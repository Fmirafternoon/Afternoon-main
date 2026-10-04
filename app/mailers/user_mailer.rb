class UserMailer < ApplicationMailer
  def password_creation(user)
    @user = user
    @password_creation_url = new_users_password_creation_url(password_token: @user.password_token)
    mail(to: @user.email, subject: "[Afternoon] Votre compte a été créé")
  end
end
