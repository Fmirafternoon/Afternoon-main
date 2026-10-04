class RedFlagPolicy < ApplicationPolicy
  def update?
    user.agent? && record.candidate.agent == user
  end
end
