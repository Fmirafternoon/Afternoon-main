class Candidate::CardComponent < ViewComponent::Base
  with_collection_parameter :candidate

  def initialize(candidate:, readonly: false, basket: nil)
    @candidate = candidate
    @readonly = readonly
    @basket = basket
  end

  attr_reader :candidate, :basket

  def readonly?
    @readonly ||= false
  end

  def in_basket?
    basket&.has_candidate?(candidate)
  end

  def basket_item_for_candidate
    basket&.basket_item_for_candidate(candidate)
  end

  def meeting_requested?
    basket_item = basket_item_for_candidate
    basket_item&.status_meeting_requested? || basket_item&.status_meeting_scheduled?
  end
  # enum :availability_notice, {
  #   immediate: "immediate",
  #   two_to_three_weeks: "2_to_3_weeks",
  #   four_to_six_weeks: "4_to_6_weeks",
  #   two_months: "2_months",
  #   three_months: "3_months",
  #   four_months_plus: "4_months_plus"
  # }, default: :immediate

  def card_class
    case candidate.availability_notice
    when "immediate"
      "bg-success-100 border-success-200"
    when "2_to_3_weeks"
      "bg-success-100 border-success-200"
    when "4_to_6_weeks"
      "bg-success-100 border-success-200"
    else
      "bg-mute-200 border-mute-300"
    end
  end
end
