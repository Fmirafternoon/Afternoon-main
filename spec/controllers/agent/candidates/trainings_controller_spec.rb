require 'rails_helper'

RSpec.describe Agent::Candidates::TrainingsController, type: :controller do
  let(:recruitment_office) { create(:recruitment_office) }
  let(:agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:other_agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:customer) { create(:user, :customer, terms_accepted_at: 1.day.ago) }
  let(:candidate) { create(:candidate, agent: agent) }
  let(:other_candidate) { create(:candidate, agent: other_agent) }
  let!(:training) { create(:training, candidate: candidate) }
  let!(:other_training) { create(:training, candidate: other_candidate) }

  describe 'authentication' do
    context 'when not logged in' do
      it 'redirects to sign in' do
        delete :destroy, params: { id: training.id }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as non-agent' do
      before { sign_in customer }

      it 'redirects to root with alert' do
        delete :destroy, params: { id: training.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Vous n'êtes pas autorisé à accéder à cette page.")
      end
    end
  end

  describe 'DELETE #destroy' do
    before { sign_in agent }

    context 'with own candidate training' do
      it 'deletes the training' do
        expect {
          delete :destroy, params: { id: training.id }
        }.to change(Training, :count).by(-1)
      end

      it 'redirects to wizard trainings step with success notice' do
        delete :destroy, params: { id: training.id }
        expect(response).to redirect_to(agent_candidate_wizard_path(candidate, :trainings))
        expect(flash[:notice]).to eq("Formation supprimée avec succès.")
      end
    end

    context 'with other agent training' do
      it 'raises not found error' do
        expect {
          delete :destroy, params: { id: other_training.id }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'when destroy fails' do
      before do
        allow_any_instance_of(Training).to receive(:destroy).and_return(false)
      end

      it 'redirects with alert' do
        delete :destroy, params: { id: training.id }
        expect(response).to redirect_to(agent_candidate_wizard_path(candidate, :trainings))
        expect(flash[:alert]).to eq("La suppression de la formation a échoué.")
      end
    end
  end
end