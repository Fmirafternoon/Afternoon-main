class Agent::CandidateDocumentsController < Agent::BaseController
  def create
    @candidate = Candidate.find(params[:candidate_id])
    @candidate_document = @candidate.candidate_documents.create(candidate_document_params)
    authorize @candidate_document
    if @candidate_document.save
      Resume::ImportJob.perform_async(@candidate.id)
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.append("document-links", partial: "agent/candidates/document_link", locals: { document: @candidate_document })
        }
        format.html { redirect_to agent_candidate_path(@candidate), notice: "Candidat mis à jour." }
      end
    else
      redirect_to agent_candidate_path(@candidate), alert: "Erreur lors de l'ajout du document"
    end
  end

  private

  def candidate_document_params
    params.require(:candidate_document).permit(:file_name, :url)
  end
end
