class Customer::CompanyInfoForm < BaseForm
  self.model_class = User

  attribute :company_name, :string
  attribute :siren, :string


  # Pour l'adresse en cours d'édition
  attribute :autocomplete_address, :string
  attribute :zip_code, :string
  attribute :city, :string
  attribute :lat, :string
  attribute :lng, :string
  attribute :location_name, :string

  attribute :sector_id, :integer

  validates :company_name, :siren, presence: true
  validates :zip_code, :city, presence: true, if: -> { autocomplete_address.present? }

  validates :sector_id, presence: true, on: :add_sector

  def initialize(attributes = {})
    super(attributes)
  end

  def persist_location!
    return unless autocomplete_address.present?
    return unless lat.present? && lng.present?
    return unless zip_code.present? && city.present?

    return if current_user.company.nil?

    location =
      Location.create_with(
          latitude: lat,
          longitude: lng
        ).find_or_create_by(
          city: city,
          zip_code: zip_code,
        )
    current_user.company.locations << location
    current_user.save!
    location
  end

  def persist_sector!
    return false unless valid?(:add_sector)

    current_user.company.sectors << Sector.find(sector_id)
    current_user.save!
  end

  private


  def persist!
    ActiveRecord::Base.transaction do
      if current_user.company.nil?
        company = Company.create!(
          name: company_name,
          siren: siren
        )
        current_user.company = company
        current_user.save!
      else
        current_user.company.update!(
          name: company_name,
          siren: siren
        )
      end
    end
  end

  def current_user
    Current.user
  end
end
