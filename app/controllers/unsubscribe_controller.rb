class UnsubscribeController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :check_terms_accepted
  skip_before_action :onboard_customer
  skip_before_action :onboard_agent
  skip_before_action :set_current_attributes
  skip_after_action :verify_pundit_authorization

  def saved_search
    begin
      payload = Rails.application.message_verifier(:unsubscribe).verify(params[:token])
      
      # Vérifier l'expiration
      if payload['expires_at'] && Time.parse(payload['expires_at']) < Time.current
        raise ActiveSupport::MessageVerifier::InvalidSignature
      end
      
      # Gérer la désinscription selon le type
      if params[:action_type] == 'unsubscribe_all' && payload['customer_id']
        customer = User.find(payload['customer_id'])
        customer.saved_searches.update_all(email_alerts_enabled: false)
        flash[:notice] = 'Vous êtes désinscrits de toutes les alertes email'
      elsif payload['saved_search_id']
        saved_search = SavedSearch.find(payload['saved_search_id'])
        saved_search.update!(email_alerts_enabled: false)
        flash[:notice] = 'Alertes désactivées pour cette recherche'
      else
        raise ActiveSupport::MessageVerifier::InvalidSignature
      end
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound => e
      Rails.logger.error "Unsubscribe error: #{e.message}"
      flash[:alert] = 'Lien invalide ou expiré'
    end
    
    redirect_to root_path
  end
end