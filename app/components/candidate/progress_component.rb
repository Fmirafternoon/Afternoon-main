# frozen_string_literal: true

class Candidate::ProgressComponent <  ViewComponent::Base
  def initialize(candidate)
    @candidate = candidate
  end

  attr_reader :candidate

  def render?
    @candidate.import_status.present?
  end
end
