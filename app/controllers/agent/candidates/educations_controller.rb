class Agent::Candidates::EducationsController < Agent::BaseController
  def destroy
    @education = Education.find(params[:id])
    @candidate = @education.candidate

    authorize @candidate

    if @education.destroy
      redirect_to agent_candidate_wizard_path(@candidate, :educations), notice: "Formation supprimée avec succès."
    else
      redirect_to agent_candidate_wizard_path(@candidate, :educations), alert: "La suppression de la formation a échoué."
    end
  end
end
