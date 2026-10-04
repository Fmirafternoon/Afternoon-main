class Project < ApplicationRecord
  belongs_to :customer, class_name: "User", foreign_key: "customer_id"
  belongs_to :location, optional: true
  belongs_to :saved_search, optional: true
  has_many :project_skills, dependent: :destroy
  has_many :skills, through: :project_skills
  has_many :project_candidates, dependent: :destroy
  has_many :candidates, through: :project_candidates

  enum :status, { draft: 0, active: 1, archived: 2 }

  BROADCAST_COOLDOWN = 1.week

  after_commit :enqueue_candidate_matching, if: :just_published?
  after_commit :create_or_update_saved_search, if: :just_published?
  after_commit :email_broadcast_project, if: :just_published?
  after_commit :archive_saved_search, if: :just_archived?
  enum :desired_availability, {
    immediate: "immediate",
    within_1_month: "within_1_month",
    within_3_months: "within_3_months",
    flexible: "flexible"
  }, prefix: true

  scope :not_archived, -> { where.not(status: :archived) }
  scope :ordered, -> { order(created_at: :desc) }

  # Agent scopes
  scope :with_candidates_to_validate, -> {
    joins(:project_candidates).where(project_candidates: { status: :matched }).distinct
  }
  scope :with_client_interests, -> {
    joins(:project_candidates).where(project_candidates: { status: :interested }).distinct
  }

  def candidates_to_validate_count
    project_candidates.matched.count
  end

  def candidates_pushed_count
    project_candidates.pushed.count
  end

  def candidates_interested_count
    project_candidates.interested.count
  end

  def client_initials
    return "??" unless customer.present?
    name = customer.company&.name
    if name.present?
      parts = name.split
      first = parts.first&.first || "?"
      second = parts.second&.first || ""
      "#{first}#{second}".upcase
    else
      first = customer.first_name&.first || "?"
      second = customer.last_name&.first || ""
      "#{first}#{second}".upcase
    end
  end

  def client_name
    customer&.company&.name || "#{customer&.first_name} #{customer&.last_name}"
  end

  def output
    as_json(
      only: [
        :position_name, :contract_type, :min_experience_years,
        :description, :languages, :target_salary, :desired_availability
      ],
      include: {
        location: { only: [:city, :zip_code] },
        skills: { only: [:name] }
      }
    )
  end

  def broadcastable?
    broadcast_enabled? &&
      (last_email_broadcasted_at.nil? || last_email_broadcasted_at < BROADCAST_COOLDOWN.ago)
  end

  def next_broadcast_available_at
    return nil if last_email_broadcasted_at.nil?

    last_email_broadcasted_at + BROADCAST_COOLDOWN
  end

  def build_search_criteria
    {
      "query" => position_name,
      "city" => location&.city,
      "skills" => skills.pluck(:name)
    }.compact_blank
  end

  private

  def just_published?
    saved_change_to_status? && active?
  end

  def just_archived?
    saved_change_to_status? && archived?
  end

  def enqueue_candidate_matching
    Project::MatchCandidatesJob.perform_async(id)
  end

  def email_broadcast_project
    return unless broadcastable?

    Project::EmailBroadcastJob.perform_async(id)
  end

  def create_or_update_saved_search
    criteria = build_search_criteria
    return if criteria.blank?

    if saved_search.present?
      saved_search.update!(criteria: criteria)
    else
      search = customer.saved_searches.create!(
        name: "Projet - #{position_name}",
        criteria: criteria
      )
      update_column(:saved_search_id, search.id)
    end
  end

  def archive_saved_search
    saved_search&.update!(archived: true)
  end

  # Ransack whitelist for ActiveAdmin
  def self.ransackable_attributes(auth_object = nil)
    %w[id position_name status contract_type created_at updated_at customer_id]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[customer location project_candidates]
  end
end
