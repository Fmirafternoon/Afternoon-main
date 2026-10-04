class SavedSearchPolicy < ApplicationPolicy
  def new?
    user.customer?
  end

  def create?
    user.customer?
  end

  def destroy?
    user.customer? && record.customer_id == user.id
  end

  def load?
    user.customer? && record.customer_id == user.id
  end

  def toggle_alerts?
    user.customer? && record.customer_id == user.id
  end
end