class Candidate::PersonalInfoForm < BaseForm
  self.model_class = Candidate

  attribute :id, :integer

  attribute :first_name, :string
  attribute :last_name, :string
  attribute :email, :string
  attribute :phone_number, :string
  attribute :gender, :string
  attribute :birth_year, :integer
  attribute :address, :string

  attribute :autocomplete_address, :string
  attribute :address, :string
  attribute :zip_code, :string
  attribute :city, :string
  attribute :lat, :float
  attribute :lng, :float

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, if: -> { email.present? }
  validates :gender, inclusion: { in: %w[male female] }, allow_blank: true
  validates :birth_year, numericality: {
    greater_than_or_equal_to: 1940,
    less_than_or_equal_to: -> { Date.today.year - 15 }
  }, allow_blank: true
  validate :autocomplete_address_presence

  def initialize(attributes = {})
    @candidate = Candidate.find_or_initialize_by(id: attributes.with_indifferent_access.dig(:id))
    attributes[:autocomplete_address] = @candidate.location.full_address if @candidate.location.present?
    super(attributes)
  end

  private

  def persist!
    if id
      @candidate = Candidate.find(id)
    else
      @candidate = Current.user.candidates.new
    end
    if address.present?
      @candidate.location = Location.create_with(latitude: lat, longitude: lng).find_or_create_by(address: address, zip_code: zip_code, city: city)
    end

    @candidate.assign_attributes(attributes.except("id", "autocomplete_address", "zip_code", "city", "lat", "lng", "address"))
    @candidate.save!
    self.id = @candidate.id
  end

  def autocomplete_address_presence
    errors.add(:autocomplete_address, :blank) if autocomplete_address.blank?
  end
end
