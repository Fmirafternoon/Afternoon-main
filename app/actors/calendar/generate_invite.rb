class Calendar::GenerateInvite < Actor
  MEETING_DURATION = 60 # minutes

  input :basket_item, type: BasketItem

  output :ics_content, type: String

  def call
    require 'icalendar'

    cal = Icalendar::Calendar.new

    # Configuration du calendrier
    cal.prodid = "-//Afternoon//Meeting Invitation//FR"
    cal.version = "2.0"

    # Création de l'événement
    event = Icalendar::Event.new
    event.dtstart = Icalendar::Values::DateTime.new(basket_item.meeting_date)
    event.dtend = Icalendar::Values::DateTime.new(basket_item.meeting_date + MEETING_DURATION.minutes)

    # Titre
    candidates_count = basket_item.candidates.count
    event.summary = "RDV - #{candidates_count} candidat#{'s' if candidates_count > 1}"

    # Description avec liste des candidats et message
    description_parts = []
    description_parts << "Candidats :"
    basket_item.candidates.each do |candidate|
      description_parts << "- #{candidate.first_name} #{candidate.last_name}"
    end

    if basket_item.customer_message.present?
      description_parts << ""
      description_parts << "Message :"
      description_parts << basket_item.customer_message
    end

    event.description = description_parts.join("\n")

    # Lieu (adresse du cabinet)
    if basket_item.agent.recruitment_office.present?
      office = basket_item.agent.recruitment_office
      location_parts = []
      location_parts << office.address if office.address.present?
      location_parts << "#{office.zip_code} #{office.city}" if office.zip_code.present? && office.city.present?
      event.location = location_parts.join(", ") if location_parts.any?
    end

    # Organisateur (le client qui demande le RDV)
    event.organizer = "mailto:#{basket_item.basket.customer.email}"
    event.organizer = Icalendar::Values::CalAddress.new("mailto:#{basket_item.basket.customer.email}", cn: basket_item.basket.customer.full_name)

    # Participant (l'agent)
    attendee = Icalendar::Values::CalAddress.new(
      "mailto:#{basket_item.agent.email}",
      cn: basket_item.agent.full_name,
      role: "REQ-PARTICIPANT"
    )
    event.append_attendee(attendee)

    # URL vers le panier
    event.url = Rails.application.routes.url_helpers.customer_basket_url(host: ENV.fetch("HOST", "localhost:3000"))

    # Génération d'un UID unique
    event.uid = "basket-item-#{basket_item.id}@afternoon.fr"
    event.created = Time.current
    event.last_modified = Time.current
    event.sequence = 0
    event.status = "CONFIRMED"

    cal.add_event(event)

    self.ics_content = cal.to_ical
  end
end
