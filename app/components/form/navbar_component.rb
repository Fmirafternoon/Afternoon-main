# frozen_string_literal: true

class Form::NavbarComponent < ViewComponent::Base
  def initialize(title:, cancel_path: nil, previous_path: nil, current_step: nil, wizard_steps: nil, show_finish: false)
    @title = title
    @cancel_path = cancel_path
    @previous_path = previous_path
    @current_step = current_step
    @wizard_steps = wizard_steps
    @show_finish = show_finish
  end

  attr_reader :title, :cancel_path, :previous_path, :current_step, :wizard_steps

  def show_finish_button?
    @show_finish && current_step != wizard_steps.last
  end

  def show_previous_button?
    @previous_path.present?
  end
end
