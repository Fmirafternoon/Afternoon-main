class Agent::Candidates::ReferralsController < Agent::BaseController
  def destroy
    @referral = Referral.find(params[:id])
    @candidate = @referral.candidate

    authorize @candidate

    if @referral.destroy
      redirect_to agent_candidate_wizard_path(@candidate, :referrals), notice: "Référence supprimée avec succès."
    else
      redirect_to agent_candidate_wizard_path(@candidate, :referrals), alert: "La suppression de la référence a échoué."
    end
  end
end
