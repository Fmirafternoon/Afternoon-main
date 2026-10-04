# frozen_string_literal: true

class PaginationComponent < ViewComponent::Base
  include Pagy::Frontend
  include ApplicationHelper

  def initialize(pagy:)
    @pagy = pagy
  end

  def render?
    @pagy.count.positive?
  end

  def pagy_url_for(page:)
    request.params.merge(page: page)
  end

  attr_reader :pagy
end
