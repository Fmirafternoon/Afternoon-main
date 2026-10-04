class Customer::CompanyLocationsController < Customer::BaseController
  def destroy
    @company_location = CompanyLocation.find(params[:id])
    authorize @company_location
    @company_location.destroy
    redirect_to customer_onboarding_path(:company_info)
  end
end
