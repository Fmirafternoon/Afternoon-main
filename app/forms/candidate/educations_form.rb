class Candidate::EducationsForm < BaseForm
  GLOBAL_VALIDATION = false
  self.model_class = Education

  attribute :id, :integer

  attribute :title, :string
  attribute :issuing_organization, :string
  attribute :duration_in_months, :integer
  attribute :from_year, :integer
  attribute :from_month, :integer
  attribute :to_year, :integer
  attribute :to_month, :integer
  attribute :location, :string

  # Attributs virtuels pour les dates formatées
  attribute :from_date, :string
  attribute :to_date, :string

  validates :title, presence: true

  def initialize(attributes = {})
    @candidate = Candidate.find(attributes.with_indifferent_access.dig(:id))
    super(attributes)

    # Initialiser les dates formatées à partir des valeurs existantes
    self.from_date = format_date(from_month, from_year) if from_month.present? && from_year.present?
    self.to_date = format_date(to_month, to_year) if to_month.present? && to_year.present?
  end

  private

  def persist!
    self.from_year = from_date.split("/").last.to_i
    self.from_month = from_date.split("/").first.to_i
    self.to_year = to_date.split("/").last.to_i
    self.to_month = to_date.split("/").first.to_i
    @candidate.educations.create(attributes.except("id", "from_date", "to_date"))
  end
end
