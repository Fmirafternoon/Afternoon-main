class Agent::CandidatesController < Agent::BaseController
  before_action :find_candidate, only: %i[show edit update destroy archive restore]

  def index
    scope = policy_scope(Candidate).where(agent: current_user)

    @candidates =
    case params[:status]
    when "archived" then scope.archived
    when "draft" then scope.kept.where(publication_status: [:draft, :pending])
    when "published" then scope.kept.where(publication_status: :published)
    else
      scope.kept
    end
    @candidates = @candidates.order(created_at: :desc)
  end

  def show
  end

  def new
    @candidate = Candidate.new
    authorize @candidate
  end

  def create
    @candidate = Candidate.new(candidate_params)
    @candidate.agent = current_user
    authorize @candidate
    if @candidate.save
      Resume::UpsertBatch.call(candidate: @candidate, user: current_user)
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(params[:temp_id], partial: "agent/candidates/upload", locals: { candidate: @candidate })
        }
        format.html { redirect_to agent_candidates_path, notice: "Candidate créé." }
      end
    else
      render :new
    end
  end

  def edit
    @candidate = Candidate.find(params[:id])
    authorize @candidate
    render layout: "no_navbar"
  end

  def update
    if @candidate.update(candidate_params)

      Resume::ImportJob.perform_async(@candidate.id)
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace("resume-upload", partial: "agent/candidates/resume_link", locals: { candidate: @candidate })
        }
        format.html { redirect_to agent_candidate_path(@candidate), notice: "Candidat mis à jour." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    authorize @candidate, :archive?
    @candidate.update(publication_status: :draft)
    @candidate.discard
    redirect_back fallback_location: agent_candidates_path, notice: "Candidat archivé."
  end

  def restore
    authorize @candidate, :restore?
    @candidate.undiscard
    redirect_back fallback_location: agent_candidates_path, notice: "Candidat restauré."
  end

  def destroy
    authorize @candidate, :destroy?
    Cloudinary::DestroyFromUrl.call(url: @candidate.resume_url) if @candidate.resume_url.present?
    @candidate.destroy
    redirect_to agent_candidates_path, alert: "Candidat supprimé définitivement."
  end

  def publish
    @candidate = current_user.candidates.find(params[:id])
    authorize @candidate
    if @candidate.publish_workflow
      redirect_to agent_candidate_path(@candidate), notice: "Candidat publié !"
    else
      redirect_to agent_candidate_path(@candidate), alert: "Impossible de soumettre le candidat"
    end
  end

  def cancel
    candidates = current_user.candidates
    candidates =
      policy_scope(Candidate)
        .where(import_status: %i[uploading pending failed])

    authorize candidates
    candidates.each do |candidate|
      candidate.discard
      Cloudinary::DestroyFromUrl.call(url: candidate.resume_url) if candidate.resume_url.present?
    end

    redirect_to agent_candidates_path, status: :see_other
  end

  def new_wizard
    @candidate = current_user.candidates.create
    redirect_to agent_candidate_wizard_path(@candidate, :personal_info)
  end

  private

  def candidate_params
    params
      .require(:candidate)
      .permit(
        :first_name,
        :last_name,
        :resume_url,
        :resume_file_name
      )
  end

  def find_candidate
    @candidate = current_user.candidates.with_discarded.find(params[:id])
    authorize @candidate
  end
end
