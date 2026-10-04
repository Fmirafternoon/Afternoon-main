require 'rails_helper'

RSpec.describe "Customer::SavedSearches", type: :request do
  let(:customer) { create(:user, :customer) }
  let(:non_customer) { create(:user, :agent_user) }
  
  before do
    sign_in customer
  end

  describe 'GET /customer/saved_searches/new' do
    it 'renders successfully' do
      get new_customer_saved_search_path, params: { query: 'test' }
      expect(response).to be_successful
    end
    
    it 'includes search form' do
      get new_customer_saved_search_path
      expect(response).to be_successful
      expect(response.body).to include('saved_search')
    end
    
    it 'includes search params' do
      get new_customer_saved_search_path, params: { query: 'developer', city: 'Paris' }
      expect(response).to be_successful
      expect(response.body).to include('developer')
      expect(response.body).to include('Paris')
    end
    
  end

  describe 'POST /customer/saved_searches' do
    let(:valid_params) do
      {
        saved_search: {
          name: 'My Search',
          criteria: { 'query' => 'developer', 'city' => 'Paris' }.to_json
        }
      }
    end
    
    context 'with valid params' do
      it 'creates a new saved search' do
        expect {
          post customer_saved_searches_path, params: valid_params, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        }.to change(customer.saved_searches, :count).by(1)
      end
      
      it 'responds with turbo stream' do
        post customer_saved_searches_path, params: valid_params, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
      
      context 'with email alerts enabled' do
        let(:params_with_alerts) do
          {
            saved_search: {
              name: 'My Search with Alerts',
              criteria: { 'query' => 'developer', 'city' => 'Paris' }.to_json,
              email_alerts_enabled: '1'
            }
          }
        end
        
        it 'creates saved search with alerts enabled' do
          post customer_saved_searches_path, params: params_with_alerts, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
          
          saved_search = customer.saved_searches.last
          expect(saved_search.email_alerts_enabled).to be true
        end
      end
      
      context 'with email alerts disabled' do
        let(:params_without_alerts) do
          {
            saved_search: {
              name: 'My Search without Alerts',
              criteria: { 'query' => 'developer', 'city' => 'Paris' }.to_json,
              email_alerts_enabled: '0'
            }
          }
        end
        
        it 'creates saved search with alerts disabled' do
          post customer_saved_searches_path, params: params_without_alerts, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
          
          saved_search = customer.saved_searches.last
          expect(saved_search.email_alerts_enabled).to be false
        end
      end
    end
    
    context 'with invalid params' do
      let(:invalid_params) do
        {
          saved_search: {
            name: '',
            criteria: {}.to_json
          }
        }
      end
      
      it 'does not create a saved search' do
        expect {
          post customer_saved_searches_path, params: invalid_params, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        }.not_to change(SavedSearch, :count)
      end
      
      it 'responds with error turbo stream' do
        post customer_saved_searches_path, params: invalid_params, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end
    
  end

  describe 'DELETE /customer/saved_searches/:id' do
    let!(:saved_search) { create(:saved_search, customer: customer) }
    
    it 'destroys the saved search' do
      expect {
        delete customer_saved_search_path(saved_search), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      }.to change(customer.saved_searches, :count).by(-1)
    end
    
    it 'responds with turbo stream' do
      delete customer_saved_search_path(saved_search), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end
    
    context 'when trying to delete another customer\'s search' do
      let(:other_customer) { create(:user, :customer) }
      let!(:other_search) { create(:saved_search, customer: other_customer) }
      
      it 'returns not found' do
        delete customer_saved_search_path(other_search), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /customer/saved_searches/:id/load' do
    let!(:saved_search) do
      create(:saved_search, 
        customer: customer,
        criteria: { 'query' => 'developer', 'city' => 'Paris' }
      )
    end
    
    context 'with turbo stream format' do
      it 'updates last_used_at' do
        expect {
          get load_customer_saved_search_path(saved_search), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        }.to change { saved_search.reload.last_used_at }
      end
      
      it 'responds with turbo stream' do
        get load_customer_saved_search_path(saved_search), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end
    
    context 'with html format' do
      it 'redirects to candidates index with criteria' do
        get load_customer_saved_search_path(saved_search)
        expect(response).to redirect_to(customer_candidates_path(
          saved_search.criteria.merge(saved_search_id: saved_search.id)
        ))
      end
    end
  end

  describe 'POST /customer/saved_searches/:id/toggle_alerts' do
    let!(:saved_search) { create(:saved_search, customer: customer, email_alerts_enabled: false) }
    
    context 'when alerts are disabled' do
      it 'enables alerts' do
        expect {
          post toggle_alerts_customer_saved_search_path(saved_search), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        }.to change { saved_search.reload.email_alerts_enabled }.from(false).to(true)
      end
      
      it 'responds with turbo stream' do
        post toggle_alerts_customer_saved_search_path(saved_search), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
      
      it 'includes success message' do
        post toggle_alerts_customer_saved_search_path(saved_search), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(response.body).to include('Alertes activées')
      end
    end
    
    context 'when alerts are enabled' do
      before { saved_search.update!(email_alerts_enabled: true) }
      
      it 'disables alerts' do
        expect {
          post toggle_alerts_customer_saved_search_path(saved_search), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        }.to change { saved_search.reload.email_alerts_enabled }.from(true).to(false)
      end
      
      it 'includes success message' do
        post toggle_alerts_customer_saved_search_path(saved_search), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(response.body).to include('Alertes désactivées')
      end
    end
    
    context 'when trying to toggle another customer\'s search' do
      let(:other_customer) { create(:user, :customer) }
      let!(:other_search) { create(:saved_search, customer: other_customer) }
      
      it 'returns not found' do
        post toggle_alerts_customer_saved_search_path(other_search), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /unsubscribe/saved_search/:id' do
    let!(:saved_search) { create(:saved_search, customer: customer, email_alerts_enabled: true) }
    
    context 'with valid token for single search' do
      let(:valid_token) do
        Rails.application.message_verifier(:unsubscribe).generate({
          saved_search_id: saved_search.id,
          expires_at: 1.day.from_now
        })
      end
      
      before { sign_out customer } # Unsubscribe should work without login
      
      it 'disables alerts for the saved search' do
        expect {
          get unsubscribe_saved_search_path(saved_search, token: valid_token)
        }.to change { saved_search.reload.email_alerts_enabled }.from(true).to(false)
      end
      
      it 'redirects to root with success message' do
        get unsubscribe_saved_search_path(saved_search, token: valid_token)
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to include('Alertes désactivées pour cette recherche')
      end
    end
    
    context 'with valid token for unsubscribe all' do
      let!(:other_search) { create(:saved_search, customer: customer, email_alerts_enabled: true) }
      let(:valid_token) do
        Rails.application.message_verifier(:unsubscribe).generate({
          customer_id: customer.id,
          action: 'unsubscribe_all',
          expires_at: 1.day.from_now
        })
      end
      
      before { sign_out customer }
      
      it 'disables all alerts for the customer' do
        get unsubscribe_all_saved_searches_path(token: valid_token, action_type: 'unsubscribe_all')
        
        expect(saved_search.reload.email_alerts_enabled).to be false
        expect(other_search.reload.email_alerts_enabled).to be false
      end
      
      it 'redirects to root with success message' do
        get unsubscribe_all_saved_searches_path(token: valid_token, action_type: 'unsubscribe_all')
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to include('désinscrits de toutes les alertes')
      end
    end
    
    context 'with expired token' do
      let(:expired_token) do
        Rails.application.message_verifier(:unsubscribe).generate({
          saved_search_id: saved_search.id,
          expires_at: 1.day.ago
        })
      end
      
      before { sign_out customer }
      
      it 'does not change alert status' do
        expect {
          get unsubscribe_saved_search_path(saved_search, token: expired_token)
        }.not_to change { saved_search.reload.email_alerts_enabled }
      end
      
      it 'redirects with error message' do
        get unsubscribe_saved_search_path(saved_search, token: expired_token)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('Lien invalide ou expiré')
      end
    end
    
    context 'with invalid token' do
      before { sign_out customer }
      
      it 'does not change alert status' do
        expect {
          get unsubscribe_saved_search_path(saved_search, token: 'invalid_token')
        }.not_to change { saved_search.reload.email_alerts_enabled }
      end
      
      it 'redirects with error message' do
        get unsubscribe_saved_search_path(saved_search, token: 'invalid_token')
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('Lien invalide ou expiré')
      end
    end
  end

  describe 'authorization' do
    context 'when not signed in' do
      before { sign_out customer }
      
      it 'redirects to sign in' do
        get new_customer_saved_search_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    context 'when signed in as non-customer' do
      before do
        sign_out customer
        sign_in non_customer
      end
      
      it 'returns not found' do
        get new_customer_saved_search_path
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end