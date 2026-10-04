class Customer::CompanySectorsController < Customer::BaseController
  def destroy
    @company_sector = CompanySector.find(params[:id])
    @company = @company_sector.company

    authorize @company_sector

    if @company_sector.destroy
      redirect_to customer_onboarding_path(:company_info), notice: "Secteur d'activité supprimé avec succès."
    else
      redirect_to customer_onboarding_path(:company_info), alert: "La suppression du secteur d'activité a échoué."
    end
  end
end
