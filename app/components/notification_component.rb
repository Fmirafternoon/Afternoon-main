# frozen_string_literal: true

class NotificationComponent < ViewComponent::Base
  attr_reader :message

  def initialize(message:)
    @message = message
  end

  def color
    "text-red-400"
  end

  def icon
    "icons/x.svg"
  end

  def render?
    message.present?
  end
end
