require 'rails_helper'

RSpec.describe Agent::Candidates::EducationsController, type: :controller do
  let(:recruitment_office) { create(:recruitment_office) }
  let(:agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:other_agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:customer) { create(:user, :customer, terms_accepted_at: 1.day.ago) }
  let(:candidate) { create(:candidate, agent: agent) }
  let(:other_candidate) { create(:candidate, agent: other_agent) }
  let!(:education) { create(:education, candidate: candidate) }
  let!(:other_education) { create(:education, candidate: other_candidate) }

  describe 'authentication' do
    context 'when not logged in' do
      it 'redirects to sign in' do
        delete :destroy, params: { id: education.id }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as non-agent' do
      before { sign_in customer }

      it 'redirects to root with alert' do
        delete :destroy, params: { id: education.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Vous n'êtes pas autorisé à accéder à cette page.")
      end
    end
  end

  describe 'DELETE #destroy' do
    before { sign_in agent }

    context 'with own candidate education' do
      it 'deletes the education' do
        expect {
          delete :destroy, params: { id: education.id }
        }.to change(Education, :count).by(-1)
      end

      it 'redirects to wizard educations step with success notice' do
        delete :destroy, params: { id: education.id }
        expect(response).to redirect_to(agent_candidate_wizard_path(candidate, :educations))
        expect(flash[:notice]).to eq("Formation supprimée avec succès.")
      end
    end

    context 'with other agent education' do
      it 'raises not found error' do
        expect {
          delete :destroy, params: { id: other_education.id }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'when destroy fails' do
      before do
        allow_any_instance_of(Education).to receive(:destroy).and_return(false)
      end

      it 'redirects with alert' do
        delete :destroy, params: { id: education.id }
        expect(response).to redirect_to(agent_candidate_wizard_path(candidate, :educations))
        expect(flash[:alert]).to eq("La suppression de la formation a échoué.")
      end
    end
  end
end