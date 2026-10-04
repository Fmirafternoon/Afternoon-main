class Agent::CompanyInfoForm < BaseForm
  self.model_class = User

  attribute :company_name, :string
  attribute :company_siren, :string

  attribute :autocomplete_address, :string
  attribute :city, :string
  attribute :zip_code, :string
  attribute :lat, :string
  attribute :lng, :string

  validates :autocomplete_address, :city, :zip_code, presence: true
  validates :company_name, :company_siren, presence: true, if: -> { company_name.present? || company_siren.present? }

  def initialize(attributes = {})
    super(attributes)

    return if current_user.recruitment_office.city.blank? && current_user.recruitment_office.zip_code.blank?

    self.city = current_user.recruitment_office.city if attributes[:city].blank?
    self.zip_code = current_user.recruitment_office.zip_code if attributes[:zip_code].blank?
    self.autocomplete_address = [current_user.recruitment_office.city, current_user.recruitment_office.zip_code].join(", ")
  end

  def persist_company!
    company = Company.find_or_initialize_by(siren: company_siren) do |company|
      company.name = company_name
    end

    company.save! if company.new_record? || company.name != company_name

    current_user.recruitment_office.partner_companies.find_or_create_by!(company_id: company.id)
  end

  private

  def persist!
    current_user.recruitment_office.update!(
      city: city,
      zip_code: zip_code
    )
  end

  def current_user
    @current_user ||= Current.user
  end
end
