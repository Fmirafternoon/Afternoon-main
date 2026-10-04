class Candidate::MotivationsForm < BaseForm
  self.model_class = Candidate

  attribute :id, :integer

  attribute :position, :string
  attribute :total_experience_in_years, :integer
  attribute :description, :string
  attribute :ongoing_application, :boolean
  attribute :change_motivations, :string
  attribute :career_relevance, :string

  validates :position, :description, presence: true
  validates :change_motivations, length: { maximum: 500 }
  validates :career_relevance, length: { maximum: 500 }
  validates :description, length: { maximum: 500 }

  def initialize(attributes = {})
    @candidate = Candidate.find(attributes.with_indifferent_access.dig(:id))
    super(attributes)
  end

  private

  def persist!
    if id
      @candidate = Candidate.find(id)
    else
      @candidate = Current.user.candidates.new
    end

    @candidate.assign_attributes(attributes.except("id"))
    @candidate.save!
    self.id = @candidate.id
  end
end
