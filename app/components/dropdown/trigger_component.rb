class Dropdown::TriggerComponent < ViewComponent::Base
  def initialize(classes: '', wrapper_classes: '')
    @classes = classes
    @wrapper_classes = wrapper_classes
  end

  attr_reader :classes, :wrapper_classes
end
