# frozen_string_literal: true

class Table::HeaderComponent < ViewComponent::Base
  renders_many :cells, Table::HeaderCellComponent
end
