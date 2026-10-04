require 'rails_helper'

RSpec.describe Agent::Candidates::ReferralsController, type: :controller do
  let(:recruitment_office) { create(:recruitment_office) }
  let(:agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:other_agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:customer) { create(:user, :customer, terms_accepted_at: 1.day.ago) }
  let(:candidate) { create(:candidate, agent: agent) }
  let(:other_candidate) { create(:candidate, agent: other_agent) }
  let!(:referral) { create(:referral, candidate: candidate) }
  let!(:other_referral) { create(:referral, candidate: other_candidate) }

  describe 'authentication' do
    context 'when not logged in' do
      it 'redirects to sign in' do
        delete :destroy, params: { id: referral.id }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as non-agent' do
      before { sign_in customer }

      it 'redirects to root with alert' do
        delete :destroy, params: { id: referral.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Vous n'êtes pas autorisé à accéder à cette page.")
      end
    end
  end

  describe 'DELETE #destroy' do
    before { sign_in agent }

    context 'with own candidate referral' do
      it 'deletes the referral' do
        expect {
          delete :destroy, params: { id: referral.id }
        }.to change(Referral, :count).by(-1)
      end

      it 'redirects to wizard referrals step with success notice' do
        delete :destroy, params: { id: referral.id }
        expect(response).to redirect_to(agent_candidate_wizard_path(candidate, :referrals))
        expect(flash[:notice]).to eq("Référence supprimée avec succès.")
      end
    end

    context 'with other agent referral' do
      it 'raises not found error' do
        expect {
          delete :destroy, params: { id: other_referral.id }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'when destroy fails' do
      before do
        allow_any_instance_of(Referral).to receive(:destroy).and_return(false)
      end

      it 'redirects with alert' do
        delete :destroy, params: { id: referral.id }
        expect(response).to redirect_to(agent_candidate_wizard_path(candidate, :referrals))
        expect(flash[:alert]).to eq("La suppression de la référence a échoué.")
      end
    end
  end
end