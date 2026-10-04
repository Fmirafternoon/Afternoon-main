class Customer::Projects::CandidatesController < Customer::BaseController
  before_action :set_project
  before_action :set_project_candidate

  def show
    @project_candidate.mark_as_viewed!
  end

  def interest_form
    render layout: false
  end

  def interest
    message = params[:message]
    @project_candidate.express_interest!(message: message)
    AgentMailer.customer_interested(@project_candidate).deliver_later
    redirect_to customer_project_path(@project), notice: "Votre intérêt a été transmis au cabinet"
  end

  def reject_form
    render layout: false
  end

  def reject
    reason = params[:reason]
    @project_candidate.reject!(reason: reason)
    AgentMailer.customer_rejected(@project_candidate).deliver_later
    redirect_to customer_project_path(@project), notice: "Le candidat a été rejeté"
  end

  def pdf
    @candidate = @project_candidate.candidate

    pdf_content = WickedPdf.new.pdf_from_string(
      render_to_string(
        template: "customer/projects/candidates/pdf",
        layout: "pdf"
      ),
      page_size: "A4",
      orientation: "Portrait",
      margin: { top: 0, bottom: 0, left: 0, right: 0 }
    )

    send_data pdf_content,
      filename: "candidat-#{@project_candidate.anonymized_number}.pdf",
      type: "application/pdf",
      disposition: "attachment"
  end

  private

  def set_project
    @project = current_user.projects.find(params[:project_id])
    authorize @project, :show?
  end

  def set_project_candidate
    @project_candidate = @project.project_candidates.for_customer.find(params[:id])
  end
end
