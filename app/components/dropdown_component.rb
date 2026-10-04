# frozen_string_literal: true

class DropdownComponent < ViewComponent::Base
  renders_many :separators, 'Dropdown::SeparatorComponent'
  renders_one :trigger, 'Dropdown::TriggerComponent'
  renders_one :body, 'GenericComponent'
  
  def initialize(position: :right)
    @position = position
  end
  
  def position_classes
    case @position
    when :left
      "left-0 origin-top-left"
    when :right
      "right-0 origin-top-right"
    else
      "right-0 origin-top-right"
    end
  end
end
