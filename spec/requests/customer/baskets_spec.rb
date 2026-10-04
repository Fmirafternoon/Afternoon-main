require 'rails_helper'

RSpec.describe "Customer::Baskets", type: :request do
  let(:customer) { create(:user, :customer) }
  let(:other_customer) { create(:user, :customer) }
  let(:recruitment_office) { create(:recruitment_office, address: "15 rue du Commerce", city: "Paris", zip_code: "75015") }
  let(:agent) { create(:user, :agent_user, recruitment_office: recruitment_office) }
  let(:basket) { create(:basket, customer: customer) }
  let(:basket_item) do
    create(:basket_item, :meeting_requested,
           basket: basket,
           agent: agent,
           meeting_date: Time.zone.parse("2025-10-30 14:00:00"),
           customer_message: "Je souhaite discuter de ces profils")
  end
  let(:candidate1) { create(:candidate, agent: agent, first_name: "Jean", last_name: "Dupont") }
  let(:candidate2) { create(:candidate, agent: agent, first_name: "Marie", last_name: "Martin") }

  before do
    sign_in customer
    basket_item.add_candidate(candidate1)
    basket_item.add_candidate(candidate2)
    basket_item.reload
  end

  describe 'GET /customer/basket/calendar/:id' do
    context 'when authenticated as the basket owner' do
      it 'returns a successful response' do
        get customer_basket_calendar_path(id: basket_item.id)
        expect(response).to be_successful
      end

      it 'returns ICS content type' do
        get customer_basket_calendar_path(id: basket_item.id)
        expect(response.media_type).to eq('text/calendar')
      end

      it 'sets content disposition as attachment' do
        get customer_basket_calendar_path(id: basket_item.id)
        expect(response.headers['Content-Disposition']).to include('attachment')
      end

      it 'includes basket item id in filename' do
        get customer_basket_calendar_path(id: basket_item.id)
        expect(response.headers['Content-Disposition']).to include("rdv-afternoon-#{basket_item.id}.ics")
      end

      it 'returns valid ICS content' do
        get customer_basket_calendar_path(id: basket_item.id)
        expect(response.body).to include('BEGIN:VCALENDAR')
        expect(response.body).to include('END:VCALENDAR')
        expect(response.body).to include('BEGIN:VEVENT')
        expect(response.body).to include('END:VEVENT')
      end

      it 'includes meeting details in ICS' do
        get customer_basket_calendar_path(id: basket_item.id)
        expect(response.body).to include('SUMMARY:RDV - 2 candidats')
        expect(response.body).to include('Jean Dupont')
        expect(response.body).to include('Marie Martin')
        expect(response.body).to include('DTSTART:20251030T140000')
        expect(response.body).to include('DTEND:20251030T150000')
      end

      it 'includes location in ICS' do
        get customer_basket_calendar_path(id: basket_item.id)
        # Les virgules sont échappées dans le format ICS
        expect(response.body).to include('LOCATION:15 rue du Commerce\\, 75015 Paris')
      end

      it 'includes organizer (customer) in ICS' do
        get customer_basket_calendar_path(id: basket_item.id)
        expect(response.body).to include("ORGANIZER")
        expect(response.body).to include(customer.email)
      end

      it 'includes attendee (agent) in ICS' do
        get customer_basket_calendar_path(id: basket_item.id)
        expect(response.body).to include("ATTENDEE")
        expect(response.body).to include(agent.email)
      end
    end

    context 'when basket item does not exist' do
      it 'returns 404' do
        get customer_basket_calendar_path(id: 999999)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do
      before { sign_out customer }

      it 'redirects to sign in' do
        get customer_basket_calendar_path(id: basket_item.id)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when authenticated as different customer' do
      before do
        sign_out customer
        sign_in other_customer
      end

      it 'returns 404 (basket_item not found in other customer basket)' do
        get customer_basket_calendar_path(id: basket_item.id)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with basket item with no address' do
      let(:recruitment_office_no_address) { create(:recruitment_office, address: nil, city: nil, zip_code: nil) }
      let(:agent_no_address) { create(:user, :agent_user, recruitment_office: recruitment_office_no_address) }
      let(:basket_item_no_address) do
        create(:basket_item, :meeting_requested,
               basket: basket,
               agent: agent_no_address,
               meeting_date: Time.zone.parse("2025-10-30 14:00:00"))
      end

      before do
        basket_item_no_address.add_candidate(candidate1)
        basket_item_no_address.reload
      end

      it 'returns valid ICS without location' do
        get customer_basket_calendar_path(id: basket_item_no_address.id)
        expect(response).to be_successful
        expect(response.body).to include('BEGIN:VEVENT')
        # Ne devrait pas avoir de LOCATION si pas d'adresse
        expect(response.body).not_to include('LOCATION:')
      end
    end
  end
end
