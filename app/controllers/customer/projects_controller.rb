class Customer::ProjectsController < Customer::BaseController
  def index
    scope = policy_scope(Project).ordered
    scope = params[:status] == 'archived' ? scope.archived : scope.not_archived

    @pagy, @projects = pagy(scope)
  end

  def show
    @project = current_user.projects.find(params[:id])
    authorize @project

    scope = @project.project_candidates.for_customer.includes(:candidate).ordered
    scope = filter_candidates(scope)
    @project_candidates = scope
    @counts = {
      all: @project.project_candidates.for_customer.count,
      new: @project.project_candidates.for_customer.new_for_customer.count,
      interested: @project.project_candidates.interested.count
    }
  end

  def duplicate
    @project = current_user.projects.find(params[:id])
    authorize @project

    new_project = @project.dup
    new_project.title = "#{@project.title} (copie)"
    new_project.status = :draft
    new_project.created_at = nil
    new_project.updated_at = nil
    new_project.last_email_broadcasted_at = nil
    new_project.save!

    redirect_to customer_projects_path, notice: "Projet dupliqué avec succès"
  end

  def archive
    @project = current_user.projects.find(params[:id])
    authorize @project
    
    @project.archived!
    redirect_to customer_projects_path, notice: "Projet archivé"
    

  end

  def unarchive
    @project = current_user.projects.find(params[:id])
    authorize @project
    
    @project.active!
    redirect_to customer_projects_path, notice: "Projet réactivé"
    

  end




  def destroy
    @project = current_user.projects.find(params[:id])
    authorize @project

    @project.destroy!
    redirect_to customer_projects_path, notice: "Projet supprimé"
  end

  def save_draft
    @project = current_user.projects.find(params[:id])
    authorize @project

    @project.draft!
    redirect_to customer_projects_path, notice: "Brouillon enregistré"
  end

  def rebroadcast
    @project = current_user.projects.find(params[:id])
    authorize @project

    if @project.active? && @project.broadcastable?
      Project::EmailBroadcastJob.perform_async(@project.id)
      redirect_to customer_project_path(@project), notice: "Votre projet va être renvoyé aux agences à proximité."
    else
      redirect_to customer_project_path(@project), alert: "Le projet a déjà été diffusé il y a moins d'une semaine."
    end
  end

  private

  def filter_candidates(scope)
    case params[:filter]
    when "new"
      scope.new_for_customer
    when "interested"
      scope.interested
    else
      scope
    end
  end
end
