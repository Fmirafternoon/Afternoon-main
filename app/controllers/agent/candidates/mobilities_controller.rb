class Agent::Candidates::MobilitiesController < Agent::BaseController
  def destroy
    @mobility = CandidateMobility.find(params[:id])
    @candidate = @mobility.candidate

    authorize @candidate

    if @mobility.destroy
      redirect_to agent_candidate_wizard_path(@candidate, :availability), notice: "Mobilité supprimée avec succès."
    else
      redirect_to agent_candidate_wizard_path(@candidate, :availability), alert: "La suppression de la mobilité a échoué."
    end
  end
end
