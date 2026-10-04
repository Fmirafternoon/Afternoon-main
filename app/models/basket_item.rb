class BasketItem < ApplicationRecord
  belongs_to :basket
  belongs_to :agent, class_name: "User", foreign_key: "agent_id"

  has_many :basket_item_candidates, dependent: :destroy
  has_many :candidates, through: :basket_item_candidates

  enum :status, {
    pending: "pending",               # En attente dans le panier
    meeting_requested: "meeting_requested",  # Email envoyé
    meeting_scheduled: "meeting_scheduled",  # RDV confirmé
    cancelled: "cancelled"            # Annulé
  }, prefix: true

  validates :agent, presence: true

  def add_candidate(candidate)
    basket_item_candidates.create(candidate: candidate, added_at: Time.current)
  end

  def remove_candidate(candidate)
    basket_item_candidates.find_by(candidate: candidate)&.destroy
  end

  def has_candidate?(candidate)
    candidates.include?(candidate)
  end

  def request_meeting!(date:, message:)
    update!(
      status: :meeting_requested,
      meeting_date: date,
      customer_message: message
    )
  end
end
