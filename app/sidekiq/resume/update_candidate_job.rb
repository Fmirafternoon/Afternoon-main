class Resume::UpdateCandidateJob
  include Sidekiq::Job

  sidekiq_options retry: 0, queue: 'default'

  def perform(candidate_id)
    candidate = Candidate.find(candidate_id)

    begin
      # Vérifier que le résultat LLM est disponible
      json_output = candidate.llm_analysis_result
      if json_output.blank?
        raise StandardError.new("llm_analysis_result is missing for candidate #{candidate_id}")
      end

      # Appliquer les changements du LLM au candidat
      Resume::UpdateCandidate.call(candidate: candidate, json_output: json_output)

      # Enqueue le job de géolocalisation
      Candidate::GeocodeLocationJob.perform_async(candidate.id)

      # Marquer comme terminé
      candidate.complete_import_workflow!

      Rails.logger.info "Candidate #{candidate_id}: Update completed successfully"
    rescue => e
      Rails.logger.error "Candidate #{candidate_id}: Update failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      candidate.fail_import_workflow! unless candidate.import_failed?
      raise e # Pas de retry, va directement dans la Dead queue
    end

    candidate.reload

    # Broadcast du statut final
    Turbo::StreamsChannel.broadcast_replace_to(
      "candidates_#{candidate.agent.id}",
      partial: "agent/candidates/upload",
      target: ActionView::RecordIdentifier.dom_id(candidate, :agent),
      locals: { candidate: candidate }
    )

    Turbo::StreamsChannel.broadcast_prepend_to(
      "candidates_#{candidate.agent.id}",
      partial: "agent/candidates/candidate",
      target: "candidates",
      locals: { candidate: candidate }
    )

    Turbo::StreamsChannel.broadcast_update_to(
      "candidates_#{candidate.agent.id}",
      partial: "agent/candidates/count",
      target: "candidates_count",
      locals: { count: candidate.agent.candidates.import_completed.count }
    )
  end
end
