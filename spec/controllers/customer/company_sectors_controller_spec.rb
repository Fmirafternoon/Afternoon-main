require 'rails_helper'

RSpec.describe Customer::CompanySectorsController, type: :controller do
  let(:company) { create(:company) }
  let(:other_company) { create(:company) }
  let(:customer) { create(:user, :customer, company: company, terms_accepted_at: 1.day.ago) }
  let(:other_customer) { create(:user, :customer, company: other_company, terms_accepted_at: 1.day.ago) }
  let(:agent) { create(:user, :agent_user, terms_accepted_at: 1.day.ago) }
  let(:sector) { create(:sector) }
  let!(:company_sector) { create(:company_sector, company: company, sector: sector) }
  let!(:other_company_sector) { create(:company_sector, company: other_company, sector: sector) }

  describe 'authentication' do
    context 'when not logged in' do
      it 'redirects to sign in' do
        delete :destroy, params: { id: company_sector.id }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as non-customer' do
      before { sign_in agent }

      it 'redirects to root with alert' do
        delete :destroy, params: { id: company_sector.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Vous n'êtes pas autorisé à accéder à cette page.")
      end
    end
  end

  describe 'DELETE #destroy' do
    before { sign_in customer }

    context 'with own company sector' do
      it 'deletes the company sector' do
        expect {
          delete :destroy, params: { id: company_sector.id }
        }.to change(CompanySector, :count).by(-1)
      end

      it 'redirects to onboarding company info with success notice' do
        delete :destroy, params: { id: company_sector.id }
        expect(response).to redirect_to(customer_onboarding_path(:company_info))
        expect(flash[:notice]).to eq("Secteur d'activité supprimé avec succès.")
      end
    end

    context 'with other company sector' do
      it 'raises authorization error' do
        expect {
          delete :destroy, params: { id: other_company_sector.id }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'when destroy fails' do
      before do
        allow_any_instance_of(CompanySector).to receive(:destroy).and_return(false)
      end

      it 'redirects with alert' do
        delete :destroy, params: { id: company_sector.id }
        expect(response).to redirect_to(customer_onboarding_path(:company_info))
        expect(flash[:alert]).to eq("La suppression du secteur d'activité a échoué.")
      end
    end
  end
end