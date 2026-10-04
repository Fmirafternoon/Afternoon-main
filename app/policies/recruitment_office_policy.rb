class RecruitmentOfficePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.super_admin?
        scope.all
      else
        scope.none
      end
    end
  end

  def index?
    user.super_admin?
  end

  def show?
    user.super_admin?
  end

  def new?
    user.super_admin?
  end

  def create?
    new?
  end

  def edit?
    user.super_admin?
  end

  def update?
    edit?
  end
end
