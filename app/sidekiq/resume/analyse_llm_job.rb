class Resume::AnalyseLlmJob
  include Sidekiq::Job
  include Sidekiq::Throttled::Job

  sidekiq_options retry: 5, queue: 'llm', dead: true

  sidekiq_retries_exhausted do |job, exception|
    candidate = Candidate.find_by(id: job["args"].first)
    if candidate
      candidate.fail_import_workflow! unless candidate.import_failed?
      Rails.logger.error "Candidate #{candidate.id}: retries exhausted — #{exception.message}"
    end
  end

  # Limite à 2 jobs LLM concurrents maximum pour ne pas monopoliser tous les threads
  sidekiq_throttle(
    concurrency: { limit: 2 }
  )

  def perform(candidate_id)
    candidate = Candidate.find(candidate_id)
    candidate.start_import_workflow!

    begin
      # Réutiliser le résultat existant ou appeler le LLM
      json_output = candidate.llm_analysis_result.presence ||
                    Resume::Analyse.call(candidate: candidate).json_output

      if json_output.nil?
        Rails.logger.error "Candidate #{candidate_id}: LLM analysis returned nil"
        raise "LLM analysis returned nil for candidate #{candidate_id}"
      end

      # Sauvegarder le résultat avant de passer au job suivant
      if candidate.llm_analysis_result.blank?
        candidate.update_column(:llm_analysis_result, json_output)
        Rails.logger.info "Candidate #{candidate_id}: LLM result cached"
      end

      # Enqueue le job suivant pour l'update
      Resume::UpdateCandidateJob.perform_async(candidate.id)

      Rails.logger.info "Candidate #{candidate_id}: LLM analysis completed, update job enqueued"
    rescue => e
      Rails.logger.error "Candidate #{candidate_id}: LLM analysis failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end

    candidate.reload

    # Broadcast du statut pending (en attente de l'update)
    Turbo::StreamsChannel.broadcast_replace_to(
      "candidates_#{candidate.agent.id}",
      partial: "agent/candidates/upload",
      target: ActionView::RecordIdentifier.dom_id(candidate, :agent),
      locals: { candidate: candidate }
    )

    Turbo::StreamsChannel.broadcast_update_to(
      "candidates_#{candidate.agent.id}",
      partial: "agent/candidates/count",
      target: "candidates_count",
      locals: { count: candidate.agent.candidates.import_pending.count }
    )
  end
end
