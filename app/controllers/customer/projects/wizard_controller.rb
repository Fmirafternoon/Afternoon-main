class Customer::Projects::WizardController < Customer::BaseController
  include Wicked::Wizard

  steps :step1, :step2, :step3

  before_action :set_project, only: [:show, :update, :create]

  def show
    authorize @project, :edit?
    handle_skills if step == :step2
    set_form_from_database
    render_wizard
  end

  def create
    authorize @project, :create?
    @form = Customer::ProjectStep1Form.new(step1_params, project: @project)

    if @form.save
      redirect_to customer_project_wizard_path(@form.project, :step2)
    else
      render :step1, status: :unprocessable_entity
    end
  end

  def update
    authorize @project, :edit?
    set_form_from_params

    if @form.save
      if step == :step3
        redirect_to customer_project_path(@project), notice: "Votre projet à été publié avec succes"
      else
        redirect_to next_wizard_path
      end
    else
      @skills = @form.skills if step == :step2
      render_wizard nil, status: :unprocessable_entity
    end
  end

  helper_method :wizard_path, :next_wizard_path, :previous_wizard_path

  def wizard_path(goto_step = nil)
    customer_project_wizard_path(@project, goto_step || step)
  end

  def next_wizard_path
    next_step_index = wizard_steps.index(step) + 1
    if next_step_index < wizard_steps.length
      customer_project_wizard_path(@project, wizard_steps[next_step_index])
    else
      customer_project_path(@project)
    end
  end

  def previous_wizard_path
    prev_step_index = wizard_steps.index(step) - 1
    if prev_step_index >= 0
      customer_project_wizard_path(@project, wizard_steps[prev_step_index])
    else
      customer_projects_path
    end
  end

  private

  def set_project
    if params[:project_id] == "new"
      @project = current_user.projects.build(status: :draft)
    else
      @project = current_user.projects.find(params[:project_id])
    end
  end

  def new_project?
    @project.new_record?
  end
  helper_method :new_project?

  def handle_skills
    return unless params[:skills].present? || params[:editing_skills].present?

    @skills = Array(params[:skills]).filter_map do |skill|
      name = skill[:name].to_s.strip
      next if name.blank?

      { "name" => name, "required" => skill[:required] == "1", "seniority" => skill[:seniority].presence }
    end
  end

  def set_form_from_database
    @form = form_class.new(project: @project)
    @skills ||= @form.skills if step == :step2
  end

  def set_form_from_params
    @form = form_class.new(wizard_params, project: @project)
  end

  def form_class
    @form_class ||= "Customer::Project#{step.to_s.camelize}Form".constantize
  end

  def wizard_params
    return {} unless params[:wizard_form].present?

    permitted = params.require(:wizard_form).permit(*permitted_attributes, "start_date(1i)", "start_date(2i)", "start_date(3i)").to_h
    convert_multiparameter_dates(permitted)
  end

  def step1_params
    return {} unless params[:wizard_form].present?

    permitted = params.require(:wizard_form).permit(
      :position_name, :location_city, :start_date, :contract_type, :description,
      "start_date(1i)", "start_date(2i)", "start_date(3i)"
    ).to_h
    convert_multiparameter_dates(permitted)
  end

  def convert_multiparameter_dates(attrs)
    if attrs["start_date(1i)"].present?
      year = attrs.delete("start_date(1i)")
      month = attrs.delete("start_date(2i)")
      day = attrs.delete("start_date(3i)")
      attrs["start_date"] = Date.new(year.to_i, month.to_i, day.to_i) rescue nil
    end
    attrs
  end

  def permitted_attributes
    case step
    when :step1
      [:position_name, :location_city, :start_date, :contract_type, :description]
    when :step2
      [:min_experience_years, :desired_availability, skills: [:name, :required, :seniority]]
    when :step3
      [:broadcast_enabled]
    else
      []
    end
  end
end
