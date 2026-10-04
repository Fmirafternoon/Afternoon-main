class SkillPolicy < ApplicationPolicy
  def index?
    user.super_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.super_admin?
        scope.all
      else
        scope.none
      end
    end
  end
end
