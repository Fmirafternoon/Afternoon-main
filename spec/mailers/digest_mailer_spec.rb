require 'rails_helper'

RSpec.describe DigestMailer, type: :mailer do
  describe '#weekly_alert' do
    let(:customer) { create(:user, :customer, email: 'customer@example.com', first_name: 'Jean') }
    let(:saved_search1) { create(:saved_search, customer: customer, name: 'Développeurs Ruby Paris') }
    let(:saved_search2) { create(:saved_search, customer: customer, name: 'Data Scientists Lyon') }
    
    let(:candidate1) do
      location = create(:location, city: 'Paris', zip_code: '75001')
      candidate = create(:candidate, 
        first_name: 'Marie',
        last_name: 'Dupont',
        position: 'Développeuse Full Stack',
        total_experience_in_years: 5,
        location: location
      )
      ['Ruby', 'Rails', 'PostgreSQL', 'JavaScript', 'React'].each do |skill_name|
        skill = Skill.find_or_create_by!(name: skill_name)
        candidate.candidate_skills.create!(skill: skill)
      end
      candidate
    end
    
    let(:candidate2) do
      location = create(:location, city: 'Lyon', zip_code: '69001')
      candidate = create(:candidate,
        first_name: 'Pierre',
        last_name: 'Martin',
        position: 'Lead Developer',
        total_experience_in_years: 8,
        location: location
      )
      ['Python', 'Django', 'Machine Learning'].each do |skill_name|
        skill = Skill.find_or_create_by!(name: skill_name)
        candidate.candidate_skills.create!(skill: skill)
      end
      candidate
    end

    let(:alerts_data) do
      [
        {
          search: saved_search1,
          candidates: [candidate1],
          total_count: 1
        },
        {
          search: saved_search2,
          candidates: [candidate2],
          total_count: 1
        }
      ]
    end

    let(:mail) { described_class.weekly_alert(customer: customer, alerts_data: alerts_data) }

    describe 'email headers' do
      it 'sends to the correct email' do
        expect(mail.to).to eq([customer.email])
      end

      it 'has the correct subject' do
        expect(mail.subject).to eq('📊 2 nouveaux candidats cette semaine')
      end

      it 'sends from the default email' do
        expect(mail.from).to eq([ApplicationMailer.default[:from]])
      end
    end

    describe 'email body' do
      let(:html_body) { mail.html_part.body.to_s }
      let(:text_body) { mail.text_part.body.to_s }

      it 'includes customer first name' do
        expect(html_body).to include('Jean')
      end

      it 'includes total candidates count in header' do
        expect(html_body).to include('2 nouveaux candidats cette semaine')
      end

      it 'includes number of active searches' do
        expect(html_body).to include('2 nouveaux candidats')
      end

      it 'includes saved search names' do
        expect(html_body).to include('Développeurs Ruby Paris')
        expect(html_body).to include('Data Scientists Lyon')
      end

      it 'includes candidate information' do
        expect(html_body).to include('Marie Dupont')
        expect(html_body).to include('Développeuse Full Stack')
        expect(html_body).to include('Paris')
      end

      it 'includes candidate skills' do
        expect(html_body).to include('Ruby')
        expect(html_body).to include('Rails')
        expect(html_body).to include('PostgreSQL')
      end

      it 'limits skills display to 5' do
        expect(html_body).to include('JavaScript')
        expect(html_body).to include('React')
      end

      it 'includes links to candidate profiles' do
        expect(html_body).to include(customer_candidate_url(candidate1))
        expect(html_body).to include(customer_candidate_url(candidate2))
      end

      it 'includes unsubscribe link' do
        expect(html_body).to include('unsubscribe')
        expect(html_body).to include('token=')
      end

      it 'includes link to manage searches' do
        expect(html_body).to include('saved_searches')
      end

      context 'when a search has more candidates than shown' do
        let(:extra_candidates) { create_list(:candidate, 3) }
        let(:alerts_data) do
          [{
            search: saved_search1,
            candidates: [candidate1, candidate2] + extra_candidates.first(1),
            total_count: 5
          }]
        end

        it 'shows only first 3 candidates per search' do
          expect(html_body).to include('candidats')
        end

        it 'includes link to see all candidates' do
          expect(html_body).to include('candidat')
        end
      end

      context 'with proper styling' do
        it 'includes necessary CSS styles' do
          expect(html_body).to include('font-family')
          expect(html_body).to include('background-color')
          expect(html_body).to include('border-radius')
        end

        it 'has container with correct width' do
          expect(html_body).to include('width="600"')
        end
      end
    end

    describe 'unsubscribe token generation' do
      let(:test_token) { 'test_token' }

      it 'generates a token with correct parameters' do
        test_mail = described_class.weekly_alert(customer: customer, alerts_data: alerts_data)
        html_body = test_mail.html_part.body.to_s
        
        expect(html_body).to include('unsubscribe')
        expect(html_body).to include('token=')
      end

      it 'includes the token in unsubscribe URL' do
        allow(Rails.application.message_verifier(:unsubscribe)).to receive(:generate)
          .and_return(test_token)
        
        test_mail = described_class.weekly_alert(customer: customer, alerts_data: alerts_data)
        expect(test_mail.html_part.body.to_s).to include('token=test_token')
      end
    end

    describe 'edge cases' do
      context 'with no alerts data' do
        let(:alerts_data) { [] }

        it 'still generates email with 0 candidates' do
          expect(mail.subject).to eq('📊 0 nouveaux candidats cette semaine')
        end
      end

      context 'with candidates without skills' do
        before { candidate1.update!(skills: []) }

        it 'handles empty skills gracefully' do
          expect { mail }.not_to raise_error
        end
      end

      context 'with very long candidate names' do
        before do
          candidate1.update!(
            first_name: 'Jean-Baptiste-Emmanuel',
            last_name: 'De La Rochefoucauld-Liancourt'
          )
        end

        it 'includes full name' do
          expect(mail.html_part.body.to_s).to include('Jean-Baptiste-Emmanuel De La Rochefoucauld-Liancourt')
        end
      end
    end

    describe 'multipart email' do
      it 'generates both HTML and text parts' do
        expect(mail.parts.count).to eq(2)
        expect(mail.html_part).to be_present
        expect(mail.text_part).to be_present
      end

      it 'text part contains essential information' do
        text_body = mail.text_part.body.to_s
        expect(text_body).to include('2 nouveaux candidats cette semaine')
        expect(text_body).to include('Marie Dupont')
        expect(text_body).to include('Développeuse Full Stack')
      end
    end
  end
end