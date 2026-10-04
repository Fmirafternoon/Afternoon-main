class PublicAccessController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :check_terms_accepted
  skip_before_action :onboard_customer
  skip_before_action :onboard_agent
  skip_before_action :set_current_attributes
  skip_after_action :verify_pundit_authorization

  def show
    project_candidate = GlobalID::Locator.locate_signed(params[:token], for: "customer_view")

    if project_candidate.nil?
      redirect_to root_path, alert: "Ce lien a expiré ou n'est pas valide."
      return
    end

    sign_in(project_candidate.project.customer)
    redirect_to customer_project_candidate_path(project_candidate.project, project_candidate)
  end
end
