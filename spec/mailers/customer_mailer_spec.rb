require 'rails_helper'

RSpec.describe CustomerMailer, type: :mailer do
  describe '#meeting_request_confirmation' do
    let(:customer) { create(:user, :customer, email: 'customer@example.com', first_name: 'Jean', last_name: 'Dupont') }
    let(:recruitment_office) { create(:recruitment_office, name: 'Cabinet ABC', address: '123 Rue de la Paix', zip_code: '75001', city: 'Paris') }
    let(:agent) { create(:user, :agent_user, email: 'agent@example.com', first_name: 'Marie', last_name: 'Martin', recruitment_office: recruitment_office) }
    let(:basket) { create(:basket, customer: customer) }
    let(:basket_item) { create(:basket_item, :meeting_requested, basket: basket, agent: agent) }
    let(:candidate1) { create(:candidate, first_name: 'Alice', last_name: 'Durand', position: 'Développeur Ruby') }
    let(:candidate2) { create(:candidate, first_name: 'Bob', last_name: 'Bernard', position: 'Designer UX') }

    before do
      basket_item.basket_item_candidates.create!(candidate: candidate1, added_at: Time.current)
      basket_item.basket_item_candidates.create!(candidate: candidate2, added_at: Time.current)
    end

    let(:mail) { described_class.meeting_request_confirmation(basket_item: basket_item) }

    describe 'email headers' do
      it 'sends to the customer email' do
        expect(mail.to).to eq([customer.email])
      end

      it 'has the correct subject' do
        expect(mail.subject).to eq('[Afternoon] Votre demande de rendez-vous a été envoyée')
      end

      it 'has reply_to set to agent email' do
        expect(mail.reply_to).to eq([agent.email])
      end

      it 'sends from the default email' do
        expect(mail.from).to eq([ApplicationMailer.default[:from]])
      end
    end

    describe 'email body' do
      let(:html_body) { mail.html_part.body.to_s }

      it 'includes customer first name' do
        expect(html_body).to include('Bonjour Jean')
      end

      it 'includes confirmation message' do
        expect(html_body).to include('Demande de rendez-vous envoyée')
      end

      it 'includes agent full name' do
        expect(html_body).to include('Marie Martin')
      end

      it 'includes agent email as clickable link' do
        expect(html_body).to include('agent@example.com')
        expect(html_body).to include('mailto:agent@example.com')
      end

      it 'includes recruitment office name' do
        expect(html_body).to include('Cabinet ABC')
      end

      it 'includes meeting date with time' do
        formatted_date = I18n.l(basket_item.meeting_date, format: :long_with_time)
        expect(html_body).to include(formatted_date)
      end

      it 'includes candidate count' do
        expect(html_body).to include('2')
      end

      it 'includes candidate names and positions' do
        expect(html_body).to include('Alice Durand')
        expect(html_body).to include('Développeur Ruby')
        expect(html_body).to include('Bob Bernard')
        expect(html_body).to include('Designer UX')
      end

      it 'includes customer message if present' do
        expect(html_body).to include(basket_item.customer_message)
      end

      it 'includes next steps section' do
        expect(html_body).to include('Prochaines étapes')
        expect(html_body).to include('va recevoir votre demande')
      end

      it 'includes direct reply instruction' do
        expect(html_body).to include('Vous pouvez répondre directement à cet email')
      end

      it 'includes reminder about checking spam' do
        expect(html_body).to include('Surveillez votre boîte email')
        expect(html_body).to include('spams')
      end

      it 'includes footer' do
        expect(html_body).to include('Cet email a été envoyé automatiquement par Afternoon')
      end
    end

    context 'without customer message' do
      before do
        basket_item.update!(customer_message: nil)
      end

      it 'does not show message section' do
        html_body = mail.html_part.body.to_s
        expect(html_body).not_to include('Votre message :')
      end
    end

    context 'without recruitment office' do
      let(:agent_without_office) do
        agent_user = create(:user, :agent_user, email: 'agent2@example.com', first_name: 'Pierre', last_name: 'Durand')
        agent_user.update_column(:recruitment_office_id, nil)
        agent_user.reload
        agent_user
      end
      let(:basket_item_no_office) { create(:basket_item, :meeting_requested, basket: basket, agent: agent_without_office) }

      before do
        basket_item_no_office.basket_item_candidates.create!(candidate: candidate1, added_at: Time.current)
      end

      let(:mail) { described_class.meeting_request_confirmation(basket_item: basket_item_no_office) }

      it 'still generates valid email' do
        expect { mail }.not_to raise_error
      end

      it 'does not show office name' do
        html_body = mail.html_part.body.to_s
        expect(html_body).not_to include('Cabinet')
      end
    end

    context 'with single candidate' do
      let(:agent2) { create(:user, :agent_user, email: 'agent3@example.com', first_name: 'Sophie', last_name: 'Leroux', recruitment_office: recruitment_office) }
      let(:basket_item_single) { create(:basket_item, :meeting_requested, basket: basket, agent: agent2) }

      before do
        basket_item_single.basket_item_candidates.create!(candidate: candidate1, added_at: Time.current)
      end

      let(:mail) { described_class.meeting_request_confirmation(basket_item: basket_item_single) }

      it 'shows singular candidate count' do
        html_body = mail.html_part.body.to_s
        expect(html_body).to include('1')
      end
    end

    describe 'styling' do
      let(:html_body) { mail.html_part.body.to_s }

      it 'has styled sections with colors' do
        expect(html_body).to include('background-color')
        expect(html_body).to include('border-radius')
      end

      it 'highlights next steps section' do
        expect(html_body).to include('#d4edda') # Green background
        expect(html_body).to include('Prochaines étapes')
      end

      it 'highlights contact section' do
        expect(html_body).to include('#e3f2fd') # Blue background
        expect(html_body).to include('Pour échanger avec l\'agent')
      end

      it 'includes warning about spam' do
        expect(html_body).to include('#fff3e0') # Orange background
        expect(html_body).to include('Surveillez votre boîte email')
      end
    end
  end
end
