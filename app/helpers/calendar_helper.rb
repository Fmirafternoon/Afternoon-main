module CalendarHelper
  MEETING_DURATION = 60 # minutes

  def google_calendar_url(basket_item)
    params = {
      action: 'TEMPLATE',
      text: meeting_title(basket_item),
      dates: google_calendar_dates(basket_item),
      details: meeting_description(basket_item)
    }

    # Ajouter la location si elle existe
    location = meeting_location(basket_item)
    params[:location] = location if location.present?

    "https://calendar.google.com/calendar/render?#{params.to_query}"
  end

  def outlook_calendar_url(basket_item)
    params = {
      path: '/calendar/action/compose',
      rru: 'addevent',
      subject: meeting_title(basket_item),
      startdt: outlook_datetime(basket_item.meeting_date),
      enddt: outlook_datetime(basket_item.meeting_date + MEETING_DURATION.minutes),
      body: meeting_description(basket_item)
    }

    # Ajouter la location si elle existe
    location = meeting_location(basket_item)
    params[:location] = location if location.present?

    "https://outlook.live.com/calendar/0/deeplink/compose?#{params.to_query}"
  end

  private

  def meeting_title(basket_item)
    count = basket_item.candidates.count
    "RDV - #{count} candidat#{'s' if count > 1}"
  end

  def meeting_description(basket_item)
    parts = []
    parts << "Candidats :"
    basket_item.candidates.each do |candidate|
      parts << "- #{candidate.first_name} #{candidate.last_name}"
    end

    if basket_item.customer_message.present?
      parts << ""
      parts << "Message :"
      parts << basket_item.customer_message
    end

    parts.join("\n")
  end

  def meeting_location(basket_item)
    return nil unless basket_item.agent.recruitment_office.present?

    office = basket_item.agent.recruitment_office
    location_parts = []
    location_parts << office.address if office.address.present?
    location_parts << "#{office.zip_code} #{office.city}" if office.zip_code.present? && office.city.present?

    location_parts.any? ? location_parts.join(", ") : nil
  end

  def google_calendar_dates(basket_item)
    start_time = basket_item.meeting_date
    end_time = start_time + MEETING_DURATION.minutes

    # Format Google Calendar: YYYYMMDDTHHmmss
    "#{start_time.strftime('%Y%m%dT%H%M%S')}/#{end_time.strftime('%Y%m%dT%H%M%S')}"
  end

  def outlook_datetime(datetime)
    # Format Outlook: ISO8601
    datetime.strftime('%Y-%m-%dT%H:%M:%S')
  end
end
