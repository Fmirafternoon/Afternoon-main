class SavedSearchViewedCandidate < ApplicationRecord
  belongs_to :saved_search
  belongs_to :candidate
  
  validates :viewed_at, presence: true
  validates :candidate_id, uniqueness: { scope: :saved_search_id }
end