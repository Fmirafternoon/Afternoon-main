# frozen_string_literal: true

class HeaderComponent < ViewComponent::Base
  renders_one :actions, GenericComponent
  renders_one :body, GenericComponent
  renders_one :header, GenericComponent
  renders_one :prefix, GenericComponent
  renders_one :suffix, GenericComponent
  renders_one :tabs, GenericComponent

  def initialize(title:)
    @title = title
  end
end
