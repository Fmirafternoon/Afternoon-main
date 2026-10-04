# frozen_string_literal: true

class Card::TitleComponent < ViewComponent::Base
  renders_one :actions, 'GenericComponent'

  def initialize(title:, hint: nil)
    @title = title
    @hint = hint
  end

  attr_reader :title, :hint
end
