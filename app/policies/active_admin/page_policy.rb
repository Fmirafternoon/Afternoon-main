module ActiveAdmin
  class PagePolicy < ApplicationPolicy
    # Policy pour les pages Active Admin (Dashboard, etc.)
    # Hérite de ActiveAdmin::ApplicationPolicy qui autorise uniquement les super_admin
  end
end
