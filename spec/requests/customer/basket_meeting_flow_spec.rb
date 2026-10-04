require 'rails_helper'

RSpec.describe "Customer Basket Meeting Request Flow", type: :request do
  let(:customer) { create(:user, :customer) }
  let(:recruitment_office) { create(:recruitment_office, address: "123 Rue de la Paix", zip_code: "75001", city: "Paris") }
  let(:agent) { create(:user, :agent_user, email: "agent@test.com", first_name: "Marie", recruitment_office: recruitment_office) }
  let!(:candidate1) { create(:candidate, :published, agent: agent, first_name: "Alice", last_name: "Martin", position: "Développeur Ruby") }
  let!(:candidate2) { create(:candidate, :published, agent: agent, first_name: "Bob", last_name: "Durand", position: "Designer UX/UI") }
  let(:basket) { Basket.for_customer(customer) }

  before do
    sign_in customer
    # Ajouter des candidats au panier
    basket.add_candidate(candidate1)
    basket.add_candidate(candidate2)
    # S'assurer qu'ActionMailer est en mode test
    ActionMailer::Base.deliveries.clear
  end

  describe "Complete meeting request flow" do
    it "successfully requests a meeting and sends email with ICS attachment" do
      basket_item = basket.basket_items.first

      # 1. Vérifier que le basket_item est en pending
      expect(basket_item.status).to eq("pending")
      expect(basket.pending_candidates_count).to eq(2)

      # 2. Envoyer la demande de RDV
      meeting_date = 2.days.from_now

      post customer_basket_send_meeting_request_path(basket_item),
           params: {
             meeting_date: meeting_date.strftime("%Y-%m-%dT%H:%M"),
             customer_message: "Je souhaite discuter de ces deux profils intéressants."
           },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      # 3. Vérifier la réponse
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("turbo-stream")

      # 4. Vérifier que le basket_item a été mis à jour
      basket_item.reload
      expect(basket_item.status).to eq("meeting_requested")
      expect(basket_item.meeting_date).to be_present
      expect(basket_item.customer_message).to eq("Je souhaite discuter de ces deux profils intéressants.")

      # 5. Vérifier que le compteur du panier a été mis à jour
      basket.reload
      expect(basket.pending_candidates_count).to eq(0)

      # 6. Tester l'email directement (car deliver_later enqueue en arrière-plan)
      # On génère l'email pour tester son contenu
      email = AgentMailer.meeting_request(basket_item: basket_item)

      # 7. Vérifier les headers de l'email
      expect(email.to).to include("agent@test.com")
      expect(email.subject).to eq("[Afternoon] Nouvelle demande de RDV - 2 candidat(s)")

      # 8. Vérifier que l'email contient le fichier ICS en pièce jointe (+ logo)
      expect(email.attachments.count).to eq(2)
      attachment = email.attachments['invitation.ics']
      expect(attachment.filename).to eq("invitation.ics")
      expect(attachment.content_type).to start_with("text/calendar")

      # 9. Vérifier le contenu de l'email HTML
      html_body = email.html_part.body.to_s
      expect(html_body).to include("Bonjour Marie")
      expect(html_body).to include(customer.first_name)
      expect(html_body).to include(customer.last_name)
      expect(html_body).to include(customer.email)
      expect(html_body).to include("Alice Martin")
      expect(html_body).to include("Bob Durand")
      expect(html_body).to include("Je souhaite discuter de ces deux profils intéressants.")

      # 10. Vérifier les liens calendrier dans l'email
      expect(html_body).to include("Ajouter à mon calendrier")
      expect(html_body).to include("Google Calendar")
      expect(html_body).to include("calendar.google.com")
      expect(html_body).to include("Outlook")
      expect(html_body).to include("outlook.live.com")
      expect(html_body).to include("Télécharger .ics")
      expect(html_body).to include("basket/calendar/#{basket_item.id}")

      # 11. Vérifier le contenu du fichier ICS
      ics_content = attachment.body.to_s

      # Vérifier la structure du fichier ICS
      expect(ics_content).to include("BEGIN:VCALENDAR")
      expect(ics_content).to include("VERSION:2.0")
      expect(ics_content).to include("BEGIN:VEVENT")
      expect(ics_content).to include("END:VEVENT")
      expect(ics_content).to include("END:VCALENDAR")

      # Vérifier les détails de l'événement
      expect(ics_content).to include("SUMMARY:RDV - 2 candidats")
      # Dans ICS, les virgules sont échappées avec un backslash
      expect(ics_content).to match(/LOCATION:123 Rue de la Paix.*75001 Paris/)
      expect(ics_content).to match(/ORGANIZER.*:mailto:#{Regexp.escape(customer.email)}/)
      expect(ics_content).to match(/ATTENDEE.*:mailto:agent@test\.com/)

      # Vérifier la description avec les candidats
      expect(ics_content).to include("Alice Martin")
      expect(ics_content).to include("Bob Durand")
      # Le format ICS peut couper les lignes longues
      expect(ics_content).to match(/DESCRIPTION:.*Candidats.*Alice Martin.*Bob Durand/m)

      # 12. Vérifier que les turbo_streams sont corrects
      expect(response.body).to include("turbo-stream")
      expect(response.body).to include('action="update"')
      expect(response.body).to include('target="modal"')
      expect(response.body).to include('action="replace"')
      expect(response.body).to include("basket_item_#{basket_item.id}")
      expect(response.body).to include('target="basket-count"')
      expect(response.body).to include("Demande de RDV envoyée")
    end

    it "accepts empty message but meeting_date is required" do
      basket_item = basket.basket_items.first

      # Envoyer la demande sans customer_message (optionnel)
      meeting_date = 2.days.from_now
      post customer_basket_send_meeting_request_path(basket_item),
           params: {
             meeting_date: meeting_date.strftime("%Y-%m-%dT%H:%M"),
             customer_message: ""
           },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      # Le basket_item devrait être mis à jour même sans message
      basket_item.reload
      expect(basket_item.status).to eq("meeting_requested")
      expect(basket_item.meeting_date).to be_present
      expect(basket_item.customer_message).to be_blank

      # Vérifier que l'email peut être généré sans message
      email = AgentMailer.meeting_request(basket_item: basket_item)
      expect(email.to).to include("agent@test.com")
    end

    it "allows downloading the ICS file directly" do
      basket_item = basket.basket_items.first
      basket_item.update!(
        status: :meeting_requested,
        meeting_date: 2.days.from_now,
        customer_message: "Test message"
      )

      # Télécharger le fichier ICS
      get customer_basket_calendar_path(basket_item)

      # Vérifier la réponse
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("text/calendar")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.headers["Content-Disposition"]).to include("rdv-afternoon-#{basket_item.id}.ics")

      # Vérifier le contenu
      expect(response.body).to include("BEGIN:VCALENDAR")
      expect(response.body).to include("SUMMARY:RDV - 2 candidats")
    end
  end
end
