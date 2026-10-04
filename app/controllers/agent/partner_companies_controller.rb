class Agent::PartnerCompaniesController < Agent::BaseController
  def destroy
    partner_company = PartnerCompany.find(params[:id])
    authorize partner_company
    partner_company.destroy

    redirect_back(fallback_location: agent_onboarding_path(:company_info), notice: "Entreprise partenaire supprimée avec succès")
  end
end
