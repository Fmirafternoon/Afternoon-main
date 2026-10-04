require 'rails_helper'

RSpec.describe UnsubscribeController, type: :controller do
  describe 'GET #saved_search' do
    let(:customer) { create(:user, :customer) }
    let!(:saved_search) { create(:saved_search, customer: customer, email_alerts_enabled: true) }
    
    context 'with valid token for single search' do
      let(:valid_token) do
        Rails.application.message_verifier(:unsubscribe).generate({
          saved_search_id: saved_search.id,
          expires_at: 1.day.from_now
        })
      end
      
      it 'disables alerts for the saved search' do
        expect {
          get :saved_search, params: { id: saved_search.id, token: valid_token }
        }.to change { saved_search.reload.email_alerts_enabled }.from(true).to(false)
      end
      
      it 'redirects to root with success message' do
        get :saved_search, params: { id: saved_search.id, token: valid_token }
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('Alertes désactivées pour cette recherche')
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
      
      it 'disables all alerts for the customer' do
        get :saved_search, params: { token: valid_token, action_type: 'unsubscribe_all' }
        
        expect(saved_search.reload.email_alerts_enabled).to be false
        expect(other_search.reload.email_alerts_enabled).to be false
      end
      
      it 'redirects to root with success message' do
        get :saved_search, params: { token: valid_token, action_type: 'unsubscribe_all' }
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('Vous êtes désinscrits de toutes les alertes email')
      end
    end
    
    context 'with expired token' do
      let(:expired_token) do
        Rails.application.message_verifier(:unsubscribe).generate({
          saved_search_id: saved_search.id,
          expires_at: 1.day.ago
        })
      end
      
      it 'does not change alert status' do
        expect {
          get :saved_search, params: { id: saved_search.id, token: expired_token }
        }.not_to change { saved_search.reload.email_alerts_enabled }
      end
      
      it 'redirects with error message' do
        get :saved_search, params: { id: saved_search.id, token: expired_token }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Lien invalide ou expiré')
      end
    end
    
    context 'with invalid token' do
      it 'does not change alert status' do
        expect {
          get :saved_search, params: { id: saved_search.id, token: 'invalid_token' }
        }.not_to change { saved_search.reload.email_alerts_enabled }
      end
      
      it 'redirects with error message' do
        get :saved_search, params: { id: saved_search.id, token: 'invalid_token' }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Lien invalide ou expiré')
      end
    end
  end
end