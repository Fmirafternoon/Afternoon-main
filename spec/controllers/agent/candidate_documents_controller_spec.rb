require 'rails_helper'

RSpec.describe Agent::CandidateDocumentsController, type: :controller do
  let(:recruitment_office) { create(:recruitment_office) }
  let(:agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:other_agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:customer) { create(:user, :customer, terms_accepted_at: 1.day.ago) }
  let(:candidate) { create(:candidate, agent: agent) }
  let(:other_candidate) { create(:candidate, agent: other_agent) }

  before do
    allow(Resume::ImportJob).to receive(:perform_async).and_return(true)
  end

  describe 'authentication' do
    context 'when not logged in' do
      it 'redirects to sign in' do
        post :create, params: { 
          candidate_id: candidate.id,
          candidate_document: { file_name: 'test.pdf', url: 'http://example.com/test.pdf' }
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as non-agent' do
      before { sign_in customer }

      it 'redirects to root with alert' do
        post :create, params: {
          candidate_id: candidate.id,
          candidate_document: { file_name: 'test.pdf', url: 'http://example.com/test.pdf' }
        }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Vous n'êtes pas autorisé à accéder à cette page.")
      end
    end
  end

  describe 'POST #create' do
    before { sign_in agent }

    let(:valid_params) do
      {
        candidate_id: candidate.id,
        candidate_document: {
          file_name: 'resume.pdf',
          url: 'https://example.com/resume.pdf'
        }
      }
    end

    context 'with valid params' do
      it 'creates a new candidate document' do
        expect {
          post :create, params: valid_params
        }.to change(CandidateDocument, :count).by(1)
      end

      it 'assigns document to the candidate' do
        post :create, params: valid_params
        document = CandidateDocument.last
        expect(document.candidate).to eq(candidate)
        expect(document.file_name).to eq('resume.pdf')
        expect(document.url).to eq('https://example.com/resume.pdf')
      end

      it 'calls Resume::ImportJob' do
        expect(Resume::ImportJob).to receive(:perform_async).with(candidate.id)
        post :create, params: valid_params
      end

      context 'with turbo_stream format' do
        it 'returns turbo stream response' do
          post :create, params: valid_params, format: :turbo_stream
          expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        end
      end

      context 'with html format' do
        it 'redirects to candidate path with notice' do
          post :create, params: valid_params
          expect(response).to redirect_to(agent_candidate_path(candidate))
          expect(flash[:notice]).to eq("Candidat mis à jour.")
        end
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          candidate_id: candidate.id,
          candidate_document: {
            file_name: '',
            url: ''
          }
        }
      end

      before do
        allow_any_instance_of(CandidateDocument).to receive(:save).and_return(false)
      end

      it 'does not create a document' do
        expect {
          post :create, params: invalid_params
        }.not_to change(CandidateDocument, :count)
      end

      it 'redirects with alert' do
        post :create, params: invalid_params
        expect(response).to redirect_to(agent_candidate_path(candidate))
        expect(flash[:alert]).to eq("Erreur lors de l'ajout du document")
      end
    end

    context 'with other agent\'s candidate' do
      it 'raises authorization error' do
        expect {
          post :create, params: {
            candidate_id: other_candidate.id,
            candidate_document: { file_name: 'test.pdf', url: 'http://example.com/test.pdf' }
          }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end
end