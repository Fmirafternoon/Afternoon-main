class Candidate::MatchProjectsJob
  include Sidekiq::Job

  sidekiq_options retry: 3, queue: 'default'

  MAX_CANDIDATES_PER_PROJECT = 10

  def perform(candidate_id)
    candidate = Candidate.find(candidate_id)

    return unless candidate.published?

    matching_projects = find_matching_projects(candidate)

    matching_projects.each do |project, score|
      create_project_candidate(project, candidate, score)
    end

    Rails.logger.info "Candidate #{candidate_id}: matched to #{matching_projects.size} projects"
  end

  private

  def find_matching_projects(candidate)
    Project.active.includes(:location, :skills).find_each.filter_map do |project|
      next if project.project_candidates.count >= MAX_CANDIDATES_PER_PROJECT
      next if project.project_candidates.exists?(candidate: candidate)

      result = ProjectCandidate::Match.call(project: project, limit: MAX_CANDIDATES_PER_PROJECT)

      match = result.matches.find { |m| m[:candidate].id == candidate.id }
      next unless match

      [project, match[:score]]
    end
  end

  def create_project_candidate(project, candidate, score)
    project_candidate = ProjectCandidate.create!(
      project: project,
      candidate: candidate,
      status: :matched,
      match_score: score
    )

    ProjectCandidate::AnalyseJob.perform_async(project_candidate.id)
  rescue ActiveRecord::RecordNotUnique
    # Already exists, skip
  end
end
