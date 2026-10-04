class ProjectCandidateQuestion < ApplicationRecord
  belongs_to :project_candidate

  scope :unanswered, -> { where(answer: [nil, ""]) }
end
