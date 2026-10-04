module WizardHelper
  def wizard_breadcrumb_options(key:, wizard_steps:, current_step:, description:)
    {
      key: key,
      wizard_steps: wizard_steps,
      current_step: current_step,
      description: description,
      step_path: ->(step) { step_path(step) },
      step_accessible: ->(step) { step_accessible?(step) }
    }
  end
end
