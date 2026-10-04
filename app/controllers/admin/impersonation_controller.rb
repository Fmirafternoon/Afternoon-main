module Admin
  class ImpersonationController < ApplicationController
    skip_after_action :verify_pundit_authorization

    def destroy
      # Récupérer l'URL de retour avant d'arrêter l'impersonation
      return_to = session[:impersonation_return_to] || admin_root_path
      session.delete(:impersonation_return_to)

      stop_impersonating_user
      redirect_to return_to, notice: "Impersonation arrêtée"
    end
  end
end
