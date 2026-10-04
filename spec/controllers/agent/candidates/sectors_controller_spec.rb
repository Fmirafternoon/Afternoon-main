require 'rails_helper'

RSpec.describe Agent::Candidates::SectorsController, type: :controller do
  let(:recruitment_office) { create(:recruitment_office) }
  let(:agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:other_agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:candidate) { create(:candidate, agent: agent) }
  let(:other_candidate) { create(:candidate, agent: other_agent) }
  let(:sector) { create(:sector) }
  let!(:candidate_sector) { create(:candidate_sector, candidate: candidate, sector: sector) }
  let!(:other_candidate_sector) { create(:candidate_sector, candidate: other_candidate, sector: sector) }

  describe 'DELETE #destroy' do
    before { sign_in agent }

    context 'with own candidate sector' do
      it 'deletes the candidate sector' do
        expect {
          delete :destroy, params: { id: candidate_sector.id }
        }.to change(CandidateSector, :count).by(-1)
      end

      it 'redirects to wizard skills step with success notice' do
        delete :destroy, params: { id: candidate_sector.id }
        expect(response).to redirect_to(agent_candidate_wizard_path(candidate, :skills))
        expect(flash[:notice]).to eq("Secteur d'activité supprimé avec succès.")
      end
    end

    context 'when destroy fails' do
      before do
        allow_any_instance_of(CandidateSector).to receive(:destroy).and_return(false)
      end

      it 'redirects with alert' do
        delete :destroy, params: { id: candidate_sector.id }
        expect(response).to redirect_to(agent_candidate_wizard_path(candidate, :skills))
        expect(flash[:alert]).to eq("La suppression du secteur d'activité a échoué.")
      end
    end
  end
end