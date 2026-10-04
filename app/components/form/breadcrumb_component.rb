class Form::BreadcrumbComponent < ViewComponent::Base
  def initialize(wizard:, wizard_steps:, current_step:, description: nil, step_path: nil, step_accessible: nil)
    @wizard = wizard
    @wizard_steps = wizard_steps
    @current_step = current_step
    @description = description
    @step_path = step_path
    @step_accessible = step_accessible
  end

  attr_reader :wizard, :wizard_steps, :current_step, :description, :step_path, :step_accessible
end
