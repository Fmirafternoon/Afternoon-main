class Candidate::ValidationComponent < ViewComponent::Base
  def initialize(candidate:)
    @candidate = candidate
  end

  def render?
    validation_errors.any?
  end

  private

  attr_reader :candidate

  def validation_errors
    @candidate.validation_errors
  end

  def step_path(step)
    Rails.application.routes.url_helpers.agent_candidate_wizard_path(candidate, step, validate: true)
  end

  def step_name(step)
    I18n.t("wizard.candidate.#{step}")
  end
end
