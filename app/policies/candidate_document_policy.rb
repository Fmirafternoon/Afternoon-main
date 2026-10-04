class CandidateDocumentPolicy < ApplicationPolicy
  def create?
    user.agent? && record.candidate.agent == user
  end
end
