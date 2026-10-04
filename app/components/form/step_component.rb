class Form::StepComponent < ViewComponent::Base
  use_helpers :icon, :icon?, from: ApplicationHelper, prefix: :user
  renders_one :breadcrumb, Form::BreadcrumbComponent

  def initialize(wizard:, wizard_steps:, current_step:, previous_path: nil, show_finish: false)
    @wizard = wizard
    @wizard_steps = wizard_steps
    @current_step = current_step
    @previous_path = previous_path
    @show_finish = show_finish
  end

  attr_reader :wizard, :wizard_steps, :current_step, :previous_path

  def show_finish_button?
    @show_finish && current_step != wizard_steps.last
  end
end
