class Agent::PersonalInfoForm < BaseForm
  self.model_class = User

  attribute :first_name, :string
  attribute :last_name, :string
  attribute :phone_number, :string
  attribute :avatar_url, :string
  attribute :avatar_url_file, :string
  attribute :description, :string

  validates :first_name, :last_name, presence: true

  def initialize(attributes = {})
    @agent = current_user
    super(attributes)
  end

  private

  def persist!
    # Remove the file field helper, avatar_url already contains the Cloudinary URL
    attrs = attributes.dup.with_indifferent_access
    attrs.delete(:avatar_url_file) # Remove the file field helper

    current_user.assign_attributes(attrs)
    current_user.save!
  end

  def current_user
    @current_user ||= Current.user
  end
end
