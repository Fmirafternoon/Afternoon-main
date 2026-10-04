class Project::MatchCandidatesJob
  include Sidekiq::Job

  sidekiq_options retry: 3, queue: "default"

  def perform(project_id)
    project = Project.find(project_id)

    return unless project.active?

    result = ProjectCandidate::Match.call(project: project, limit: 10)

    result.matches.each do |match|
      create_project_candidate(project, match)
    end

    Rails.logger.info "Project #{project_id}: matched #{result.matches.size} candidates"
  end

  private

  def create_project_candidate(project, match)
    project_candidate = ProjectCandidate.find_or_initialize_by(
      project: project,
      candidate: match[:candidate]
    )

    # Déjà traité : on relance juste l'analyse si elle est restée bloquée en pending
    if project_candidate.persisted?
      if project_candidate.pending? && !project_candidate.analysis_ready?
        ProjectCandidate::AnalyseJob.perform_async(project_candidate.id)
      end
      return
    end

    project_candidate.assign_attributes(
      status: :pending,
      match_score: match[:score]
    )

    if project_candidate.save
      ProjectCandidate::AnalyseJob.perform_async(project_candidate.id)
    end
  end
end
