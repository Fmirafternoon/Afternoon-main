class Customer::ProjectStep1Form < BaseForm
  self.model_class = Project

  attribute :position_name, :string
  attribute :location_city, :string
  attribute :start_date, :date
  attribute :contract_type, :string
  attribute :description, :string

  validates :position_name, presence: true
  validates :location_city, presence: true
  validates :contract_type, presence: true
  validates :description, presence: true

  def initialize(attributes = {}, project: nil)
    @project = project || current_user.projects.build(status: :draft)
    super(attributes)
    load_from_project if attributes.blank?
  end

  attr_reader :project

  private

  def load_from_project
    self.position_name = project.position_name
    self.location_city = project.location&.city
    self.start_date = project.start_date
    self.contract_type = project.contract_type
    self.description = project.description
  end

  def persist!
    project.assign_attributes(
      position_name: position_name,
      start_date: start_date,
      contract_type: contract_type,
      description: description,
      title: position_name
    )

    if location_city.present?
      location = Location.find_or_create_by!(city: location_city) do |loc|
        loc.address = location_city
      end
      project.location = location
    end

    project.save!
  end

  def current_user
    @current_user ||= Current.user
  end
end
