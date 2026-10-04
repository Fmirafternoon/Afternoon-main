class Customer::PersonalInfoForm < BaseForm
  self.model_class = User

  attribute :first_name, :string
  attribute :last_name, :string
  attribute :phone_number, :string
  attribute :job_title, :string

  validates :first_name, :last_name, :phone_number, presence: true

  def initialize(attributes = {})
    @customer = current_user
    super(attributes)
  end

  private

  def persist!
    current_user.assign_attributes(attributes)
    current_user.save!
  end

  def current_user
    @current_user ||= Current.user
  end
end
