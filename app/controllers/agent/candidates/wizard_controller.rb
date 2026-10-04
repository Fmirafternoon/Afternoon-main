class Agent::Candidates::WizardController < Agent::BaseController
  include Wicked::Wizard

  before_action :set_candidate

  steps(*Candidate::WIZARD_STEPS)

  layout "no_navbar"

  helper_method :step_path, :step_accessible?, :previous_wizard_path, :next_wizard_path

  def show
    authorize @candidate

    case step
    when :personal_info
      set_form_from_database
    when :motivations
      set_form_from_database
    when :skills
      @form = Candidate::SkillsForm.new(id: @candidate.id)
    when :employments
      @form = Candidate::EmploymentsForm.new(id: @candidate.id)
    when :educations
      @form = Candidate::EducationsForm.new(id: @candidate.id)
    when :trainings
      @form = Candidate::TrainingsForm.new(id: @candidate.id)
    when :referrals
      @form = Candidate::ReferralsForm.new(id: @candidate.id)
    when :availability
      set_form_from_database
    when :comission
      set_form_from_database
    end

    @form.valid? if params[:validate].present?

    render_wizard
  end

  def update
    set_form_from_wizard_params
    authorize @candidate

    case step
    when :personal_info
      if @form.save
        redirect_to next_wizard_path and return
      else
        render_wizard @form
      end
    when :motivations
      if @form.save
        redirect_to next_wizard_path and return
      else
        render_wizard @form
      end
    when :skills
      if params[:commit] == "add_language"
        if @form.persist_language!
          redirect_to current_wizard_path and return
        else
          render_wizard @form
        end
      elsif params[:commit] == "add_skill"
        if @form.persist_skill!
          redirect_to current_wizard_path and return
        else
          render_wizard @form
        end
      elsif params[:commit] == "add_sector"
        if @form.persist_sector!
          redirect_to current_wizard_path and return
        else
          render_wizard @form
        end
      else
        if @form.save
          redirect_to next_wizard_path and return
        else
          render_wizard @form
        end
      end
    when :employments
      if params[:commit] == "add_employment"
        if @form.save
          redirect_to current_wizard_path and return
        else
          render_wizard @form
        end
      else
        if @form.valid_employment?
          redirect_to next_wizard_path and return
        else
          render_wizard @form
        end
      end
    when :educations
      if params[:commit] == "add_education"
        if @form.save
          redirect_to current_wizard_path and return
        else
          render_wizard @form
        end
      else
        redirect_to next_wizard_path and return
      end
    when :trainings
      if params[:commit] == "add_training"
        if @form.save
          redirect_to current_wizard_path and return
        else
          render_wizard @form
        end
      else
        redirect_to next_wizard_path and return
      end
    when :referrals
      if params[:commit] == "add_referral"
        if @form.save
          redirect_to current_wizard_path and return
        else
          render_wizard @form
        end
      else
        redirect_to next_wizard_path and return
      end
    when :availability
      if params[:commit] == "add_mobility"
        if @form.save
          @form.persist_location!
          redirect_to current_wizard_path and return
        else
          render_wizard @form
        end
      else
        if @form.save
          redirect_to next_wizard_path and return
        else
          render_wizard @form
        end
      end
    when :comission
      if @form.save
        redirect_to finish_wizard_path and return
      else
        render_wizard @form
      end
    end
  end

  def current_wizard_path
    agent_candidate_wizard_path(@form.id, step)
  end

  def next_wizard_path
    return agent_candidate_path(@form&.id || @candidate) if params[:finish].present?

    next_step_index = wizard_steps.index(step) + 1
    if next_step_index < wizard_steps.length
      agent_candidate_wizard_path(@form.id, wizard_steps[next_step_index])
    else
      finish_wizard_path
    end
  end

  def previous_wizard_path
    prev_step_index = wizard_steps.index(step) - 1
    if prev_step_index >= 0
      agent_candidate_wizard_path(@form.id, wizard_steps[prev_step_index])
    else
      agent_candidates_path
    end
  end


  def self.wizard_steps
    steps
  end

  private

  def step_path(step)
    agent_candidate_wizard_path(@candidate, step) if @candidate.persisted?
  end

  def step_accessible?(step_name)
    @candidate.persisted?
  end

  def finish_wizard_path
    agent_candidate_path(@candidate)
  end

  def set_candidate # ok
    @candidate = current_user.candidates.find_by_id(params[:candidate_id])
    @candidate = current_user.candidates.new if @candidate.nil?
  end

  def set_form_from_database
    @form = form_class.new(@candidate.attributes.slice(*form_class.attribute_names))
  end

  def set_form_from_wizard_params
    @form = form_class.new(wizard_params.merge(id: @candidate&.id))
  end

  def form_class
    @form_class ||= "Candidate::#{step.to_s.camelize}Form".constantize
  end

  def wizard_params
    return {} unless params[:wizard_form].present?

    params.require(:wizard_form).permit(*form_class.attribute_names).to_h
  end
end
