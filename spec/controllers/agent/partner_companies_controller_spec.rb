require 'rails_helper'

RSpec.describe Agent::PartnerCompaniesController, type: :controller do
  let(:recruitment_office) { create(:recruitment_office) }
  let(:other_recruitment_office) { create(:recruitment_office) }
  let(:company) { create(:company) }
  let(:partner_company) { create(:partner_company, recruitment_office: recruitment_office, company: company) }
  let(:other_office_partner_company) { create(:partner_company, recruitment_office: other_recruitment_office, company: create(:company)) }
  
  let(:agent_manager) { create(:user, :agent_manager, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:other_office_agent_manager) { create(:user, :agent_manager, recruitment_office: other_recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:customer) { create(:user, :customer, terms_accepted_at: 1.day.ago) }

  describe 'authentication and authorization' do
    context 'when not logged in' do
      it 'redirects to sign in' do
        delete :destroy, params: { id: partner_company.id }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as non-agent' do
      before { sign_in customer }

      it 'redirects to root with alert' do
        delete :destroy, params: { id: partner_company.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Vous n'êtes pas autorisé à accéder à cette page.")
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when logged in as agent manager with access to the recruitment office' do
      before { sign_in agent_manager }

      it 'deletes the partner company' do
        partner_company # ensure it exists
        expect {
          delete :destroy, params: { id: partner_company.id }
        }.to change(PartnerCompany, :count).by(-1)
      end

      it 'redirects back with success notice' do
        delete :destroy, params: { id: partner_company.id }
        expect(response).to redirect_to(agent_onboarding_path(:company_info))
        expect(flash[:notice]).to eq("Entreprise partenaire supprimée avec succès")
      end
    end

    context 'when logged in as regular agent (not manager)' do
      before { sign_in agent }

      it 'raises Pundit authorization error' do
        expect {
          delete :destroy, params: { id: partner_company.id }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'when logged in as agent manager from different recruitment office' do
      before { sign_in other_office_agent_manager }

      it 'raises Pundit authorization error' do
        expect {
          delete :destroy, params: { id: partner_company.id }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'when partner company does not exist' do
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
        delete :destroy, params: { id: partner_company.id }
        expect(response).to redirect_to('/custom/path')
      end
    end

    context 'when trying to delete partner company from another recruitment office' do
      before { sign_in agent_manager }

      it 'raises Pundit authorization error' do
        expect {
          delete :destroy, params: { id: other_office_partner_company.id }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end
end