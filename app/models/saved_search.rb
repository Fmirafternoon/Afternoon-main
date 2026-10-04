class SavedSearch < ApplicationRecord
  belongs_to :customer, class_name: "User", foreign_key: "customer_id"
  has_one :project
  has_many :saved_search_viewed_candidates, dependent: :destroy
  has_many :viewed_candidates, through: :saved_search_viewed_candidates, source: :candidate

  validates :name, presence: true, uniqueness: { scope: :customer_id }
  validates :criteria, presence: true

  scope :ordered, -> { order(created_at: :desc) }
  scope :active, -> { where(archived: false) }
  scope :archived, -> { where(archived: true) }
  scope :with_alerts_enabled, -> { where(email_alerts_enabled: true) }

  def formatted_criteria
    parts = []
    parts << criteria["query"] if criteria["query"].present?
    parts << criteria["city"] if criteria["city"].present?

    if criteria["sector_ids"].present? && criteria["sector_ids"].any?
      sectors = Sector.where(id: criteria["sector_ids"]).pluck(:name)
      parts << sectors.join(", ") if sectors.any?
    end

    if criteria["skills"].present? && criteria["skills"].any?
      parts << criteria["skills"].join(", ")
    end

    parts.join(", ")
  end

  def touch_last_used_at!
    update_column(:last_used_at, Time.current)
  end

  def toggle_email_alerts!
    update!(email_alerts_enabled: !email_alerts_enabled)
  end

  def mark_candidates_as_viewed(candidates)
    return if candidates.empty?
    
    viewed_records = candidates.map do |candidate|
      {
        saved_search_id: id,
        candidate_id: candidate.id,
        viewed_at: Time.current,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    SavedSearchViewedCandidate.upsert_all(viewed_records, unique_by: [:saved_search_id, :candidate_id])
  end

  def find_new_candidates
    result = Candidate::Search.call(
      scope: Candidate.all,
      form: Customer::SearchForm.new(criteria)
    )
    
    candidates = result.candidates.published.kept
    
    viewed_candidate_ids = saved_search_viewed_candidates.pluck(:candidate_id)
    
    candidates = candidates.where.not(id: viewed_candidate_ids) if viewed_candidate_ids.any?
    
    if last_alert_sent_at.present?
      candidates = candidates.where('candidates.created_at >= ?', last_alert_sent_at)
    end
    
    candidates
  end
  
end
