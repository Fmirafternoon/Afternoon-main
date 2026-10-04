# frozen_string_literal: true

class Table::EmptyStateComponent < ViewComponent::Base
  def initialize(name:, icon:, new_path:)
    @name = name
    @icon = icon
    @new_path = new_path
  end

  attr_reader :name, :icon, :new_path
end
