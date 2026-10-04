module ActiveAdmin
  class CommentPolicy < ApplicationPolicy
    # Policy pour les commentaires Active Admin
    # Hérite de ActiveAdmin::ApplicationPolicy qui autorise uniquement les super_admin
  end
end
