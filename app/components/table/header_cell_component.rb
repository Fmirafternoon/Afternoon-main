# frozen_string_literal: true

class Table::HeaderCellComponent < ViewComponent::Base
  def initialize(classes: "")
    @classes = classes
  end

  attr_reader :classes
end
