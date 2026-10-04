# frozen_string_literal: true

class Table::RowComponent < ViewComponent::Base
  renders_many :cells, Table::RowCellComponent
  def initialize(id: '')
    @id = id
  end

  attr_reader :id
end
