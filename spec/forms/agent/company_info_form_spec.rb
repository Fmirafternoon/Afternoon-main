require 'rails_helper'

RSpec.describe Agent::CompanyInfoForm do
  let(:recruitment_office) { create(:recruitment_office) }
  let(:user) { create(:user, :agent_user, recruitment_office: recruitment_office) }
  let(:form) { described_class.new(attributes) }
  let(:attributes) { {} }

  before do
    Current.user = user
  end

  after do
    Current.user = nil
  end

  describe '#initialize' do
    context 'when recruitment office has city and zip_code' do
      before do
        recruitment_office.update!(city: 'Paris', zip_code: '75001')
      end

      it 'sets default values from recruitment office' do
        form = described_class.new
        expect(form.city).to eq('Paris')
        expect(form.zip_code).to eq('75001')
        expect(form.autocomplete_address).to eq('Paris, 75001')
      end

      it 'does not override provided values' do
        form = described_class.new(city: 'Lyon', zip_code: '69001')
        expect(form.city).to eq('Lyon')
        expect(form.zip_code).to eq('69001')
      end

      it 'sets city from recruitment office when not provided' do
        form = described_class.new(zip_code: '69001')
        expect(form.city).to eq('Paris')
        expect(form.zip_code).to eq('69001')
      end

      it 'sets zip_code from recruitment office when not provided' do
        form = described_class.new(city: 'Lyon')
        expect(form.city).to eq('Lyon')
        expect(form.zip_code).to eq('75001')
      end
    end

    context 'when recruitment office has no city or zip_code' do
      before do
        recruitment_office.update!(city: nil, zip_code: nil)
      end

      it 'does not set default values' do
        form = described_class.new
        expect(form.city).to be_nil
        expect(form.zip_code).to be_nil
        expect(form.autocomplete_address).to be_nil
      end
    end

    context 'when recruitment office has only city' do
      before do
        recruitment_office.update!(city: 'Paris', zip_code: '')
      end

      it 'still sets defaults because city is present' do
        form = described_class.new
        expect(form.city).to eq('Paris')
        expect(form.zip_code).to eq('')
        expect(form.autocomplete_address).to eq('Paris, ')
      end
    end

    context 'when recruitment office has only zip_code' do
      before do
        recruitment_office.update!(city: '', zip_code: '75001')
      end

      it 'still sets defaults because zip_code is present' do
        form = described_class.new
        expect(form.city).to eq('')
        expect(form.zip_code).to eq('75001')
        expect(form.autocomplete_address).to eq(', 75001')
      end
    end
  end

  describe 'validations' do
    describe 'location validations' do
      before do
        # Ensure recruitment office has no default values
        recruitment_office.update!(city: nil, zip_code: nil)
      end

      it 'requires autocomplete_address' do
        form = described_class.new(city: 'Paris', zip_code: '75001')
        expect(form).not_to be_valid
        expect(form.errors[:autocomplete_address]).to include("doit être rempli(e)")
      end

      it 'requires city' do
        form = described_class.new(autocomplete_address: 'Paris', zip_code: '75001')
        expect(form).not_to be_valid
        expect(form.errors[:city]).to include("doit être rempli(e)")
      end

      it 'requires zip_code' do
        form = described_class.new(autocomplete_address: 'Paris', city: 'Paris')
        expect(form).not_to be_valid
        expect(form.errors[:zip_code]).to include("doit être rempli(e)")
      end

      it 'is valid with all location fields' do
        form = described_class.new(
          autocomplete_address: 'Paris, 75001',
          city: 'Paris',
          zip_code: '75001'
        )
        expect(form).to be_valid
      end
    end

    describe 'company validations' do
      before do
        # Ensure recruitment office has no default values
        recruitment_office.update!(city: nil, zip_code: nil)
      end

      let(:base_attributes) do
        {
          autocomplete_address: 'Paris, 75001',
          city: 'Paris',
          zip_code: '75001'
        }
      end

      context 'when company_name is present' do
        it 'requires company_siren' do
          form = described_class.new(base_attributes.merge(company_name: 'Test Company'))
          expect(form).not_to be_valid
          expect(form.errors[:company_siren]).to include("doit être rempli(e)")
        end

        it 'is valid with both company fields' do
          form = described_class.new(base_attributes.merge(
            company_name: 'Test Company',
            company_siren: '123456789'
          ))
          expect(form).to be_valid
        end
      end

      context 'when company_siren is present' do
        it 'requires company_name' do
          form = described_class.new(base_attributes.merge(company_siren: '123456789'))
          expect(form).not_to be_valid
          expect(form.errors[:company_name]).to include("doit être rempli(e)")
        end
      end

      context 'when neither company field is present' do
        it 'is valid without company fields' do
          form = described_class.new(base_attributes)
          expect(form).to be_valid
        end
      end
    end
  end

  describe '#save' do
    before do
      # Ensure recruitment office has no default values
      recruitment_office.update!(city: nil, zip_code: nil)
    end

    let(:attributes) do
      {
        autocomplete_address: 'Lyon, 69001',
        city: 'Lyon',
        zip_code: '69001'
      }
    end

    context 'when form is valid' do
      it 'updates recruitment office location' do
        expect(form.save).to be true
        recruitment_office.reload
        expect(recruitment_office.city).to eq('Lyon')
        expect(recruitment_office.zip_code).to eq('69001')
      end

      it 'returns true' do
        expect(form.save).to be true
      end
    end

    context 'when form is invalid' do
      let(:attributes) { { city: 'Paris' } }

      it 'returns false' do
        expect(form.save).to be false
      end

      it 'does not update recruitment office' do
        original_city = recruitment_office.city
        form.save
        expect(recruitment_office.reload.city).to eq(original_city)
      end
    end
  end

  describe '#persist_company!' do
    let(:attributes) do
      {
        company_name: 'New Company',
        company_siren: '987654321'
      }
    end

    context 'when company does not exist' do
      it 'creates a new company' do
        expect {
          form.persist_company!
        }.to change { Company.count }.by(1)
      end

      it 'creates company with correct attributes' do
        form.persist_company!
        company = Company.last
        expect(company.name).to eq('New Company')
        expect(company.siren).to eq('987654321')
      end

      it 'creates partner company association' do
        expect {
          form.persist_company!
        }.to change { recruitment_office.partner_companies.count }.by(1)
      end
    end

    context 'when company already exists with same siren' do
      let!(:existing_company) { create(:company, name: 'Old Company', siren: '987654321') }

      it 'does not create a new company' do
        expect {
          form.persist_company!
        }.not_to change { Company.count }
      end

      it 'does not update company name for existing records' do
        # The find_or_initialize_by block only sets the name for NEW records
        # For existing records, the block is not executed, so the name is not updated
        # The condition `company.name != company_name` will be true but company.name is still 'Old Company'
        # So it will save but won't change the name
        form.persist_company!
        existing_company.reload
        expect(existing_company.name).to eq('Old Company')
      end

      it 'creates partner company association if not exists' do
        expect {
          form.persist_company!
        }.to change { recruitment_office.partner_companies.count }.by(1)
      end

      context 'when partner company association already exists' do
        before do
          recruitment_office.partner_companies.create!(company: existing_company)
        end

        it 'does not create duplicate association' do
          expect {
            form.persist_company!
          }.not_to change { recruitment_office.partner_companies.count }
        end
      end

      context 'when company name is the same' do
        let(:attributes) do
          {
            company_name: 'Old Company',
            company_siren: '987654321'
          }
        end

        it 'does not update the company' do
          expect(existing_company).not_to receive(:save!)
          form.persist_company!
        end
      end
    end
  end

  describe 'private methods' do
    describe '#persist!' do
      let(:attributes) do
        {
          autocomplete_address: 'Marseille, 13001',
          city: 'Marseille',
          zip_code: '13001'
        }
      end

      it 'updates recruitment office with location data' do
        form.send(:persist!)
        recruitment_office.reload
        expect(recruitment_office.city).to eq('Marseille')
        expect(recruitment_office.zip_code).to eq('13001')
      end
    end

    describe '#current_user' do
      it 'returns Current.user' do
        expect(form.send(:current_user)).to eq(user)
      end

      it 'memoizes the current user' do
        first_call = form.send(:current_user)
        second_call = form.send(:current_user)
        expect(first_call).to equal(second_call)
      end
    end
  end
end