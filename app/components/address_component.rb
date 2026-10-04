# frozen_string_literal: true

class AddressComponent < ViewComponent::Base
  def initialize(instance:)
    @instance = instance
  end

  attr_reader :instance
end
