# frozen_string_literal: true

class TableComponent < ViewComponent::Base
  renders_one :header, Table::HeaderComponent
  renders_one :empty_state, Table::EmptyStateComponent
  renders_one :empty_search, Table::EmptySearchComponent
  renders_many :rows, Table::RowComponent

  def initialize(loop_on: nil)
    @loop_on = loop_on
  end

  attr_reader :loop_on
end
