require 'rails_helper'

RSpec.describe Agent::CandidatesController, type: :controller do
  let(:recruitment_office) { create(:recruitment_office) }
  let(:agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:other_agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:customer) { create(:user, :customer, terms_accepted_at: 1.day.ago) }
  
  let!(:published_candidate) { create(:candidate, agent: agent, publication_status: :published) }
  let!(:draft_candidate) { create(:candidate, agent: agent, publication_status: :draft) }
  let!(:archived_candidate) { create(:candidate, agent: agent, publication_status: :draft, discarded_at: Time.current) }
  let!(:other_agent_candidate) { create(:candidate, agent: other_agent) }

  before do
    # Stub external services
    allow(Embedding::Create).to receive(:call).and_return(
      OpenStruct.new(embedding: Array.new(1024, 0.1))
    )
    allow(EmbeddingCache).to receive(:get_embedding).and_return(Array.new(1024, 0.1))
    allow(Resume::UpsertBatch).to receive(:call).and_return(true)
    allow(Resume::ImportJob).to receive(:perform_async).and_return(true)
    allow(Cloudinary::DestroyFromUrl).to receive(:call).and_return(true)
  end

  describe 'authentication and authorization' do
    context 'when not logged in' do
      it 'redirects to sign in' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as non-agent' do
      before { sign_in customer }

      it 'redirects to root with alert' do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Vous n'êtes pas autorisé à accéder à cette page.")
      end
    end
  end

  describe 'GET #index' do
    before { sign_in agent }

    context 'without status filter' do
      it 'returns all kept candidates for the agent' do
        get :index
        expect(assigns(:candidates)).to include(published_candidate, draft_candidate)
        expect(assigns(:candidates)).not_to include(archived_candidate)
        expect(assigns(:candidates)).not_to include(other_agent_candidate)
      end
    end

    context 'with archived status' do
      it 'returns only archived candidates' do
        get :index, params: { status: 'archived' }
        expect(assigns(:candidates)).to include(archived_candidate)
        expect(assigns(:candidates)).not_to include(published_candidate, draft_candidate)
      end
    end

    context 'with draft status' do
      it 'returns draft and pending candidates' do
        get :index, params: { status: 'draft' }
        expect(assigns(:candidates)).to include(draft_candidate)
        expect(assigns(:candidates)).not_to include(published_candidate)
      end
    end

    context 'with published status' do
      it 'returns only published candidates' do
        get :index, params: { status: 'published' }
        expect(assigns(:candidates)).to include(published_candidate)
        expect(assigns(:candidates)).not_to include(draft_candidate)
      end
    end

    it 'orders candidates by created_at desc' do
      get :index
      sql = assigns(:candidates).to_sql
      expect(sql).to match(/ORDER BY.*created_at.*DESC/i)
    end
  end

  describe 'GET #show' do
    before { sign_in agent }

    it 'assigns the candidate' do
      get :show, params: { id: published_candidate.id }
      expect(assigns(:candidate)).to eq(published_candidate)
    end

    it 'raises error for other agent\'s candidate' do
      expect {
        get :show, params: { id: other_agent_candidate.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET #new' do
    before { sign_in agent }

    it 'assigns a new candidate' do
      get :new
      expect(assigns(:candidate)).to be_a_new(Candidate)
    end
  end

  describe 'POST #create' do
    before { sign_in agent }

    let(:valid_params) do
      {
        candidate: {
          first_name: 'John',
          last_name: 'Doe',
          resume_url: 'https://example.com/resume.pdf',
          resume_file_name: 'resume.pdf'
        }
      }
    end

    context 'with valid params' do
      it 'creates a new candidate' do
        expect {
          post :create, params: valid_params
        }.to change(Candidate, :count).by(1)
      end

      it 'assigns the current user as agent' do
        post :create, params: valid_params
        expect(Candidate.last.agent).to eq(agent)
      end

      it 'calls Resume::UpsertBatch' do
        expect(Resume::UpsertBatch).to receive(:call).with(
          candidate: an_instance_of(Candidate),
          user: agent
        )
        post :create, params: valid_params
      end

      context 'with turbo_stream format' do
        it 'returns turbo stream response' do
          post :create, params: valid_params.merge(temp_id: 'temp_123'), format: :turbo_stream
          expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        end
      end

      context 'with html format' do
        it 'redirects to candidates path' do
          post :create, params: valid_params
          expect(response).to redirect_to(agent_candidates_path)
          expect(flash[:notice]).to eq('Candidate créé.')
        end
      end
    end

    context 'with invalid params' do
      let(:invalid_params) { { candidate: { first_name: '' } } }

      it 'does not create a candidate' do
        allow_any_instance_of(Candidate).to receive(:save).and_return(false)
        expect {
          post :create, params: invalid_params
        }.not_to change(Candidate, :count)
      end

      it 'renders new template' do
        allow_any_instance_of(Candidate).to receive(:save).and_return(false)
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end
    end
  end


  describe 'PUT #update' do
    before { sign_in agent }

    let(:update_params) do
      {
        id: draft_candidate.id,
        candidate: {
          first_name: 'Updated',
          resume_url: 'https://example.com/new_resume.pdf'
        }
      }
    end

    context 'with valid params' do
      it 'updates the candidate' do
        put :update, params: update_params
        draft_candidate.reload
        expect(draft_candidate.first_name).to eq('Updated')
      end

      it 'calls Resume::ImportJob' do
        expect(Resume::ImportJob).to receive(:perform_async).with(draft_candidate.id)
        put :update, params: update_params
      end

      context 'with turbo_stream format' do
        it 'returns turbo stream response' do
          put :update, params: update_params, format: :turbo_stream
          expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        end
      end

      context 'with html format' do
        it 'redirects to candidate path' do
          put :update, params: update_params
          expect(response).to redirect_to(agent_candidate_path(draft_candidate))
          expect(flash[:notice]).to eq('Candidat mis à jour.')
        end
      end
    end

    context 'with invalid params' do
      before do
        allow_any_instance_of(Candidate).to receive(:update).and_return(false)
      end

      it 'returns unprocessable entity status' do
        expect(controller).to receive(:render).with(:edit, status: :unprocessable_entity)
        put :update, params: update_params
      end
    end
  end

  describe 'POST #archive' do
    before { sign_in agent }

    it 'archives the candidate' do
      post :archive, params: { id: published_candidate.id }
      published_candidate.reload
      expect(published_candidate.publication_status).to eq('draft')
      expect(published_candidate).to be_discarded
    end

    it 'redirects back with notice' do
      request.env['HTTP_REFERER'] = agent_candidates_path
      post :archive, params: { id: published_candidate.id }
      expect(response).to redirect_to(agent_candidates_path)
      expect(flash[:notice]).to eq('Candidat archivé.')
    end
  end

  describe 'POST #restore' do
    before { sign_in agent }

    it 'restores the candidate' do
      post :restore, params: { id: archived_candidate.id }
      archived_candidate.reload
      expect(archived_candidate).not_to be_discarded
    end

    it 'redirects back with notice' do
      request.env['HTTP_REFERER'] = agent_candidates_path
      post :restore, params: { id: archived_candidate.id }
      expect(response).to redirect_to(agent_candidates_path)
      expect(flash[:notice]).to eq('Candidat restauré.')
    end
  end

  describe 'DELETE #destroy' do
    before { sign_in agent }

    it 'destroys the candidate' do
      expect {
        delete :destroy, params: { id: draft_candidate.id }
      }.to change(Candidate, :count).by(-1)
    end

    it 'calls Cloudinary::DestroyFromUrl if resume_url present' do
      draft_candidate.update(resume_url: 'https://cloudinary.com/resume.pdf')
      expect(Cloudinary::DestroyFromUrl).to receive(:call).with(url: 'https://cloudinary.com/resume.pdf')
      delete :destroy, params: { id: draft_candidate.id }
    end

    it 'redirects to candidates path' do
      delete :destroy, params: { id: draft_candidate.id }
      expect(response).to redirect_to(agent_candidates_path)
      expect(flash[:alert]).to eq('Candidat supprimé définitivement.')
    end
  end

  describe 'POST #publish' do
    before { sign_in agent }

    context 'when publishing succeeds' do
      before do
        allow_any_instance_of(Candidate).to receive(:publish_workflow).and_return(true)
      end

      it 'publishes the candidate' do
        post :publish, params: { id: draft_candidate.id }
        expect(response).to redirect_to(agent_candidate_path(draft_candidate))
        expect(flash[:notice]).to eq('Candidat publié !')
      end
    end

    context 'when publishing fails' do
      before do
        allow_any_instance_of(Candidate).to receive(:publish_workflow).and_return(false)
      end

      it 'redirects with alert' do
        post :publish, params: { id: draft_candidate.id }
        expect(response).to redirect_to(agent_candidate_path(draft_candidate))
        expect(flash[:alert]).to eq('Impossible de soumettre le candidat')
      end
    end
  end

  describe 'DELETE #cancel' do
    before { sign_in agent }

    let!(:uploading_candidate) { create(:candidate, agent: agent, import_status: :uploading) }
    let!(:pending_candidate) { create(:candidate, agent: agent, import_status: :pending) }

    it 'discards candidates with uploading/pending/failed status' do
      delete :cancel
      [uploading_candidate, pending_candidate].each do |candidate|
        expect(candidate.reload).to be_discarded
      end
    end

    it 'calls Cloudinary destroy for candidates with resume_url' do
      uploading_candidate.update(resume_url: 'https://cloudinary.com/resume.pdf')
      expect(Cloudinary::DestroyFromUrl).to receive(:call).at_least(:once)
      delete :cancel
    end

    it 'redirects to candidates path' do
      delete :cancel
      expect(response).to redirect_to(agent_candidates_path)
      expect(response).to have_http_status(:see_other)
    end
  end

end