class UserPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.super_admin?
        scope.all
      elsif user.agent_manager?
        scope.where(recruitment_office: user.recruitment_office)
      else
        scope.none
      end
    end
  end

  def index?
    user.super_admin? or user.agent_manager?
  end

  def show?
    user.super_admin? or (user.agent_manager? && same_office?) or user == record
  end

  def new?
    user.super_admin? or user.agent_manager?
  end

  def create?
    new?
  end

  def edit?
    user.super_admin? or (user.agent_manager? && same_office?) or user == record
  end

  def update?
    edit?
  end

  def destroy?
    user.super_admin? or (user.agent_manager? && same_office?)
  end

  def password?
    true
  end

  def invite?
    user.super_admin? or user.agent_manager?
  end

  def impersonate?
    user.super_admin?
  end

  # For the agent onboarding controller
  def onboarding?
    user.agent? && user == record
  end

  private

  def same_office?
    record && user.recruitment_office == record.recruitment_office
  end
end
