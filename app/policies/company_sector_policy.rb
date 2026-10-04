class CompanySectorPolicy < ApplicationPolicy
  def destroy?
    (user.customer? && record.company == user.company) ||
    (user.agent_manager? && record.company == user.company)
  end
end
