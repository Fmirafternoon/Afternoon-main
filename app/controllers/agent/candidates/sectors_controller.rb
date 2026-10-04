class Agent::Candidates::SectorsController < Agent::BaseController
  def destroy
    @candidate_sector = CandidateSector.find(params[:id])
    @candidate = @candidate_sector.candidate

    authorize @candidate

    if @candidate_sector.destroy
      redirect_to agent_candidate_wizard_path(@candidate, :skills), notice: "Secteur d'activité supprimé avec succès."
    else
      redirect_to agent_candidate_wizard_path(@candidate, :skills), alert: "La suppression du secteur d'activité a échoué."
    end
  end
end
