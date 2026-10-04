class Agent::ProjectsController < Agent::BaseController
  def index
    @projects = policy_scope(Project).active.includes(:customer, :project_candidates).ordered
    @projects = filter_projects(@projects)

    @counts = {
      all: policy_scope(Project).active.count,
      to_validate: policy_scope(Project).active.with_candidates_to_validate.count,
      with_interests: policy_scope(Project).active.with_client_interests.count
    }
  end

  def show
    @project = Project.find(params[:id])
    authorize @project

    @project_candidates = @project.project_candidates.includes(:candidate).order(created_at: :desc)
    @project_candidates = filter_candidates(@project_candidates)

    @counts = {
      all: @project.project_candidates.count,
      matched: @project.project_candidates.matched.count,
      validated: @project.project_candidates.validated.count,
      pushed: @project.project_candidates.pushed.count,
      interested: @project.project_candidates.interested.count,
      rejected: @project.project_candidates.rejected.count
    }
  end

  private

  def filter_projects(scope)
    case params[:filter]
    when "to_validate"
      scope.with_candidates_to_validate
    when "interests"
      scope.with_client_interests
    else
      scope
    end
  end

  def filter_candidates(scope)
    case params[:status]
    when "matched"
      scope.matched
    when "validated"
      scope.validated
    when "pushed"
      scope.pushed
    when "interested"
      scope.interested
    when "rejected"
      scope.rejected
    else
      scope
    end
  end
end
