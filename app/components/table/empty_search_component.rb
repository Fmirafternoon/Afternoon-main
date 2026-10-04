# frozen_string_literal: true

class Table::EmptySearchComponent < ViewComponent::Base
  def search
    params.dig(:search, :query).present?
  end

  def query
    params[:search][:query]
  end
end
