class CandidatePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.super_admin?
        scope.all
      elsif user.agent?
        scope.where(agent: user)
      elsif user.customer?
        scope.kept.published
      else
        scope.none
      end
    end
  end

  def index?
    user.agent?
  end

  def show?
    (user.agent? && record.agent == user) || (user.customer? && record.published?)
  end

  def new?
    user.agent?
  end

  def create?
    new?
  end

  def edit?
    user.agent? && record.agent == user
  end

  def update?
    edit?
  end

  def archive?
    user.agent? && record.agent == user
  end

  def restore?
    user.agent? && record.agent == user
  end

  def destroy?
    user.agent? && record.agent == user
  end

  def cancel?
    user.agent?
  end

  def publish?
    user.agent? && record.agent == user
  end
end
