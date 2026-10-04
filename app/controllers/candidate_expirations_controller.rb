class CandidateExpirationsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :check_terms_accepted
  skip_before_action :onboard_customer
  skip_before_action :onboard_agent
  skip_before_action :set_current_attributes
  skip_after_action :verify_pundit_authorization

  before_action :verify_token

  def extend_publication
    @candidate.extend_publication!
    redirect_to root_path, notice: 'Publication prolongée de 14 jours'
  rescue ActiveRecord::RecordInvalid
    redirect_to root_path, alert: 'Ce candidat n\'est plus publié'
  end

  def unpublish
    if @candidate.may_unpublish_workflow?
      @candidate.unpublish_workflow!
      redirect_to root_path, notice: 'Candidat dépublié avec succès'
    else
      redirect_to root_path, alert: 'Action impossible'
    end
  end

  private

  def verify_token
    begin
      data = Rails.application.message_verifier(:candidate_expiration).verify(params[:token])

      # Check expiration
      if data["expires_at"] && Time.parse(data["expires_at"]) < Time.current
        Rails.logger.warn "Expired token used for candidate expiration"
        redirect_to root_path, alert: 'Lien invalide ou expiré'
        return
      end

      @candidate = Candidate.find(data["candidate_id"])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      Rails.logger.error "Invalid token signature in candidate expiration"
      redirect_to root_path, alert: 'Lien invalide ou expiré'
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "Candidate not found for token in expiration action"
      redirect_to root_path, alert: 'Lien invalide ou expiré'
    end
  end
end
