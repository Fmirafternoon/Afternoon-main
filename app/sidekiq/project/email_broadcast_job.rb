class Project::EmailBroadcastJob
  include Sidekiq::Job

  BROADCAST_RADIUS_KM = 50

  def perform(project_id)
    project = Project.find(project_id)
    return unless project.broadcastable?

    coordinates = coordinates_for(project.location)
    return if coordinates.blank?

    agent_ids = nearby_agent_ids(coordinates)
    return if agent_ids.empty?

    # Rempli avant l'envoi pour éviter un double envoi si Sidekiq retente le job à mi-parcours
    project.update_column(:last_email_broadcasted_at, Time.current)

    agent_ids.each do |agent_id|
      AgentMailer.project_broadcast(agent_id, project.id).deliver_later
    end
  end

  private

  def coordinates_for(location)
    return nil if location.nil?

    if location.latitude.present? && location.longitude.present?
      return [location.latitude, location.longitude]
    end

    # Les locations de projet créées par le wizard (ville seule) n'ont pas de coordonnées
    geocoded = Location::Geocode.result(address: location.full_address).location
    return nil if geocoded.nil?

    [geocoded.latitude, geocoded.longitude]
  end

  def nearby_agent_ids(coordinates)
    offices = RecruitmentOffice.kept.near_location(
      coordinates[0], coordinates[1], BROADCAST_RADIUS_KM
    )
    User.where(recruitment_office_id: offices.select(:id)).pluck(:id)
  end
end
