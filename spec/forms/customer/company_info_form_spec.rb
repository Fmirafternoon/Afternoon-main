require 'rails_helper'

RSpec.describe Customer::CompanyInfoForm do
  let(:user) { create(:user, :customer) }
  let(:form) { described_class.new(attributes) }
  let(:attributes) { {} }

  before do
    Current.user = user
  end

  after do
    Current.user = nil
  end

  describe '#initialize' do
    it 'sets attributes from hash' do
      form = described_class.new(company_name: 'Test Company', siren: '123456789')
      expect(form.company_name).to eq('Test Company')
      expect(form.siren).to eq('123456789')
    end
  end

  describe 'validations' do
    describe 'basic validations' do
      it 'requires company_name' do
        form = described_class.new(siren: '123456789')
        expect(form).not_to be_valid
        expect(form.errors[:company_name]).to include("doit être rempli(e)")
      end

      it 'requires siren' do
        form = described_class.new(company_name: 'Test Company')
        expect(form).not_to be_valid
        expect(form.errors[:siren]).to include("doit être rempli(e)")
      end

      it 'is valid with all required fields' do
        form = described_class.new(company_name: 'Test Company', siren: '123456789')
        expect(form).to be_valid
      end
    end

    describe 'location validations' do
      context 'when autocomplete_address is present' do
        let(:attributes) do
          {
            company_name: 'Test Company',
            siren: '123456789',
            autocomplete_address: '123 Main St, Paris'
          }
        end

        it 'requires zip_code' do
          form.city = 'Paris'
          expect(form).not_to be_valid
          expect(form.errors[:zip_code]).to include("doit être rempli(e)")
        end

        it 'requires city' do
          form.zip_code = '75001'
          expect(form).not_to be_valid
          expect(form.errors[:city]).to include("doit être rempli(e)")
        end

        it 'is valid with both zip_code and city' do
          form.zip_code = '75001'
          form.city = 'Paris'
          expect(form).to be_valid
        end
      end

      context 'when autocomplete_address is blank' do
        let(:attributes) do
          {
            company_name: 'Test Company',
            siren: '123456789'
          }
        end

        it 'does not require zip_code or city' do
          expect(form).to be_valid
        end
      end
    end

    describe 'sector validation' do
      context 'on :add_sector context' do
        it 'requires sector_id' do
          form = described_class.new(company_name: 'Test', siren: '123')
          expect(form).not_to be_valid(:add_sector)
          expect(form.errors[:sector_id]).to include("doit être rempli(e)")
        end

        it 'is valid with sector_id' do
          form = described_class.new(company_name: 'Test', siren: '123', sector_id: 1)
          expect(form).to be_valid(:add_sector)
        end
      end
    end
  end

  describe '#save' do
    context 'when user has no company' do
      before do
        user.update!(company: nil)
      end
      
      let(:attributes) do
        {
          company_name: 'New Company',
          siren: '987654321'
        }
      end

      it 'creates a new company' do
        expect {
          form.save
        }.to change { Company.count }.by(1)
      end

      it 'associates company with user' do
        form.save
        expect(user.reload.company).to be_present
        expect(user.company.name).to eq('New Company')
        expect(user.company.siren).to eq('987654321')
      end

      it 'returns true' do
        expect(form.save).to be true
      end
    end

    context 'when user already has a company' do
      let!(:company) { create(:company, name: 'Old Company', siren: '111111111') }
      let(:attributes) do
        {
          company_name: 'Updated Company',
          siren: '222222222'
        }
      end

      before do
        user.update!(company: company)
      end

      it 'does not create a new company' do
        expect {
          form.save
        }.not_to change { Company.count }
      end

      it 'updates existing company' do
        form.save
        company.reload
        expect(company.name).to eq('Updated Company')
        expect(company.siren).to eq('222222222')
      end

      it 'returns true' do
        expect(form.save).to be true
      end
    end

    context 'when validation fails' do
      let(:attributes) { { company_name: '' } }

      it 'returns false' do
        expect(form.save).to be false
      end

      it 'does not create or update company' do
        expect {
          form.save
        }.not_to change { Company.count }
      end
    end
  end

  describe '#persist_location!' do
    let!(:company) { create(:company) }

    before do
      user.update!(company: company)
    end

    context 'with valid location data' do
      let(:attributes) do
        {
          autocomplete_address: '123 Main St, Paris',
          lat: '48.8566',
          lng: '2.3522',
          zip_code: '75001',
          city: 'Paris'
        }
      end

      it 'creates or finds a location' do
        expect {
          form.persist_location!
        }.to change { Location.count }.by(1)
      end

      it 'creates location with correct attributes' do
        location = form.persist_location!
        expect(location.latitude).to eq(48.8566)
        expect(location.longitude).to eq(2.3522)
        expect(location.zip_code).to eq('75001')
        expect(location.city).to eq('Paris')
      end

      it 'adds location to company' do
        expect {
          form.persist_location!
        }.to change { company.locations.count }.by(1)
      end

      it 'returns the location' do
        location = form.persist_location!
        expect(location).to be_a(Location)
      end

      context 'when location already exists' do
        let!(:existing_location) do
          create(:location, city: 'Paris', zip_code: '75001', latitude: 48.8566, longitude: 2.3522)
        end

        it 'does not create duplicate location' do
          expect {
            form.persist_location!
          }.not_to change { Location.count }
        end

        it 'adds existing location to company' do
          form.persist_location!
          expect(company.locations).to include(existing_location)
        end
      end
    end

    context 'when autocomplete_address is blank' do
      it 'returns nil' do
        expect(form.persist_location!).to be_nil
      end
    end

    context 'when lat/lng are missing' do
      let(:attributes) do
        {
          autocomplete_address: '123 Main St',
          zip_code: '75001',
          city: 'Paris'
        }
      end

      it 'returns nil' do
        expect(form.persist_location!).to be_nil
      end
    end

    context 'when zip_code/city are missing' do
      let(:attributes) do
        {
          autocomplete_address: '123 Main St',
          lat: '48.8566',
          lng: '2.3522'
        }
      end

      it 'returns nil' do
        expect(form.persist_location!).to be_nil
      end
    end

    context 'when user has no company' do
      before do
        user.update!(company: nil)
      end

      let(:attributes) do
        {
          autocomplete_address: '123 Main St',
          lat: '48.8566',
          lng: '2.3522',
          zip_code: '75001',
          city: 'Paris'
        }
      end

      it 'returns nil' do
        expect(form.persist_location!).to be_nil
      end

      it 'does not create location' do
        expect {
          form.persist_location!
        }.not_to change { Location.count }
      end
    end
  end

  describe '#persist_sector!' do
    let!(:company) { create(:company) }
    let!(:sector) { create(:sector) }

    before do
      user.update!(company: company)
    end

    context 'with valid sector' do
      let(:attributes) do
        {
          company_name: 'Test',
          siren: '123',
          sector_id: sector.id
        }
      end

      it 'adds sector to company' do
        expect {
          form.persist_sector!
        }.to change { company.sectors.count }.by(1)
      end

      it 'adds the correct sector' do
        form.persist_sector!
        expect(company.sectors).to include(sector)
      end

      it 'returns true' do
        expect(form.persist_sector!).to be true
      end
    end

    context 'with invalid sector' do
      let(:attributes) do
        {
          company_name: 'Test',
          siren: '123',
          sector_id: nil
        }
      end

      it 'does not add sector' do
        expect {
          form.persist_sector!
        }.not_to change { company.sectors.count }
      end

      it 'returns false' do
        expect(form.persist_sector!).to be false
      end
    end
  end

  describe 'private methods' do
    describe '#current_user' do
      it 'returns Current.user' do
        expect(form.send(:current_user)).to eq(user)
      end
    end
  end
end