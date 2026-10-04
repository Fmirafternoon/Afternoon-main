require 'rails_helper'

RSpec.describe Agent::CompanyLocationsController, type: :controller do
  let(:company) { create(:company) }
  let(:location) { create(:location) }
  let(:company_location) { create(:company_location, company: company, location: location) }
  
  let(:recruitment_office) { create(:recruitment_office) }
  let(:agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:agent_manager) { create(:user, :agent_manager, company: company, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:customer) { create(:user, :customer, company: company, terms_accepted_at: 1.day.ago) }
  let(:other_company_customer) { create(:user, :customer, company: create(:company), terms_accepted_at: 1.day.ago) }
  let(:non_agent) { create(:user, :customer, terms_accepted_at: 1.day.ago) }

  describe 'authentication and authorization' do
    context 'when not logged in' do
      it 'redirects to sign in' do
        delete :destroy, params: { id: company_location.id }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as non-agent' do
      before { sign_in non_agent }

      it 'redirects to root with alert' do
        delete :destroy, params: { id: company_location.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Vous n'êtes pas autorisé à accéder à cette page.")
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when logged in as agent manager with access to the company' do
      before { sign_in agent_manager }

      it 'deletes the company location' do
        company_location # ensure it exists
        expect {
          delete :destroy, params: { id: company_location.id }
        }.to change(CompanyLocation, :count).by(-1)
      end

      it 'redirects back with success notice' do
        delete :destroy, params: { id: company_location.id }
        expect(response).to redirect_to(agent_onboarding_path(:company_info))
        expect(flash[:notice]).to eq("Location supprimée avec succès")
      end
    end

    context 'when logged in as agent without manager role' do
      before { sign_in agent }

      it 'raises Pundit authorization error' do
        expect {
          delete :destroy, params: { id: company_location.id }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'when logged in as customer with access to the company' do
      before { sign_in customer }

      it 'redirects to root with alert' do
        delete :destroy, params: { id: company_location.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Vous n'êtes pas autorisé à accéder à cette page.")
      end
    end

    context 'when logged in as customer without access to the company' do
      before { sign_in other_company_customer }

      it 'redirects to root with alert' do
        delete :destroy, params: { id: company_location.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Vous n'êtes pas autorisé à accéder à cette page.")
      end
    end

    context 'when company location does not exist' do
      before { sign_in agent_manager }

      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          delete :destroy, params: { id: 999999 }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with custom referrer' do
      before { sign_in agent_manager }

      it 'redirects back to the referrer' do
        request.env['HTTP_REFERER'] = '/custom/path'
        delete :destroy, params: { id: company_location.id }
        expect(response).to redirect_to('/custom/path')
      end
    end
  end
end