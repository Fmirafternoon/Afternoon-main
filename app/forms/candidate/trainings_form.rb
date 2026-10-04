class Candidate::TrainingsForm < BaseForm
  GLOBAL_VALIDATION = false
  self.model_class = Training

  attribute :id, :integer

  attribute :title, :string
  attribute :issuing_organization, :string
  attribute :year, :integer

  validates :title, presence: true

  def initialize(attributes = {})
    @candidate = Candidate.find(attributes.with_indifferent_access.dig(:id))
    super(attributes)
  end

  private

  def persist!
    @candidate.trainings.create(attributes.except("id"))
  end
end
