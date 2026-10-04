class ApplicationMailer < ActionMailer::Base
  default from: ENV["EMAIL_SENDER"]
  layout "mailer"

  before_action :attach_logo

  private

  def attach_logo
    attachments.inline["logo.png"] = {
      data: File.read(Rails.root.join("app/assets/images/afternoon-logo.png")),
      mime_type: "image/png"
    }
  end
end
