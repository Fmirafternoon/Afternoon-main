class Details::ItemComponent < ViewComponent::Base
  renders_one :action, GenericComponent

  def initialize(id: "", label: "", value: nil, classes: "", wrapper_classes: "")
    @id = id
    @label = label
    @value = value
    @classes = classes
    @wrapper_classes = wrapper_classes
  end

  attr_reader :id, :label, :value, :classes, :wrapper_classes
end
