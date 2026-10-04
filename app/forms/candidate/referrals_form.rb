class Candidate::ReferralsForm < BaseForm
  GLOBAL_VALIDATION = false
  self.model_class = Referral

  attribute :id, :integer

  attribute :first_name, :string
  attribute :last_name, :string
  attribute :phone_number, :string
  attribute :email, :string
  attribute :company, :string
  attribute :position, :string
  attribute :description, :string

  validates :last_name, :company, :position, presence: true

  def initialize(attributes = {})
    @candidate = Candidate.find(attributes.with_indifferent_access.dig(:id))
    super(attributes)
  end

  private

  def persist!
    @candidate.referrals.create(attributes.except("id"))
  end
end
