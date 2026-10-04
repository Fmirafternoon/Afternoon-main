require 'rails_helper'

RSpec.describe Calendar::GenerateInvite do
  let(:recruitment_office) { create(:recruitment_office, address: "15 rue du Commerce", city: "Paris", zip_code: "75015") }
  let(:agent) { create(:user, :agent_user, recruitment_office: recruitment_office, email: "agent@example.com") }
  let(:customer) { create(:user, :customer, email: "customer@example.com") }
  let(:basket) { create(:basket, customer: customer) }
  let(:basket_item) do
    create(:basket_item, :meeting_requested,
           basket: basket,
           agent: agent,
           meeting_date: Time.zone.parse("2025-10-30 14:00:00"),
           customer_message: "Je souhaite discuter de ces profils")
  end
  let!(:candidate1) { create(:candidate, agent: agent, first_name: "Jean", last_name: "Dupont") }
  let!(:candidate2) { create(:candidate, agent: agent, first_name: "Marie", last_name: "Martin") }

  before do
    basket_item.add_candidate(candidate1)
    basket_item.add_candidate(candidate2)
    basket_item.reload
  end

  let(:actor_result) { described_class.call(basket_item: basket_item) }

  describe '#call' do
    it 'returns success' do
      expect(actor_result).to be_success
    end

    it 'returns ics_content as a string' do
      expect(actor_result.ics_content).to be_a(String)
    end

    context 'ICS content validation' do
      let(:ics_content) { actor_result.ics_content }

      it 'contains BEGIN:VCALENDAR' do
        expect(ics_content).to include('BEGIN:VCALENDAR')
      end

      it 'contains END:VCALENDAR' do
        expect(ics_content).to include('END:VCALENDAR')
      end

      it 'contains BEGIN:VEVENT' do
        expect(ics_content).to include('BEGIN:VEVENT')
      end

      it 'contains END:VEVENT' do
        expect(ics_content).to include('END:VEVENT')
      end

      it 'contains meeting start date' do
        # Format iCalendar: YYYYMMDDTHHMMSS
        expect(ics_content).to include('DTSTART:20251030T140000')
      end

      it 'contains meeting end date (start + 60 minutes)' do
        # Fin du RDV: 15:00:00
        expect(ics_content).to include('DTEND:20251030T150000')
      end

      it 'contains meeting summary' do
        expect(ics_content).to include('SUMMARY:RDV - 2 candidat')
      end

      it 'contains organizer (customer email)' do
        expect(ics_content).to include('ORGANIZER')
        expect(ics_content).to include('customer@example.com')
      end

      it 'contains attendee (agent email)' do
        expect(ics_content).to include('ATTENDEE')
        expect(ics_content).to include('agent@example.com')
      end

      it 'contains location (recruitment office address)' do
        # Dans le format ICS, les virgules sont échappées
        expect(ics_content).to include('LOCATION:15 rue du Commerce\\, 75015 Paris')
      end

      it 'contains description with candidate names' do
        expect(ics_content).to include('DESCRIPTION')
        expect(ics_content).to include('Jean Dupont')
        expect(ics_content).to include('Marie Martin')
      end

      it 'contains customer message in description' do
        # Le format ICS peut wrapper les longues lignes, donc on vérifie sans les retours à la ligne
        expect(ics_content.gsub(/\r\n\s/, '')).to include('Je souhaite discuter de ces profils')
      end
    end

    context 'with one candidate' do
      let(:customer_single) { create(:user, :customer) }
      let(:recruitment_office_single) { create(:recruitment_office) }
      let(:agent_single) { create(:user, :agent_user, recruitment_office: recruitment_office_single) }
      let(:basket_single) { create(:basket, customer: customer_single) }
      let(:basket_item_single) do
        create(:basket_item, :meeting_requested,
               basket: basket_single,
               agent: agent_single,
               meeting_date: Time.zone.parse("2025-10-30 14:00:00"))
      end
      let(:candidate_single) { create(:candidate, agent: agent_single, first_name: "Paul", last_name: "Durand") }

      before do
        basket_item_single.add_candidate(candidate_single)
        basket_item_single.reload
      end

      it 'uses singular form in summary' do
        result = described_class.call(basket_item: basket_item_single)
        expect(result.ics_content).to include('SUMMARY:RDV - 1 candidat')
      end
    end

    context 'with no customer message' do
      let(:basket_item) do
        create(:basket_item, :meeting_requested,
               basket: basket,
               agent: agent,
               meeting_date: Time.zone.parse("2025-10-30 14:00:00"),
               customer_message: nil)
      end

      before do
        basket_item.add_candidate(candidate1)
      end

      it 'generates ICS without error' do
        expect(actor_result).to be_success
        expect(actor_result.ics_content).to be_present
      end
    end

    context 'with recruitment office without address' do
      let(:recruitment_office) { create(:recruitment_office, address: nil, city: nil, zip_code: nil) }

      it 'generates ICS without error' do
        expect(actor_result).to be_success
        expect(actor_result.ics_content).to be_present
      end

      it 'handles missing location gracefully' do
        ics_content = actor_result.ics_content
        expect(ics_content).to include('BEGIN:VEVENT')
      end
    end
  end
end
