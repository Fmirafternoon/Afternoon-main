class CandidateMobility < ApplicationRecord
  belongs_to :candidate
  belongs_to :location

  delegate :name, to: :location
end
