class Agent::RedFlagsController < Agent::BaseController
  def update
    @red_flag = RedFlag.find(params[:id])
    authorize @red_flag
    @red_flag.update!(red_flag_params)
    redirect_to agent_candidate_path(@red_flag.candidate)
  end

  private

  def red_flag_params
    params.require(:red_flag).permit(:answer)
  end
end
