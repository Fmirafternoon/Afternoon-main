class UserMailerPreview < ActionMailer::Preview
  def password_creation
    user = User.agent.first || User.first
    UserMailer.password_creation(user)
  end
end
