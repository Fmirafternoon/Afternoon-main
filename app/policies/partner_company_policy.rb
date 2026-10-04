class PartnerCompanyPolicy < ApplicationPolicy
  def destroy?
    (user.agent_manager? && record.recruitment_office == user.recruitment_office)
  end
end
