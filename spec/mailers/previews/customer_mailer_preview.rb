class CustomerMailerPreview < ActionMailer::Preview
  def candidate_pushed
    project_candidate = ProjectCandidate.pushed.where("agent_analysis->>'summary' IS NOT NULL").first
    project_candidate ||= ProjectCandidate.pushed.first
    project_candidate ||= ProjectCandidate.first

    CustomerMailer.candidate_pushed(project_candidate)
  end

  def meeting_request_confirmation
    basket_item = BasketItem.joins(:basket, :agent).first
    CustomerMailer.meeting_request_confirmation(basket_item: basket_item)
  end
end
