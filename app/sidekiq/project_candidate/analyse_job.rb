class ProjectCandidate::AnalyseJob
  include Sidekiq::Job
  include Sidekiq::Throttled::Job

  sidekiq_options retry: 3, queue: 'llm'

  # Limite à 2 jobs LLM concurrents maximum
  sidekiq_throttle(
    concurrency: { limit: 2 }
  )

  def perform(project_candidate_id)
    project_candidate = ProjectCandidate.find(project_candidate_id)

    # Skip si déjà analysé et matched
    if project_candidate.matched? && project_candidate.analysis_ready?
      Rails.logger.info "ProjectCandidate #{project_candidate_id}: Already analysed, skipping"
      return
    end

    begin
      result = ProjectCandidate::Analyse.call(project_candidate: project_candidate)

      if result.json_output.nil?
        Rails.logger.error "ProjectCandidate #{project_candidate_id}: LLM analysis returned nil"
        raise StandardError.new("LLM analysis returned nil")
      end

      # Passe de pending à matched + sauvegarde l'analyse
      project_candidate.update!(
        llm_analysis: result.json_output,
        status: :matched
      )
      Rails.logger.info "ProjectCandidate #{project_candidate_id}: LLM analysis completed, status -> matched"

      # Broadcast Turbo update to refresh the card
      broadcast_update(project_candidate)

      # Notify agent by email (seulement après l'analyse)
      AgentMailer.candidate_matched(project_candidate_id).deliver_later

    rescue => e
      Rails.logger.error "ProjectCandidate #{project_candidate_id}: LLM analysis failed: #{e.message}"
      raise e
    end
  end

  private

  def broadcast_update(project_candidate)
    project = project_candidate.project

    Turbo::StreamsChannel.broadcast_replace_to(
      [project, :candidates],
      target: ActionView::RecordIdentifier.dom_id(project_candidate, :agent),
      partial: "agent/projects/candidates/card",
      locals: { pc: project_candidate, project: project }
    )
  end
end
