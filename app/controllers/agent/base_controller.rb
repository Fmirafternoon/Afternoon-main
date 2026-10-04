class Agent::BaseController < ApplicationController
  layout "agent"
  before_action :check_if_agent

  private

  def check_if_agent
    unless current_user.agent? || current_user.super_admin?
      redirect_to root_path, alert: "Vous n'êtes pas autorisé à accéder à cette page."
    end
  end
end
