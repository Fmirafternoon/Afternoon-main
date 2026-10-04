class Agent::Candidates::EmploymentsController < Agent::BaseController
  def destroy
    @employment = Employment.find(params[:id])
    @candidate = @employment.candidate

    authorize @candidate

    if @employment.destroy
      redirect_to agent_candidate_wizard_path(@candidate, :employments), notice: "Expérience supprimée avec succès."
    else
      redirect_to agent_candidate_wizard_path(@candidate, :employments), alert: "La suppression de l'expérience a échoué."
    end
  end
end
