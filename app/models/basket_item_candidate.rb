class BasketItemCandidate < ApplicationRecord
  belongs_to :basket_item
  belongs_to :candidate

  validates :added_at, presence: true
  validates :candidate_id, uniqueness: { scope: :basket_item_id }
end
