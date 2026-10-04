class User < ApplicationRecord
  AGENT_ROLES = %w[agent_manager agent_user]

  include Discard::Model

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :recruitment_office, optional: true
  belongs_to :company, optional: true

  has_many :candidates, foreign_key: "agent_id"
  has_many :saved_searches, foreign_key: "customer_id", dependent: :destroy
  has_many :projects, foreign_key: "customer_id", dependent: :destroy

  scope :agent, -> { where(role: AGENT_ROLES) }

  enum :role, {
    super_admin: "super_admin",
    agent_manager: "agent_manager",
    agent_user: "agent_user",
    customer: "customer"
  }

  before_create :generate_password_token

  validates :role, presence: true
  validates :recruitment_office_id, presence: true, if: :agent?

  def agent?
    AGENT_ROLES.include?(role)
  end

  # Moyenne des taux de complétion des profils actifs (publiés, non archivés)
  # de l'agent. nil pour les autres rôles ou sans profil publié.
  def calculate_average_completion_percentage
    return nil unless agent?

    candidates.kept.published.average(:completion_percentage)&.round
  end

  def recalculate_average_completion_percentage!
    update_column(:average_completion_percentage, calculate_average_completion_percentage)
  end

  def low_completion_alert?
    average_completion_percentage.present? && average_completion_percentage <= 40
  end

  def customer_onboarded?
    first_name.present? && last_name.present? && email.present? && phone_number.present?
  end

  def agent_onboarded?
    first_name.present? && last_name.present?
  end

  def full_name
    if first_name.blank? && last_name.blank?
      email
    else
      "#{first_name} #{last_name}"
    end
  end

  private

  def generate_password_token
    self.password_token = loop do
      random_token = OpenSSL::HMAC.hexdigest("SHA256", email, Time.now.to_s)
      break random_token unless User.exists?(password_token: random_token)
    end
  end
end
