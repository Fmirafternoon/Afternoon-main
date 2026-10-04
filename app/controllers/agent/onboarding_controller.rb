class Agent::OnboardingController < Agent::BaseController
  include Wicked::Wizard

  steps :personal_info, :company_info

  def wizard_steps
    if current_user.agent_manager?
      [:personal_info, :company_info]
    else
      [:personal_info]
    end
  end

  layout "no_navbar"

  def show
    authorize current_user
    set_form_from_database

    render_wizard
  end

  def update
    set_form_from_wizard_params
    authorize current_user

    case step
    when :personal_info
      if @form.save
        if current_user.agent_manager?
          redirect_to next_wizard_path and return
        else
          redirect_to finish_wizard_path, notice: "Votre profil a été créé avec succès" and return
        end
      else
        render_wizard @form
      end
    when :company_info
      if @form.save
        if params[:commit] == "add_company"
          @form.persist_company!
          redirect_to current_wizard_path, notice: "Entreprise partenaire ajoutée avec succès" and return
        end
        redirect_to next_wizard_path and return
      else
        render_wizard @form
      end
    end
  end

  helper_method :previous_wizard_path, :next_wizard_path

  def current_wizard_path
    agent_onboarding_path(step)
  end

  def next_wizard_path
    next_step_index = wizard_steps.index(step) + 1
    if next_step_index < wizard_steps.length
      next_step = wizard_steps[next_step_index]
      # Skip company_info step if not an agent_manager
      if next_step == :company_info && !current_user.agent_manager?
        finish_wizard_path
      else
        agent_onboarding_path(next_step)
      end
    else
      finish_wizard_path
    end
  end

  def previous_wizard_path
    prev_step_index = wizard_steps.index(step) - 1
    if prev_step_index >= 0
      agent_onboarding_path(wizard_steps[prev_step_index])
    else
      agent_onboarding_path
    end
  end

  private

  def finish_wizard_path
    agent_candidates_path
  end

  def set_form_from_database
    attributes = current_user.attributes

    # Set company related data for agent_manager
    if current_user.agent_manager? && step == :company_info
      # Placeholder for company related data specific to agent_manager
    end

    @form = form_class.new(attributes.with_indifferent_access.slice(*form_class.attribute_names))
  end

  def set_form_from_wizard_params
    @form = form_class.new(wizard_params)
  end

  def form_class
    @form_class ||= "Agent::#{step.to_s.camelize}Form".constantize
  end

  def wizard_params
    return {} unless params[:wizard_form].present?

    params.require(:wizard_form).permit(*form_class.attribute_names).to_h
  end
end
