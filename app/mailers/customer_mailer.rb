class CustomerMailer < ApplicationMailer
  helper ApplicationHelper

  def candidate_pushed(project_candidate)
    @project_candidate = project_candidate
    @project = project_candidate.project
    @candidate = project_candidate.candidate
    @customer = @project.customer
    @access_token = project_candidate.to_sgid(expires_in: 30.days, for: "customer_view").to_s

    pdf_content = WickedPdf.new.pdf_from_string(
      render_to_string(
        template: "customer/projects/candidates/pdf",
        layout: "pdf"
      ),
      page_size: "A4",
      orientation: "Portrait",
      margin: { top: 0, bottom: 0, left: 0, right: 0 }
    )

    attachments["candidat-#{@project_candidate.anonymized_number}.pdf"] = pdf_content

    mail(
      to: @customer.email,
      subject: "[Afternoon] Nouveau candidat pour votre projet #{@project.title}"
    )
  end

  def meeting_request_confirmation(basket_item:)
    @basket_item = basket_item
    @agent = basket_item.agent
    @customer = basket_item.basket.customer
    @candidates = basket_item.candidates

    mail(
      to: @customer.email,
      reply_to: @agent.email,
      subject: "[Afternoon] Votre demande de rendez-vous a été envoyée"
    )
  end
end
