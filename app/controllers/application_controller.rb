class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  include Pagy::Backend
  include Pundit::Authorization

  impersonates :user

  before_action :authenticate_user!
  before_action :set_current_attributes
  before_action :check_terms_accepted
  before_action :onboard_customer
  before_action :onboard_agent

  after_action :verify_pundit_authorization, unless: -> { devise_controller? || active_admin_controller? }
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  helper_method :current_basket

  def current_basket
    @current_basket ||= Basket.for_customer(current_user)
  end

  private

  def onboard_customer
    return if active_admin_controller?
    return if true_user&.super_admin? && controller_path.include?("admin")
    return if controller_path == "customer/onboarding"
    return if controller_name == "terms"
    return unless user_signed_in? && current_user.customer?

    if !current_user.customer_onboarded?
      redirect_to customer_onboarding_path(:personal_info)
    end
  end

  def onboard_agent
    return if active_admin_controller?
    return if true_user&.super_admin? && controller_path.include?("admin")
    return if controller_path == "agent/onboarding"
    return if controller_name == "terms"
    return unless user_signed_in? && current_user.agent?

    if !current_user.agent_onboarded?
      redirect_to agent_onboarding_path(:personal_info)
    end
  end

  def check_terms_accepted
    return if active_admin_controller?
    if user_signed_in? &&
        (!current_user.terms_accepted_at || current_user.terms_accepted_at < DateTime.parse(ENV["TERMS_UPDATED_AT"])) &&
        controller_name != "terms"
      redirect_to new_term_path, alert: "Vous devez accepter les conditions d'utilisation pour continuer."
    end
  end

  def verify_pundit_authorization
    if action_name == "index"
      verify_policy_scoped
    else
      verify_authorized
    end
  end

  def user_not_authorized
    return if active_admin_controller?
    raise
    flash[:alert] = "Vous n'êtes pas autorisé à effectuer cette action."
    redirect_back(fallback_location: root_path)
  end

  def set_current_attributes
    Current.user = current_user
  end

  def pundit_user
    current_user
  end

  def active_admin_controller?
    is_a?(ActiveAdmin::BaseController) rescue false
  end

  def access_denied(exception)
    redirect_to root_path, alert: "Accès non autorisé."
  end
end
