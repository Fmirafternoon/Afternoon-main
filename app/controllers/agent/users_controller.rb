class Agent::UsersController < Agent::BaseController
  before_action :find_user, only: %i[show edit update invite destroy]

  def index
    @users = policy_scope(User).all.kept

    @pagy, @users = pagy(@users)
    authorize @users
  end

  def show
  end

  def new
    @user = User.new(recruitment_office_id: params[:recruitment_office_id])
    if params[:recruitment_office_id].present?
      @user.recruitment_office = params[:recruitment_office_id]
      @user.role = :agent_user
    end
    authorize @user
  end

  def create
    @user = User.new(user_params)
    authorize @user
    @user.password = Devise.friendly_token.first(16)
    @user.recruitment_office = current_user.recruitment_office

    if @user.save
      UserMailer.password_creation(@user).deliver_later
      @user.invitation_sent_at = Time.current
      @user.save
      redirect_to agent_user_path(@user), notice: "Utilisateur créé"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to agent_user_path(@user), notice: "Utilisateur modifié"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.discard
    redirect_to agent_users_path, notice: "Utilisateur supprimé"
  end

  def invite
    UserMailer.password_creation(@user).deliver_later
    @user.invitation_sent_at = Time.current
    @user.save
    redirect_to agent_user_path(@user)
  end

  private

  def user_params
    parameters = params.require(:user).permit(
      :email,
      :first_name,
      :last_name,
      :role,
      :recruitment_office_id
    )
    parameters[:role] = nil unless User::AGENT_ROLES.include?(params[:user][:role])
    parameters
  end

  def find_user
    @user = User.find(params[:id])
    authorize @user
  end
end
