require 'rails_helper'
require 'cgi'

RSpec.describe AgentMailer, type: :mailer do
  describe '#candidate_expiration_reminder' do
    let(:agent) { create(:user, :agent_user, email: 'agent@example.com', first_name: 'Marie') }
    let(:candidate) do
      create(:candidate,
             first_name: 'Jean',
             last_name: 'Dupont',
             position: 'Développeur Ruby',
             publication_status: :published,
             published_at: 12.days.ago,
             expires_at: 2.days.from_now,
             expiration_notified_at: nil,
             agent: agent)
    end

    let(:mail) { described_class.candidate_expiration_reminder(candidate.id) }

    describe 'email headers' do
      it 'sends to the agent email' do
        expect(mail.to).to eq([agent.email])
      end

      it 'has the correct subject' do
        expect(mail.subject).to eq("[Afternoon] Prolonger ou dépublier #{candidate.full_name} ?")
      end

      it 'sends from the default email' do
        expect(mail.from).to eq([ApplicationMailer.default[:from]])
      end
    end

    describe 'email body' do
      let(:html_body) { mail.html_part.body.to_s }

      it 'includes agent first name' do
        expect(html_body).to include('Bonjour Marie')
      end

      it 'includes candidate full name' do
        expect(html_body).to include('Jean Dupont')
      end

      it 'includes candidate position' do
        expect(html_body).to include('Développeur Ruby')
      end

      it 'mentions the expiration deadline' do
        expect(html_body).to include('2 jours')
      end

      it 'includes extend button' do
        expect(html_body).to include('Prolonger de 14 jours')
      end

      it 'includes unpublish button' do
        expect(html_body).to include('Dépublier')
      end

      it 'includes footer' do
        expect(html_body).to include('Cet email a été envoyé automatiquement par Afternoon')
      end
    end

    describe 'token generation' do
      let(:html_body) { mail.html_part.body.to_s }

      it 'generates extend token URL' do
        expect(html_body).to include('candidate_expirations/extend')
        expect(html_body).to match(/token=[^"&]+/)
      end

      it 'generates unpublish token URL' do
        expect(html_body).to include('candidate_expirations/unpublish')
        expect(html_body).to match(/token=[^"&]+/)
      end

      it 'generates unique tokens for each action' do
        extend_url = html_body[/candidate_expirations\/extend\?token=([^"&]+)/, 1]
        unpublish_url = html_body[/candidate_expirations\/unpublish\?token=([^"&]+)/, 1]

        expect(extend_url).to be_present
        expect(unpublish_url).to be_present
        expect(extend_url).not_to eq(unpublish_url)
      end
    end

    describe 'token verification' do
      before do
        mail # Trigger mail generation
      end

      it 'generates valid tokens that can be verified' do
        html_body = mail.html_part.body.to_s
        extend_token = CGI.unescape(html_body[/candidate_expirations\/extend\?token=([^"&]+)/, 1])

        expect do
          data = Rails.application.message_verifier(:candidate_expiration).verify(extend_token)
          expect(data["candidate_id"]).to eq(candidate.id)
          expect(data["action"]).to eq('extend')
          expect(Time.parse(data["expires_at"])).to be > Time.current
        end.not_to raise_error
      end
    end

    describe 'styling' do
      let(:html_body) { mail.html_part.body.to_s }

      it 'includes inline CSS styles' do
        expect(html_body).to include('font-family')
        expect(html_body).to include('background-color')
      end

      it 'has container with correct width' do
        expect(html_body).to include('width="600"')
      end

      it 'styles action buttons' do
        expect(html_body).to include('padding')
        expect(html_body).to include('text-decoration: none')
      end
    end

    context 'with candidate without position' do
      before do
        candidate.update(position: nil, resume_file_name: 'cv_jean_dupont.pdf')
      end

      it 'uses resume_file_name as fallback' do
        html_body = mail.html_part.body.to_s
        expect(html_body).to include('cv_jean_dupont.pdf')
      end
    end

    context 'text part' do
      let(:text_body) { mail.text_part.body.to_s }

      it 'includes candidate name in text version' do
        expect(text_body).to include('Jean Dupont')
      end

      it 'includes extend URL in text version' do
        expect(text_body).to include('candidate_expirations/extend')
      end

      it 'includes unpublish URL in text version' do
        expect(text_body).to include('candidate_expirations/unpublish')
      end
    end
  end
end
