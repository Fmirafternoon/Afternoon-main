# frozen_string_literal: true

class TagComponent < ViewComponent::Base
  def initialize(kind: nil)
    @kind = kind
  end

  attr_reader :kind

  def classes
    case kind.to_s
    when "success"
      "text-black bg-success-200"
    when "neutral"
      "text-black bg-white"
    when "warning"
      "text-black bg-primary-500"
    when "info"
      "text-black bg-sky-200"
    when "danger"
      "text-black bg-peach"
    when "primary"
      "text-black bg-primary-500"
    when "black"
      "text-white bg-black"
    else
      "text-black bg-gray-200"
    end
  end
end
