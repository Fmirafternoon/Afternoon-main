require 'rails_helper'

RSpec.describe Customer::CandidatesController, type: :controller do
  before do
    # Stub the embedding API call with correct dimensions
    allow(Embedding::Create).to receive(:call).and_return(
      OpenStruct.new(embedding: Array.new(1024, 0.1))
    )
    # Also stub EmbeddingCache to avoid database calls
    allow(EmbeddingCache).to receive(:get_embedding).and_return(Array.new(1024, 0.1))
  end
  let(:customer) { create(:user, :customer, terms_accepted_at: 1.day.ago) }
  let(:non_customer) { create(:user, :agent_user, terms_accepted_at: 1.day.ago) }
  let(:recruitment_office) { create(:recruitment_office) }
  let(:agent) { create(:user, :agent_user, recruitment_office: recruitment_office) }
  
  let!(:published_candidate) { create(:candidate, agent: agent, publication_status: :published) }
  let!(:draft_candidate) { create(:candidate, agent: agent, publication_status: :draft) }
  let!(:discarded_candidate) { create(:candidate, agent: agent, publication_status: :published, discarded_at: Time.current) }
  
  let(:skill1) { create(:skill, name: 'Ruby') }
  let(:skill2) { create(:skill, name: 'Rails') }
  let(:sector1) { create(:sector, name: 'IT') }
  let(:sector2) { create(:sector, name: 'Finance') }

  describe 'authentication and authorization' do
    context 'when not logged in' do
      it 'redirects to sign in' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as non-customer' do
      before { sign_in non_customer }

      it 'redirects to root with alert' do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Vous n'êtes pas autorisé à accéder à cette page.")
      end
    end
  end

  describe 'GET #index' do
    before { sign_in customer }

    context 'with no search parameters' do
      it 'returns published and kept candidates' do
        get :index
        expect(assigns(:candidates)).to include(published_candidate)
        expect(assigns(:candidates)).not_to include(draft_candidate)
        expect(assigns(:candidates)).not_to include(discarded_candidate)
      end

      it 'initializes empty search form' do
        get :index
        expect(assigns(:search_form)).to be_a(Customer::SearchForm)
        expect(assigns(:search_form).query).to be_nil
      end

      it 'stores search form in session' do
        get :index
        expect(session[:search_form]).to be_present
      end

      it 'loads saved searches for customer' do
        saved_search = create(:saved_search, customer: customer)
        get :index
        expect(assigns(:saved_searches)).to include(saved_search)
      end
    end

    context 'with search parameters' do
      let(:search_params) do
        {
          customer_search_form: {
            query: 'developer',
            skills: ['Ruby', 'Rails'],
            sector_ids: [sector1.id.to_s, sector2.id.to_s]
          }
        }
      end

      before do
        allow(Candidate::Search).to receive(:call).and_return(
          OpenStruct.new(candidates: Candidate.where(publication_status: :published))
        )
      end

      it 'passes search parameters to search service' do
        expect(Candidate::Search).to receive(:call).with(
          scope: anything,
          form: an_instance_of(Customer::SearchForm)
        )
        get :index, params: search_params
      end

      it 'stores search parameters in session' do
        get :index, params: search_params
        expect(session[:search_form]).to be_present
        expect(session[:search_form]['query']).to eq('developer')
      end
    end

    context 'with new skill parameter' do
      let(:params_with_new_skill) do
        {
          customer_search_form: {
            skills: ['Ruby'],
            new_skill: 'Python'
          }
        }
      end

      it 'adds new skill to skills array and redirects' do
        get :index, params: params_with_new_skill
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('customer_search_form%5Bskills%5D%5B%5D=Ruby')
        expect(response.location).to include('customer_search_form%5Bskills%5D%5B%5D=Python')
      end

      it 'does not add duplicate skills' do
        params_with_duplicate = {
          customer_search_form: {
            skills: ['Ruby'],
            new_skill: 'Ruby'
          }
        }
        get :index, params: params_with_duplicate
        # When the skill is already in the array, no redirect happens
        expect(response).to have_http_status(:ok)
        expect(assigns(:search_form).skills).to eq(['Ruby'])
      end

      it 'strips whitespace from new skill' do
        params_with_spaces = {
          customer_search_form: {
            skills: [],
            new_skill: '  JavaScript  '
          }
        }
        get :index, params: params_with_spaces
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('customer_search_form%5Bskills%5D%5B%5D=JavaScript')
      end
    end

    context 'with duplicate values' do
      it 'removes duplicate skills' do
        params_with_duplicates = {
          customer_search_form: {
            skills: ['Ruby', 'Rails', 'Ruby'],
            sector_ids: []
          }
        }
        get :index, params: params_with_duplicates
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('customer_search_form%5Bskills%5D%5B%5D=Ruby')
        expect(response.location).to include('customer_search_form%5Bskills%5D%5B%5D=Rails')
      end

      it 'removes duplicate sector_ids' do
        params_with_duplicates = {
          customer_search_form: {
            skills: [],
            sector_ids: ['1', '2', '1']
          }
        }
        get :index, params: params_with_duplicates
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('customer_search_form%5Bsector_ids%5D%5B%5D=1')
        expect(response.location).to include('customer_search_form%5Bsector_ids%5D%5B%5D=2')
      end
    end

    context 'with saved search' do
      let(:saved_search) { create(:saved_search, customer: customer, criteria: { 'query' => 'saved query' }) }

      it 'loads saved search parameters' do
        get :index, params: { 
          saved_search_id: saved_search.id,
          query: 'saved query'
        }
        expect(assigns(:active_saved_search_id)).to eq(saved_search.id.to_s)
        expect(assigns(:search_form).query).to eq('saved query')
      end
    end
  end

  describe 'GET #show' do
    before { sign_in customer }

    context 'with valid candidate' do
      it 'assigns the candidate' do
        get :show, params: { id: published_candidate.id }
        expect(assigns(:candidate)).to eq(published_candidate)
      end

      it 'loads search form from session' do
        session[:search_form] = { query: 'test' }
        get :show, params: { id: published_candidate.id }
        expect(assigns(:search_form).query).to eq('test')
      end

      it 'initializes empty search form if no session' do
        get :show, params: { id: published_candidate.id }
        expect(assigns(:search_form)).to be_a(Customer::SearchForm)
      end
    end

    context 'with unauthorized candidate' do
      it 'raises Pundit error for draft candidate' do
        expect {
          get :show, params: { id: draft_candidate.id }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'with non-existent candidate' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :show, params: { id: 999999 }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end