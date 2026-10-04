require "net/http"
require "uri"

class Resume::ImportJob
  include Sidekiq::Job

  def perform(candidate_id)
    candidate = Candidate.find(candidate_id)
    candidate.start_import_workflow!

    begin
      # Réutiliser le résultat existant ou appeler le LLM
      json_output = candidate.llm_analysis_result.presence ||
                    Resume::Analyse.call(candidate: candidate).json_output

      if json_output.nil?
        candidate.fail_import_workflow!
        Rails.logger.error "Candidate #{candidate_id}: LLM analysis returned nil"
      else
        # Sauvegarder le résultat avant de l'utiliser (évite de rappeler le LLM en cas d'échec)
        if candidate.llm_analysis_result.blank?
          candidate.update_column(:llm_analysis_result, json_output)
          Rails.logger.info "Candidate #{candidate_id}: LLM result cached"
        end

        Resume::UpdateCandidate.call(candidate: candidate, json_output: json_output)
        Candidate::GeocodeLocationJob.perform_async(candidate.id)
        candidate.complete_import_workflow!
      end
    rescue => e
      Rails.logger.error "Candidate #{candidate_id}: Import failed with error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      candidate.fail_import_workflow!
      raise e # Pour que Sidekiq puisse retry si nécessaire
    end

    candidate.reload

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
