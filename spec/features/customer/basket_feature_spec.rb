require "rails_helper"

RSpec.describe "Customer Basket Feature", type: :feature, skip: "Temporarily disabled - requires JS setup" do
  let(:customer) { create(:user, :customer) }
  let(:recruitment_office) { create(:recruitment_office, address: "123 Rue de la Paix", zip_code: "75001", city: "Paris") }
  let(:agent) { create(:user, :agent_user, email: "agent@test.com", first_name: "Marie", recruitment_office: recruitment_office) }
  let!(:candidate1) { create(:candidate, :published, agent: agent, position: "Développeur Ruby") }
  let!(:candidate2) { create(:candidate, :published, agent: agent, position: "Designer UX/UI") }

  before do
    sign_in customer
  end

  describe "Adding candidates from index" do
    it "adds candidate to basket and updates counter and button", js: true do
      visit customer_candidates_path

      # Vérifier que le compteur est à 0
      expect(page).to have_css("#basket-count")
      within("#basket-count") do
        expect(page).to have_content("0")
      end

      # Trouver la première card et cliquer sur le bouton d'ajout
      within("#candidate-card-#{candidate1.id}") do
        expect(page).to have_css("button[title='Ajouter au panier']")
        find("button[title='Ajouter au panier']").click
      end

      # Attendre la notification
      expect(page).to have_content("Candidat ajouté au panier")

      # Vérifier que le compteur est passé à 1
      within("#basket-count") do
        expect(page).to have_content("1")
      end

      # Vérifier que le bouton a changé en bouton de retrait
      within("#candidate-card-#{candidate1.id}") do
        expect(page).to have_css("button[title='Retirer du panier']")
        expect(page).not_to have_css("button[title='Ajouter au panier']")
      end
    end

    it "removes candidate from basket and updates counter and button", js: true do
      # Ajouter d'abord un candidat au panier
      basket = Basket.for_customer(customer)
      basket.add_candidate(candidate1)

      visit customer_candidates_path

      # Vérifier que le compteur est à 1
      within("#basket-count") do
        expect(page).to have_content("1")
      end

      # Vérifier que le bouton est en mode "retirer"
      within("#candidate-card-#{candidate1.id}") do
        expect(page).to have_css("button[title='Retirer du panier']")
        find("button[title='Retirer du panier']").click
      end

      # Attendre la notification
      expect(page).to have_content("Candidat retiré")

      # Vérifier que le compteur est revenu à 0
      within("#basket-count") do
        expect(page).to have_content("0")
      end

      # Vérifier que le bouton a changé en bouton d'ajout
      within("#candidate-card-#{candidate1.id}") do
        expect(page).to have_css("button[title='Ajouter au panier']")
        expect(page).not_to have_css("button[title='Retirer du panier']")
      end
    end

    it "adds multiple candidates and updates counter correctly", js: true do
      visit customer_candidates_path

      # Ajouter le premier candidat
      within("#candidate-card-#{candidate1.id}") do
        find("button[title='Ajouter au panier']").click
      end

      # Attendre que le compteur soit à 1
      within("#basket-count") do
        expect(page).to have_content("1")
      end

      # Ajouter le deuxième candidat
      within("#candidate-card-#{candidate2.id}") do
        find("button[title='Ajouter au panier']").click
      end

      # Vérifier que le compteur est passé à 2
      within("#basket-count") do
        expect(page).to have_content("2")
      end

      # Vérifier que les deux boutons sont en mode "retirer"
      within("#candidate-card-#{candidate1.id}") do
        expect(page).to have_css("button[title='Retirer du panier']")
      end

      within("#candidate-card-#{candidate2.id}") do
        expect(page).to have_css("button[title='Retirer du panier']")
      end
    end
  end

  describe "Adding candidates from show page" do
    it "adds candidate to basket and updates counter and button", js: true do
      visit customer_candidate_path(candidate1)

      # Vérifier que le compteur est à 0
      within("#basket-count") do
        expect(page).to have_content("0")
      end

      # Vérifier le bouton initial
      within("#candidate-basket-button") do
        expect(page).to have_button("Ajouter au panier")
        click_button "Ajouter au panier"
      end

      # Attendre la notification
      expect(page).to have_content("Candidat ajouté au panier")

      # Vérifier que le compteur est passé à 1
      within("#basket-count") do
        expect(page).to have_content("1")
      end

      # Vérifier que le bouton a changé
      within("#candidate-basket-button") do
        expect(page).to have_button("Enlever du panier")
        expect(page).not_to have_button("Ajouter au panier")
      end
    end

    it "removes candidate from basket and updates counter and button", js: true do
      # Ajouter d'abord un candidat au panier
      basket = Basket.for_customer(customer)
      basket.add_candidate(candidate1)

      visit customer_candidate_path(candidate1)

      # Vérifier que le compteur est à 1
      within("#basket-count") do
        expect(page).to have_content("1")
      end

      # Vérifier le bouton initial
      within("#candidate-basket-button") do
        expect(page).to have_button("Enlever du panier")
        click_button "Enlever du panier"
      end

      # Attendre la notification
      expect(page).to have_content("Candidat retiré")

      # Vérifier que le compteur est revenu à 0
      within("#basket-count") do
        expect(page).to have_content("0")
      end

      # Vérifier que le bouton a changé
      within("#candidate-basket-button") do
        expect(page).to have_button("Ajouter au panier")
        expect(page).not_to have_button("Enlever du panier")
      end
    end
  end

  describe "Navigation between index and show page" do
    it "maintains basket state when navigating between pages", js: true do
      visit customer_candidates_path

      # Ajouter un candidat depuis l'index
      within("#candidate-card-#{candidate1.id}") do
        find("button[title='Ajouter au panier']").click
      end

      # Attendre la mise à jour
      within("#basket-count") do
        expect(page).to have_content("1")
      end

      # Aller sur la page show du candidat
      visit customer_candidate_path(candidate1)

      # Vérifier que le compteur est toujours à 1
      within("#basket-count") do
        expect(page).to have_content("1")
      end

      # Vérifier que le bouton est en mode "enlever"
      within("#candidate-basket-button") do
        expect(page).to have_button("Enlever du panier")
      end

      # Retirer le candidat depuis la show page
      within("#candidate-basket-button") do
        click_button "Enlever du panier"
      end

      # Vérifier que le compteur est revenu à 0
      within("#basket-count") do
        expect(page).to have_content("0")
      end

      # Retourner sur l'index
      visit customer_candidates_path

      # Vérifier que le bouton est en mode "ajouter"
      within("#candidate-card-#{candidate1.id}") do
        expect(page).to have_css("button[title='Ajouter au panier']")
      end
    end
  end

  describe "Requesting a meeting", :js do
    before do
      # Ajouter des candidats au panier
      basket = Basket.for_customer(customer)
      basket.add_candidate(candidate1)
      basket.add_candidate(candidate2)
    end

    it "completes the full meeting request flow", js: true do
      # 1. Aller sur la page du panier
      visit customer_basket_path

      # Vérifier que les 2 candidats sont affichés
      expect(page).to have_content("Développeur Ruby")
      expect(page).to have_content("Designer UX/UI")

      # 2. Cliquer sur "Prendre RDV"
      click_button "Prendre RDV"

      # 3. Le modal doit s'ouvrir
      expect(page).to have_css("#modal", visible: true)
      expect(page).to have_content("Demande de rendez-vous")

      # 4. Remplir le formulaire
      meeting_date = 2.days.from_now
      fill_in "meeting_date", with: meeting_date.strftime("%Y-%m-%dT%H:%M")
      fill_in "customer_message", with: "Je souhaite discuter de ces deux profils intéressants."

      # 5. Soumettre le formulaire
      within("#modal") do
        click_button "Envoyer la demande"
      end

      # 6. Vérifier que le modal se ferme
      expect(page).not_to have_css("#modal", visible: true)

      # 7. Vérifier la notification de succès
      expect(page).to have_content("Demande de RDV envoyée")

      # 8. Vérifier que le bouton "Prendre RDV" devient "RDV demandé"
      expect(page).to have_button("RDV demandé", disabled: true)
      expect(page).not_to have_button("Prendre RDV")

      # 9. Vérifier que le compteur du panier a été mis à jour (devrait être 0 maintenant)
      within("#basket-count") do
        expect(page).to have_content("0")
      end

      # 10. Vérifier que le basket_item a bien été mis à jour en base
      basket_item = customer.baskets.first.basket_items.first
      expect(basket_item.status).to eq("meeting_requested")
      expect(basket_item.meeting_date).to be_present
      expect(basket_item.customer_message).to eq("Je souhaite discuter de ces deux profils intéressants.")

      # 11. Vérifier qu'un email a été envoyé
      expect(ActionMailer::Base.deliveries.count).to eq(1)
      email = ActionMailer::Base.deliveries.last
      expect(email.to).to include("agent@test.com")
      expect(email.subject).to include("Nouvelle demande de RDV")
      expect(email.subject).to include("2 candidat(s)")

      # 12. Vérifier que l'email contient le fichier ICS en pièce jointe
      expect(email.attachments.count).to eq(1)
      attachment = email.attachments.first
      expect(attachment.filename).to eq("invitation.ics")
      expect(attachment.content_type).to start_with("text/calendar")

      # 13. Vérifier le contenu de l'email
      html_body = email.html_part.body.to_s
      expect(html_body).to include("Marie") # Prénom de l'agent
      expect(html_body).to include("Développeur Ruby")
      expect(html_body).to include("Designer UX/UI")
      expect(html_body).to include("Je souhaite discuter de ces deux profils intéressants.")
      expect(html_body).to include("Google Calendar")
      expect(html_body).to include("Outlook")
      expect(html_body).to include("Télécharger .ics")

      # 14. Vérifier le contenu du fichier ICS
      ics_content = attachment.body.to_s
      expect(ics_content).to include("BEGIN:VCALENDAR")
      expect(ics_content).to include("BEGIN:VEVENT")
      expect(ics_content).to include("SUMMARY:RDV - 2 candidats")
      expect(ics_content).to include("LOCATION:123 Rue de la Paix, 75001 Paris")
      expect(ics_content).to match(/ORGANIZER.*:mailto:#{customer.email}/)
      expect(ics_content).to match(/ATTENDEE.*:mailto:agent@test\.com/)
    end

    it "shows validation errors when form is incomplete", js: true do
      visit customer_basket_path

      # Cliquer sur "Prendre RDV"
      click_button "Prendre RDV"

      # Soumettre sans remplir le formulaire
      within("#modal") do
        click_button "Envoyer la demande"
      end

      # Le modal doit rester ouvert avec des erreurs
      expect(page).to have_css("#modal", visible: true)
      expect(page).to have_content("erreur", wait: 5) # Message d'erreur générique
    end
  end
end
