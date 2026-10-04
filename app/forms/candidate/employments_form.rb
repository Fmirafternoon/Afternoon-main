class Candidate::EmploymentsForm < BaseForm
  GLOBAL_VALIDATION = [:at_least_one_employment]
  self.model_class = Employment

  attribute :id, :integer

  attribute :title, :string
  attribute :company, :string
  attribute :description, :string
  attribute :duration_in_months, :integer
  attribute :from_year, :integer
  attribute :from_month, :integer
  attribute :to_year, :integer
  attribute :to_month, :integer
  attribute :location, :string
  attribute :sector, :string

  # Virtual attributes for formatted dates
  attribute :from_date, :string
  attribute :to_date, :string

  validates :from_date, :to_date, presence: true
  validates :title, :company, :sector, :location, :description, presence: true

  validate :at_least_one_employment, if: -> { title.blank? }

  def initialize(attributes = {})
    @candidate = Candidate.find(attributes.with_indifferent_access.dig(:id))
    super(attributes)

    self.from_date = format_date(from_month, from_year) if from_month.present? && from_year.present?
    self.to_date = format_date(to_month, to_year) if to_month.present? && to_year.present?
  end

  def valid_employment?
    if @candidate.employments.empty?
      errors.add(:base, "Veuillez renseigner au moins une expérience")
      false
    else
      true
    end
  end

  private

  def at_least_one_employment
    if @candidate.employments.empty?
      errors.add(:base, "Veuillez renseigner au moins une compétence")
    end
  end

  def persist_employment!
    self.from_year = from_date.split("/").last.to_i
    self.from_month = from_date.split("/").first.to_i
    self.to_year = to_date.split("/").last.to_i
    self.to_month = to_date.split("/").first.to_i
    @candidate.employments.create(attributes.except("id", "from_date", "to_date"))
  end

  def persist!
    persist_employment! if valid?
  end
end
