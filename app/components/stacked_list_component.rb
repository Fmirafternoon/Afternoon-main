# frozen_string_literal: true

class StackedListComponent < ViewComponent::Base
  renders_many :items, GenericComponent

  def initialize(wrapper_classes: nil)
    @wrapper_classes = wrapper_classes
  end

  attr_reader :wrapper_classes

  def render?
    items.any?
  end
end
