require 'rails_helper'

RSpec.describe CalendarHelper, type: :helper do
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
  let(:candidate1) { create(:candidate, agent: agent, first_name: "Jean", last_name: "Dupont") }
  let(:candidate2) { create(:candidate, agent: agent, first_name: "Marie", last_name: "Martin") }

  before do
    basket_item.add_candidate(candidate1)
    basket_item.add_candidate(candidate2)
    basket_item.reload
  end

  describe '#google_calendar_url' do
    let(:url) { helper.google_calendar_url(basket_item) }
    let(:parsed_url) { URI.parse(url) }
    let(:params) { URI.decode_www_form(parsed_url.query).to_h }

    it 'returns a Google Calendar URL' do
      expect(url).to start_with('https://calendar.google.com/calendar/render')
    end

    it 'includes action=TEMPLATE parameter' do
      expect(params['action']).to eq('TEMPLATE')
    end

    it 'includes meeting title with candidate count' do
      expect(params['text']).to eq('RDV - 2 candidats')
    end

    it 'includes meeting start date in correct format' do
      # Format Google: YYYYMMDDTHHmmss
      expect(params['dates']).to start_with('20251030T140000')
    end

    it 'includes meeting end date (60 minutes after start)' do
      # Format: start/end
      expect(params['dates']).to eq('20251030T140000/20251030T150000')
    end

    it 'includes location' do
      expect(params['location']).to eq('15 rue du Commerce, 75015 Paris')
    end

    it 'includes description with candidates' do
      expect(params['details']).to include('Jean Dupont')
      expect(params['details']).to include('Marie Martin')
    end

    it 'includes customer message in description' do
      expect(params['details']).to include('Je souhaite discuter de ces profils')
    end

    context 'with one candidate' do
      let(:agent_single) { create(:user, :agent_user, recruitment_office: recruitment_office) }
      let(:basket_item_single) do
        create(:basket_item, :meeting_requested,
               basket: basket,
               agent: agent_single,
               meeting_date: Time.zone.parse("2025-10-30 14:00:00"))
      end
      let(:candidate_single) { create(:candidate, agent: agent_single, first_name: "Paul", last_name: "Durand") }

      before do
        basket_item_single.add_candidate(candidate_single)
        basket_item_single.reload
      end

      it 'uses singular form in title' do
        url = helper.google_calendar_url(basket_item_single)
        params = URI.decode_www_form(URI.parse(url).query).to_h
        expect(params['text']).to eq('RDV - 1 candidat')
      end
    end

    context 'with no recruitment office address' do
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

      it 'returns URL without location parameter' do
        url = helper.google_calendar_url(basket_item_no_address)
        params = URI.decode_www_form(URI.parse(url).query).to_h
        expect(params['location']).to be_nil
      end
    end
  end

  describe '#outlook_calendar_url' do
    let(:url) { helper.outlook_calendar_url(basket_item) }
    let(:parsed_url) { URI.parse(url) }
    let(:params) { URI.decode_www_form(parsed_url.query).to_h }

    it 'returns an Outlook Calendar URL' do
      expect(url).to start_with('https://outlook.live.com/calendar/0/deeplink/compose')
    end

    it 'includes meeting title with candidate count' do
      expect(params['subject']).to eq('RDV - 2 candidats')
    end

    it 'includes meeting start date in ISO8601 format' do
      # Format Outlook: ISO8601 avec timezone
      expect(params['startdt']).to eq('2025-10-30T14:00:00')
    end

    it 'includes meeting end date (60 minutes after start)' do
      expect(params['enddt']).to eq('2025-10-30T15:00:00')
    end

    it 'includes location' do
      expect(params['location']).to eq('15 rue du Commerce, 75015 Paris')
    end

    it 'includes description with candidates' do
      expect(params['body']).to include('Jean Dupont')
      expect(params['body']).to include('Marie Martin')
    end

    it 'includes customer message in description' do
      expect(params['body']).to include('Je souhaite discuter de ces profils')
    end

    context 'with one candidate' do
      let(:agent_single_outlook) { create(:user, :agent_user, recruitment_office: recruitment_office) }
      let(:basket_item_single_outlook) do
        create(:basket_item, :meeting_requested,
               basket: basket,
               agent: agent_single_outlook,
               meeting_date: Time.zone.parse("2025-10-30 14:00:00"))
      end
      let(:candidate_single_outlook) { create(:candidate, agent: agent_single_outlook, first_name: "Paul", last_name: "Durand") }

      before do
        basket_item_single_outlook.add_candidate(candidate_single_outlook)
        basket_item_single_outlook.reload
      end

      it 'uses singular form in title' do
        url = helper.outlook_calendar_url(basket_item_single_outlook)
        params = URI.decode_www_form(URI.parse(url).query).to_h
        expect(params['subject']).to eq('RDV - 1 candidat')
      end
    end

    context 'with no recruitment office address' do
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

      it 'returns URL without location parameter' do
        url = helper.outlook_calendar_url(basket_item_no_address)
        params = URI.decode_www_form(URI.parse(url).query).to_h
        expect(params['location']).to be_nil
      end
    end
  end
end
