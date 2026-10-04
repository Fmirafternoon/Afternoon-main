class CardComponent < ViewComponent::Base
  renders_many :bodies, GenericComponent
  renders_one :header, GenericComponent
  renders_one :actions, Card::ActionsComponent
  renders_one :cancel, Card::CancelComponent
  renders_many :items, Details::ItemComponent

  def initialize(title: nil, classes: '', body_classes: '', no_padding: false)
    @title = title
    @classes = classes
    @body_classes = body_classes
    @no_padding = no_padding
  end
  attr_reader :title, :classes, :body_classes, :no_padding
end
