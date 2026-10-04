require 'rails_helper'

RSpec.describe Customer::CompanyLocationsController, type: :controller do
  let(:company) { create(:company) }
  let(:other_company) { create(:company) }
  let(:customer) { create(:user, :customer, company: company, terms_accepted_at: 1.day.ago) }
  let(:other_customer) { create(:user, :customer, company: other_company, terms_accepted_at: 1.day.ago) }
  let(:location) { create(:location) }
  let!(:company_location) { create(:company_location, company: company, location: location) }
  let!(:other_company_location) { create(:company_location, company: other_company, location: location) }

  describe 'DELETE #destroy' do
    before { sign_in customer }

    it 'deletes the company location' do
      expect {
        delete :destroy, params: { id: company_location.id }
      }.to change(CompanyLocation, :count).by(-1)
    end

    it 'redirects to onboarding company info' do
      delete :destroy, params: { id: company_location.id }
      expect(response).to redirect_to(customer_onboarding_path(:company_info))
    end

    context 'with other company location' do
      it 'raises authorization error' do
        expect {
          delete :destroy, params: { id: other_company_location.id }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end
end