class AgentMailerPreview < ActionMailer::Preview
  def candidate_matched
    pc = ProjectCandidate.joins(:candidate, :project)
                         .where("llm_analysis->>'summary' IS NOT NULL")
                         .first
    AgentMailer.candidate_matched(pc.id)
  end

  def import_complete
    user = User.agent.first
    candidates = Candidate.limit(3)
    AgentMailer.import_complete(user.id, candidates.pluck(:id))
  end

  def meeting_request
    basket_item = BasketItem.joins(:basket, :agent)
                            .first
    AgentMailer.meeting_request(basket_item: basket_item)
  end

  def customer_interested
    pc = ProjectCandidate.interested.first ||
         ProjectCandidate.pushed.first ||
         ProjectCandidate.first
    AgentMailer.customer_interested(pc)
  end

  def customer_rejected
    pc = ProjectCandidate.rejected.first ||
         ProjectCandidate.pushed.first ||
         ProjectCandidate.first
    AgentMailer.customer_rejected(pc)
  end

  def candidate_expiration_reminder
    candidate = Candidate.published.where.not(expires_at: nil).first ||
                Candidate.published.first ||
                Candidate.first
    AgentMailer.candidate_expiration_reminder(candidate.id)
  end
end
