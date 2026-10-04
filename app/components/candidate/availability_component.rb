class Candidate::AvailabilityComponent < TagComponent
  def initialize(candidate:)
    @candidate = candidate

    @kind = :success
  end

  attr_reader :candidate

  def render?
    candidate.availability_notice.present?
  end

  def content
    case candidate.availability_notice
    when "immediate"
      "⚡️ Immédiat"
    when "two_to_three_weeks"
      "🕑 2 à 3 semaines"
    when "four_to_six_weeks"
      "🕑 4 à 6 semaines"
    when "two_months"
      "🗓️ 2 mois"
    when "three_months"
      "🗓️ 3 mois"
    when "four_months_plus"
      "🗓️4 mois et plus"
    else
      candidate.availability_notice
    end
  end

  def classes
    "border border-mute-400 bg-mute-300 text-black"
  end
end
