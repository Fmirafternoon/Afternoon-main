# frozen_string_literal: true

class LogoComponent < ViewComponent::Base
  def initialize(size: :normal)
    @size = size
  end

  private

  def logo_size_class
    case @size
    when :xs
      "h-6"
    when :sm
      "h-8"
    when :xl
      "h-12"
    else
      "h-10"
    end
  end
end
