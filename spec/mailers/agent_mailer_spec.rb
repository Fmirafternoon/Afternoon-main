require 'rails_helper'

RSpec.describe AgentMailer, type: :mailer do
  describe '#meeting_request' do
    let(:customer) { create(:user, :customer, email: 'customer@example.com', first_name: 'Jean', last_name: 'Dupont') }
    let(:recruitment_office) { create(:recruitment_office, address: '123 Rue de la Paix', zip_code: '75001', city: 'Paris') }
    let(:agent) { create(:user, :agent_user, email: 'agent@example.com', first_name: 'Marie', recruitment_office: recruitment_office) }
    let(:basket) { create(:basket, customer: customer) }
    let(:basket_item) { create(:basket_item, :meeting_requested, basket: basket, agent: agent) }
    let(:candidate1) { create(:candidate, first_name: 'Alice', last_name: 'Martin') }
    let(:candidate2) { create(:candidate, first_name: 'Bob', last_name: 'Bernard') }

    before do
      basket_item.basket_item_candidates.create!(candidate: candidate1, added_at: Time.current)
      basket_item.basket_item_candidates.create!(candidate: candidate2, added_at: Time.current)
    end

    let(:mail) { described_class.meeting_request(basket_item: basket_item) }

    describe 'email headers' do
      it 'sends to the agent email' do
        expect(mail.to).to eq([agent.email])
      end

      it 'has the correct subject with candidate count' do
        expect(mail.subject).to eq('[Afternoon] Nouvelle demande de RDV - 2 candidat(s)')
      end

      it 'sends from the default email' do
        expect(mail.from).to eq([ApplicationMailer.default[:from]])
      end
    end

    describe 'email attachments' do
      it 'attaches an ICS file and logo' do
        expect(mail.attachments.count).to eq(2)
      end

      it 'has the correct attachment name' do
        attachment = mail.attachments['invitation.ics']
        expect(attachment.filename).to eq('invitation.ics')
      end

      it 'has the correct MIME type' do
        attachment = mail.attachments['invitation.ics']
        expect(attachment.content_type).to start_with('text/calendar')
      end

      it 'contains valid ICS content' do
        attachment = mail.attachments['invitation.ics']
        ics_content = attachment.body.to_s

        expect(ics_content).to include('BEGIN:VCALENDAR')
        expect(ics_content).to include('BEGIN:VEVENT')
        expect(ics_content).to include('END:VEVENT')
        expect(ics_content).to include('END:VCALENDAR')
      end

      it 'includes event details in ICS' do
        attachment = mail.attachments['invitation.ics']
        ics_content = attachment.body.to_s

        expect(ics_content).to include('SUMMARY:RDV - 2 candidats')
        expect(ics_content).to include('LOCATION:123 Rue de la Paix')
        expect(ics_content).to match(/ORGANIZER.*:mailto:customer@example\.com/)
        expect(ics_content).to match(/ATTENDEE.*:mailto:agent@example\.com/)
      end

      it 'includes candidates in ICS description' do
        attachment = mail.attachments['invitation.ics']
        ics_content = attachment.body.to_s

        expect(ics_content).to include('Alice Martin')
        expect(ics_content).to include('Bob Bernard')
      end
    end

    describe 'email body' do
      let(:html_body) { mail.html_part.body.to_s }

      it 'includes agent first name' do
        expect(html_body).to include('Bonjour Marie')
      end

      it 'includes customer name and email' do
        expect(html_body).to include('Jean Dupont')
        expect(html_body).to include('customer@example.com')
      end

      it 'includes meeting date with time' do
        formatted_date = I18n.l(basket_item.meeting_date, format: :long_with_time)
        expect(html_body).to include(formatted_date)
      end

      it 'includes candidate count' do
        expect(html_body).to include('2')
      end

      it 'includes candidate names' do
        expect(html_body).to include('Alice Martin')
        expect(html_body).to include('Bob Bernard')
      end

      it 'includes customer message' do
        expect(html_body).to include(basket_item.customer_message)
      end

      it 'includes calendar links section' do
        expect(html_body).to include('Ajouter à mon calendrier')
      end

      it 'includes Google Calendar link' do
        expect(html_body).to include('Google Calendar')
        expect(html_body).to include('calendar.google.com')
      end

      it 'includes Outlook link' do
        expect(html_body).to include('Outlook')
        expect(html_body).to include('outlook.live.com')
      end

      it 'includes download .ics link' do
        expect(html_body).to include('Télécharger .ics')
        expect(html_body).to include('basket/calendar')
      end

      it 'includes information about ICS attachment' do
        expect(html_body).to include('fichier .ics est également joint')
      end

      it 'includes footer' do
        expect(html_body).to include('Cet email a été envoyé automatiquement par Afternoon')
      end
    end

    describe 'calendar URLs' do
      let(:html_body) { mail.html_part.body.to_s }

      it 'Google Calendar URL includes event title' do
        expect(html_body).to match(/calendar\.google\.com.*text=RDV/)
      end

      it 'Outlook URL includes event subject' do
        expect(html_body).to match(/outlook\.live\.com.*subject=RDV/)
      end

      it 'download link points to correct basket_item' do
        expect(html_body).to include("basket/calendar/#{basket_item.id}")
      end
    end

    context 'with single candidate' do
      let(:agent2) { create(:user, :agent_user, email: 'agent2@example.com', first_name: 'Pierre', recruitment_office: recruitment_office) }
      let(:basket_item_single) { create(:basket_item, :meeting_requested, basket: basket, agent: agent2) }

      before do
        basket_item_single.basket_item_candidates.create!(candidate: candidate1, added_at: Time.current)
      end

      let(:mail) { described_class.meeting_request(basket_item: basket_item_single) }

      it 'has correct subject with singular form' do
        expect(mail.subject).to eq('[Afternoon] Nouvelle demande de RDV - 1 candidat(s)')
      end

      it 'includes candidate count as 1' do
        html_body = mail.html_part.body.to_s
        expect(html_body).to include('1')
      end
    end

    context 'without customer message' do
      before do
        basket_item.update!(customer_message: nil)
      end

      it 'does not show message section' do
        html_body = mail.html_part.body.to_s
        expect(html_body).not_to include('Message :')
      end
    end


    describe 'proper styling' do
      let(:html_body) { mail.html_part.body.to_s }

      it 'includes inline CSS styles' do
        expect(html_body).to include('font-family')
        expect(html_body).to include('background-color')
        expect(html_body).to include('border-radius')
      end

      it 'has container with correct width' do
        expect(html_body).to include('width="600"')
      end

      it 'styles calendar buttons' do
        expect(html_body).to include('padding: 10px 20px')
        expect(html_body).to include('text-decoration: none')
      end
    end
  end

  describe '#project_broadcast' do
    let(:customer) { create(:user, :customer, email: 'client@example.com') }
    let(:agent) { create(:user, :agent_user, email: 'agent@example.com', first_name: 'Marie') }
    let(:location) { create(:location, city: 'Paris') }
    let(:skill) { create(:skill, name: 'Cuisine') }
    let(:project) do
      create(:project,
             customer: customer,
             location: location,
             position_name: 'Chef de cuisine',
             contract_type: 'cdi',
             min_experience_years: 3,
             target_salary: 45_000)
    end

    before { project.skills << skill }

    let(:mail) { described_class.project_broadcast(agent.id, project.id) }

    it 'sends to the agent email' do
      expect(mail.to).to eq([agent.email])
    end

    it 'sets reply_to to the customer email' do
      expect(mail.reply_to).to eq([customer.email])
    end

    it 'has the position name in the subject' do
      expect(mail.subject).to eq('[Afternoon] Nouveau projet à pourvoir - Chef de cuisine')
    end

    describe 'email content' do
      let(:html_body) { mail.html_part.body.to_s }

      it 'greets the agent by first name' do
        expect(html_body).to include('Bonjour Marie')
      end

      it 'presents the client' do
        expect(html_body).to include(project.client_name)
      end

      it 'presents the project details' do
        expect(html_body).to include('Chef de cuisine')
        expect(html_body).to include('Paris')
        expect(html_body).to include('CDI')
        expect(html_body).to include('Cuisine')
        expect(html_body).to include('3+ ans')
      end

      it 'presents Afternoon' do
        expect(html_body).to include("C'est quoi Afternoon ?")
      end
    end
  end
end
