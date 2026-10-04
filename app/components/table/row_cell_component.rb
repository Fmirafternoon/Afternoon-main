# frozen_string_literal: true

class Table::RowCellComponent < ViewComponent::Base
  def initialize(classes: '', wrap: false)
    @classes = classes
    @wrap = wrap
  end

  attr_reader :classes, :wrap

  def classes
    @classes + ' ' + default_classes
  end

  def default_classes
    if wrap
      'min-w-[100px]'
    else
      'whitespace-nowrap'
    end
  end
end
