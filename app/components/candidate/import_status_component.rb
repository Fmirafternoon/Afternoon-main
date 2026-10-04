# frozen_string_literal: true

class Candidate::ImportStatusComponent <  ViewComponent::Base
  def initialize(candidate)
    @candidate = candidate
  end

  def render?
    @candidate.import_status.present?
  end

  def label
    case @candidate.import_status
    when "uploading"
      "Téléchargement en cours..."
    when "pending"
      "Import en cours..."
    when "completed"
      "Import terminé"
    when "failed"
      "Import échoué"
    end
  end
end
