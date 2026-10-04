class Agent::CompanyLocationsController < Agent::BaseController
  def destroy
    company_location = CompanyLocation.find(params[:id])
    authorize company_location
    company_location.destroy

    redirect_back(fallback_location: agent_onboarding_path(:company_info), notice: "Location supprimée avec succès")
  end
end
