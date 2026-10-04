class Customer::SearchForm < BaseForm
  attribute :query, :string
  attribute :lat, :string
  attribute :lng, :string

  attribute :autocomplete_address, :string
  attribute :zip_code, :string
  attribute :city, :string

  attribute :sector_ids, array: true, default: []
  attribute :skills, array: true, default: []

  def initialize(attributes = {})
    super(attributes)
  end

  def persist!
  end
end
