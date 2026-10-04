# frozen_string_literal: true

class Candidate::PublicationStatusComponent < TagComponent
  def initialize(candidate)
    @candidate = candidate
    @kind = @candidate.published? ? "success" : "warning"
  end

  def content
    case @candidate.publication_status
    when "draft"
      "Brouillon"
    when "pending"
      "Demande de publication"
    when "published"
      "Publié"
    end
  end
end
