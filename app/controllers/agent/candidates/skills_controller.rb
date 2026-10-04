class Agent::Candidates::SkillsController < Agent::BaseController
  def update
    @candidate_skill = CandidateSkill.find(params[:id])
    @candidate = @candidate_skill.candidate

    authorize @candidate

    if @candidate_skill.update(candidate_skill_params)
      redirect_to agent_candidate_wizard_path(@candidate, :skills), notice: "Compétence mise à jour."
    else
      redirect_to agent_candidate_wizard_path(@candidate, :skills), alert: "La mise à jour a échoué."
    end
  end


  def edit
    @candidate_skill = CandidateSkill.find(params[:id])
    @candidate = @candidate_skill.candidate
    authorize @candidate
  end







  def destroy
    @candidate_skill = CandidateSkill.find(params[:id])
    @candidate = @candidate_skill.candidate

    authorize @candidate

    if @candidate_skill.destroy
      redirect_to agent_candidate_wizard_path(@candidate, :skills), notice: "Compétence supprimée avec succès."
    else
      redirect_to agent_candidate_wizard_path(@candidate, :skills), alert: "La suppression de la compétence a échoué."
    end
  end

  private

  def candidate_skill_params
    params.require(:candidate_skill).permit(:seniority, :experience)
  end
end
