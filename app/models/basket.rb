class Basket < ApplicationRecord
  belongs_to :customer, class_name: "User", foreign_key: "customer_id"
  has_many :basket_items, dependent: :destroy
  has_many :candidates, through: :basket_items

  # Trouve ou crée le basket du customer
  def self.for_customer(customer)
    find_or_create_by(customer: customer)
  end

  # Ajoute un candidat (trouve/crée le BasketItem approprié)
  def add_candidate(candidate)
    item = basket_items.find_or_create_by(agent: candidate.agent)
    item.add_candidate(candidate) unless item.has_candidate?(candidate)
    item
  end

  # Nombre total de candidats
  def total_candidates_count
    basket_items.joins(:basket_item_candidates).count
  end

  # Nombre de candidats en attente (status pending)
  def pending_candidates_count
    basket_items.where(status: "pending").joins(:basket_item_candidates).count
  end

  def empty?
    total_candidates_count.zero?
  end

  # Groupes avec candidats en attente
  def pending_items
    basket_items.where(status: "pending").includes(:agent, :candidates)
  end

  # Vérifie si un candidat est dans le panier
  def has_candidate?(candidate)
    candidates.include?(candidate)
  end

  # Trouve le basket_item contenant un candidat
  def basket_item_for_candidate(candidate)
    basket_items.joins(:basket_item_candidates).find_by(basket_item_candidates: { candidate_id: candidate.id })
  end
end
