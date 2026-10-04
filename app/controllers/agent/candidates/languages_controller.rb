class Agent::Candidates::LanguagesController < Agent::BaseController
  def destroy
    @candidate_language = CandidateLanguage.find(params[:id])
    @candidate = @candidate_language.candidate

    authorize @candidate

    if @candidate_language.destroy
      redirect_to agent_candidate_wizard_path(@candidate, :skills), notice: "Langue supprimée avec succès."
    else
      redirect_to agent_candidate_wizard_path(@candidate, :skills), alert: "La suppression de la langue a échoué."
    end
  end
end
