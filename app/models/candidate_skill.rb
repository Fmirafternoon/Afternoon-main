class CandidateSkill < ApplicationRecord
  belongs_to :candidate, touch: true
  belongs_to :skill
  enum :seniority, { junior: 0, intermediate: 1, confirmed: 2, expert: 3 }

  delegate :name, to: :skill

  after_commit :enqueue_project_matching, on: [:create, :update, :destroy]

  private

  def enqueue_project_matching
    return unless candidate&.published?

    Candidate::MatchProjectsJob.perform_async(candidate.id)
  end
end
