module ActiveAdmin
  class CandidatePolicy < ApplicationPolicy
    # Hérite de ActiveAdmin::ApplicationPolicy qui autorise uniquement les super_admin

    def view_as_agent?
      user&.super_admin?
    end
  end
end
