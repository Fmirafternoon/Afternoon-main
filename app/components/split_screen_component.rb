# frozen_string_literal: true

class SplitScreenComponent < ViewComponent::Base
  def initialize(image:)
    @image = image
  end

  attr_reader :image
end
