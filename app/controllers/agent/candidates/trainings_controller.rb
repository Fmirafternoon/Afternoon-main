class Agent::Candidates::TrainingsController < Agent::BaseController
  def destroy
    @training = Training.find(params[:id])
    @candidate = @training.candidate

    authorize @candidate

    if @training.destroy
      redirect_to agent_candidate_wizard_path(@candidate, :trainings), notice: "Formation supprimée avec succès."
    else
      redirect_to agent_candidate_wizard_path(@candidate, :trainings), alert: "La suppression de la formation a échoué."
    end
  end
end
