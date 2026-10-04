class Customer::OnboardingController < Customer::BaseController
  include Wicked::Wizard

  steps :personal_info, :company_info, :positions

  layout "no_navbar"

  def show
    authorize current_user
    set_form_from_database

    @company = current_user.company

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
        if params[:commit] == "add_location"
          @form.persist_location!
          redirect_to current_wizard_path and return
        elsif params[:commit] == "add_sector"
          @form.persist_sector!
          redirect_to current_wizard_path and return
        end
        redirect_to next_wizard_path and return
      else
        render_wizard @form
      end
    when :positions
      if params[:commit] == "add_position"
        if @form.save
          redirect_to current_wizard_path and return
        else
          render_wizard @form
        end
      else
        redirect_to next_wizard_path and return
      end
    end
  end

  helper_method :previous_wizard_path, :next_wizard_path

  def current_wizard_path
    customer_onboarding_path(step)
  end

  def next_wizard_path
    next_step_index = wizard_steps.index(step) + 1
    if next_step_index < wizard_steps.length
      customer_onboarding_path(wizard_steps[next_step_index])
    else
      finish_wizard_path
    end
  end

  def previous_wizard_path
    prev_step_index = wizard_steps.index(step) - 1
    if prev_step_index >= 0
      customer_onboarding_path(wizard_steps[prev_step_index])
    else
      customer_onboarding_path
    end
  end

  private

  def finish_wizard_path
    # TODO: redirect to search path
    root_path
  end

  def set_form_from_database
    # Récupérer les données de Company et Location si elles existent
    attributes = {}
    if current_user.company.present?
      attributes[:company_name] = current_user.company.name
      attributes[:siren] = current_user.company.siren
    end
    @form = form_class.new(attributes.with_indifferent_access.slice(*form_class.attribute_names))
  end

  def set_form_from_wizard_params
    @form = form_class.new(wizard_params)
  end

  def form_class
    @form_class ||= "Customer::#{step.to_s.camelize}Form".constantize
  end

  def wizard_params
    return {} unless params[:wizard_form].present?

    params.require(:wizard_form).permit(*form_class.attribute_names).to_h
  end
end
