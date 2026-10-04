class Candidate::AvailabilityForm < BaseForm
  self.model_class = Candidate

  attribute :id, :integer

  attribute :availability_notice, :string

  attribute :has_driving_license, :boolean
  attribute :has_a_car, :boolean

  attribute :contract_type, :string
  attribute :salary_expectation, :integer

  # for moblities
  attribute :autocomplete_address, :string
  attribute :city, :string
  attribute :zip_code, :string
  attribute :lat, :string
  attribute :lng, :string

  validates :zip_code, :city, presence: true, if: -> { autocomplete_address.present? }
  validates :contract_type, presence: true, if: -> { autocomplete_address.blank? }

  validate :at_least_one_mobility, if: -> { autocomplete_address.blank? }

  def initialize(attributes = {})
    @candidate = Candidate.find(attributes.with_indifferent_access.dig(:id))
    super(attributes)
  end

  def availability_notices_list
    Candidate.availability_notices.keys.map { |an| [Candidate.human_enum_name("availability_notices", an), an] }
  end

  def contract_types_list
    Candidate.contract_types.keys.map { |ct| [Candidate.human_enum_name("contract_types", ct), ct] }
  end

  def persist_location!
    return unless autocomplete_address.present?
    return unless lat.present? && lng.present?
    return unless zip_code.present? && city.present?

    location =
      Location.create_with(
          latitude: lat,
          longitude: lng
        ).find_or_create_by(
          city: city,
          zip_code: zip_code,
        )
    @candidate.locations << location
    @candidate.save!
  end

  private

  def at_least_one_mobility
    if @candidate.locations.empty?
      errors.add(:base, "Veuillez renseigner au moins une mobilité")
    end
  end

  def persist!
    if id
      @candidate = Candidate.find(id)
    else
      @candidate = Current.user.candidates.new
    end

    @candidate.assign_attributes(attributes.except("id", "autocomplete_address", "lat", "lng", "city", "zip_code"))
    @candidate.save!
    self.id = @candidate.id
  end
end
