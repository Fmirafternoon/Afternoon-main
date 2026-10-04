class ProjectPolicy < ApplicationPolicy
  def index?
    user.customer? || user.agent? || user.super_admin?
  end

  def show?
    owner? || agent_with_candidate? || user.super_admin?
  end

  def new?
    user.customer?
  end

  def create?
    user.customer?
  end

  def edit?
    owner?
  end

  def update?
    owner?
  end

  def destroy?
    owner?
  end

  def duplicate?
    owner?
  end

  def archive?
    owner?
  end

  def unarchive?
    owner?
  end

  def save_draft?
    owner?
  end

  def rebroadcast?
    owner?
  end

  private

  def owner?
    user.customer? && record.customer_id == user.id
  end

  def agent_with_candidate?
    return false unless user.agent?

    record.project_candidates
          .joins(:candidate)
          .where(candidates: { agent_id: user.id })
          .where.not(status: :pending)
          .exists?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.super_admin?
        scope.all
      elsif user.agent?
        # Agent ne voit que les projets où il a au moins 1 candidat matché
        scope.joins(project_candidates: :candidate)
             .where(candidates: { agent_id: user.id })
             .where.not(project_candidates: { status: :pending })
             .distinct
      else
        scope.where(customer_id: user.id)
      end
    end
  end
end
