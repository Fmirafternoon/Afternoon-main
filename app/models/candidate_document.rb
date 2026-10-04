class CandidateDocument < ApplicationRecord
  belongs_to :candidate

  validates :url, presence: true
  validates :file_name, presence: true
end
