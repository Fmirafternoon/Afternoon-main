class Users::PasswordCreationsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create]
  before_action :find_user, only: [:new, :create]
  before_action :redirect_if_password_already_set

  layout "devise"

  # GET /users/password_creations/new?password_token=abcdef
  def new; end

  def create
    @user.password = password_params[:password]
    if @user.valid?
      @user.password_set_at = Time.current
      @user.save
      redirect_to new_user_session_path, notice: "Votre mot de passe a \u00E9t\u00E9 cr\u00E9\u00E9, vous pouvez d\u00E9sormais vous connecter"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def redirect_if_password_already_set
    redirect_to new_users_password_creation_path if @user&.password_set_at&.present?
  end

  def find_user
    @user = User.find_by(password_token: params[:password_token].presence || "xyz")
    authorize @user, :password?
  end

  def password_params
    params.require(:user).permit(:password)
  end
end
