module ActiveAdmin
  class UserPolicy < ApplicationPolicy
    # Hérite de ActiveAdmin::ApplicationPolicy qui autorise uniquement les super_admin

    def invite?
      user&.super_admin?
    end

    def impersonate?
      user&.super_admin?
    end
  end
end
