class TermPolicy < ApplicationPolicy
  def new?
    true
  end

  def create?
    new?
  end
end
