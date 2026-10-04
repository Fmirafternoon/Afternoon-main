class SearchComponent < ViewComponent::Base
  def initialize(path:, placeholder: 'Recherche')
    @path = path
    @placeholder = placeholder
  end

  def query
    params.dig(:search, :query)
  end

  attr_reader :path, :placeholder
end
