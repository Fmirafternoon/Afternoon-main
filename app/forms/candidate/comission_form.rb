class Candidate::ComissionForm < BaseForm
  self.model_class = Candidate

  attribute :id, :integer

  attribute :recruitment_commission, :integer


  def initialize(attributes = {})
    @candidate = Candidate.find(attributes.with_indifferent_access.dig(:id))
    super(attributes)
  end

  private

  def persist!
    @candidate.update(attributes.except("id"))
  end
end
