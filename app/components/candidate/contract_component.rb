class Candidate::ContractComponent < TagComponent
  def initialize(candidate:)
    @candidate = candidate

    @kind = "neutral"
  end

  def render?
    candidate.contract_type.present?
  end

  attr_reader :candidate

  def content
    candidate.contract_type&.upcase
  end
end
