class ProjectSkill < ApplicationRecord
  belongs_to :project
  belongs_to :skill

  enum :seniority, { junior: 0, intermediate: 1, confirmed: 2, expert: 3 }
end
