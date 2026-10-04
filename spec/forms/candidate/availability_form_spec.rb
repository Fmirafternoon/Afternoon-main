require 'rails_helper'

RSpec.describe Candidate::AvailabilityForm do
  let(:candidate) { create(:candidate) }
  let(:form) { described_class.new(attributes) }
  let(:attributes) { { id: candidate.id } }

  describe '#initialize' do
    it 'finds the candidate by id' do
      expect(form.instance_variable_get(:@candidate)).to eq(candidate)
    end

    it 'handles indifferent access for id' do
      form = described_class.new('id' => candidate.id)
      expect(form.instance_variable_get(:@candidate)).to eq(candidate)
    end

    it 'raises error when candidate not found' do
      expect {
        described_class.new(id: 999999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '#availability_notices_list' do
    it 'returns humanized availability notices' do
      allow(Candidate).to receive(:availability_notices).and_return(
        { 'immediate' => 0, 'one_month' => 1, 'two_months' => 2 }
      )
      allow(Candidate).to receive(:human_enum_name).with("availability_notices", 'immediate').and_return("Immédiate")
      allow(Candidate).to receive(:human_enum_name).with("availability_notices", 'one_month').and_return("1 mois")
      allow(Candidate).to receive(:human_enum_name).with("availability_notices", 'two_months').and_return("2 mois")

      expect(form.availability_notices_list).to eq([
        ["Immédiate", "immediate"],
        ["1 mois", "one_month"],
        ["2 mois", "two_months"]
      ])
    end
  end

  describe '#contract_types_list' do
    it 'returns humanized contract types' do
      allow(Candidate).to receive(:contract_types).and_return(
        { 'cdi' => 0, 'cdd' => 1, 'freelance' => 2 }
      )
      allow(Candidate).to receive(:human_enum_name).with("contract_types", 'cdi').and_return("CDI")
      allow(Candidate).to receive(:human_enum_name).with("contract_types", 'cdd').and_return("CDD")
      allow(Candidate).to receive(:human_enum_name).with("contract_types", 'freelance').and_return("Freelance")

      expect(form.contract_types_list).to eq([
        ["CDI", "cdi"],
        ["CDD", "cdd"],
        ["Freelance", "freelance"]
      ])
    end
  end

  describe 'validations' do
    context 'when autocomplete_address is present' do
      let(:attributes) do
        {
          id: candidate.id,
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

      it 'does not require availability_notice, contract_type, or salary_expectation' do
        form.zip_code = '75001'
        form.city = 'Paris'
        expect(form).to be_valid
      end
    end

    context 'when autocomplete_address is blank' do
      let(:attributes) { { id: candidate.id } }

      it 'does not require availability_notice' do
        form.contract_type = 'cdi'
        form.salary_expectation = 50000
        form.valid?
        expect(form.errors[:availability_notice]).to be_empty
      end

      it 'requires contract_type' do
        form.availability_notice = 'immediate'
        form.salary_expectation = 50000
        expect(form).not_to be_valid
        expect(form.errors[:contract_type]).to include("doit être rempli(e)")
      end

      it 'does not require salary_expectation' do
        form.availability_notice = 'immediate'
        form.contract_type = 'cdi'
        form.valid?
        expect(form.errors[:salary_expectation]).to be_empty
      end

      it 'validates at_least_one_mobility when candidate has no locations' do
        form.availability_notice = 'immediate'
        form.contract_type = 'cdi'
        form.salary_expectation = 50000
        expect(form).not_to be_valid
        expect(form.errors[:base]).to include("Veuillez renseigner au moins une mobilité")
      end

      it 'is valid when candidate already has locations' do
        candidate.locations << create(:location)
        form.availability_notice = 'immediate'
        form.contract_type = 'cdi'
        form.salary_expectation = 50000
        expect(form).to be_valid
      end
    end
  end

  describe '#save' do
    context 'when form is valid' do
      context 'with basic attributes' do
        let(:attributes) do
          {
            id: candidate.id,
            availability_notice: 'immediate',
            contract_type: 'cdi',
            salary_expectation: 50000,
            has_driving_license: true,
            has_a_car: false
          }
        end

        before do
          candidate.locations << create(:location) # To satisfy at_least_one_mobility
        end

        it 'updates the candidate' do
          expect(form.save).to be true
          candidate.reload
          expect(candidate.availability_notice).to eq('immediate')
          expect(candidate.contract_type).to eq('cdi')
          expect(candidate.salary_expectation).to eq(50000)
          expect(candidate.has_driving_license).to be true
          expect(candidate.has_a_car).to be false
        end

        it 'returns true' do
          expect(form.save).to be true
        end
      end

      context 'with location data' do
        let(:attributes) do
          {
            id: candidate.id,
            autocomplete_address: '123 Main St, Paris',
            lat: '48.8566',
            lng: '2.3522',
            zip_code: '75001',
            city: 'Paris'
          }
        end

        it 'does not require other validations' do
          expect(form).to be_valid
          expect(form.save).to be true
        end
      end
    end

    context 'when form is invalid' do
      let(:attributes) { { id: candidate.id } }

      it 'returns false' do
        expect(form.save).to be false
      end

      it 'does not update the candidate' do
        original_notice = candidate.availability_notice
        form.save
        expect(candidate.reload.availability_notice).to eq(original_notice)
      end
    end

    context 'when creating a new candidate through persist!' do
      # Since initialize always requires an existing candidate,
      # we can't test new candidate creation through the form's public interface.
      # The persist! method handles it internally, but we'd need to refactor
      # the initialize method to properly support this use case.
    end
  end

  describe '#persist_location!' do
    context 'with valid location data' do
      let(:attributes) do
        {
          id: candidate.id,
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
        form.persist_location!
        location = Location.last
        expect(location.latitude).to eq(48.8566)
        expect(location.longitude).to eq(2.3522)
        expect(location.zip_code).to eq('75001')
        expect(location.city).to eq('Paris')
      end

      it 'adds location to candidate' do
        expect {
          form.persist_location!
        }.to change { candidate.locations.count }.by(1)
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

        it 'adds existing location to candidate' do
          form.persist_location!
          expect(candidate.locations).to include(existing_location)
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
          id: candidate.id,
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
          id: candidate.id,
          autocomplete_address: '123 Main St',
          lat: '48.8566',
          lng: '2.3522'
        }
      end

      it 'returns nil' do
        expect(form.persist_location!).to be_nil
      end
    end
  end

  describe 'private methods' do
    describe '#at_least_one_mobility' do
      it 'adds error when candidate has no locations' do
        form.send(:at_least_one_mobility)
        expect(form.errors[:base]).to include("Veuillez renseigner au moins une mobilité")
      end

      it 'does not add error when candidate has locations' do
        candidate.locations << create(:location)
        form.send(:at_least_one_mobility)
        expect(form.errors[:base]).to be_empty
      end
    end

    describe '#persist!' do
      context 'with existing candidate' do
        let(:attributes) do
          {
            id: candidate.id,
            availability_notice: 'immediate',
            contract_type: 'cdi',
            salary_expectation: 50000
          }
        end

        it 'updates the existing candidate' do
          form.send(:persist!)
          candidate.reload
          expect(candidate.availability_notice).to eq('immediate')
          expect(candidate.contract_type).to eq('cdi')
          expect(candidate.salary_expectation).to eq(50000)
        end

        it 'excludes location attributes' do
          form.autocomplete_address = '123 Main St'
          form.lat = '48.8566'
          form.lng = '2.3522'
          form.city = 'Paris'
          form.zip_code = '75001'
          
          form.send(:persist!)
          candidate.reload
          # These attributes should not be on the candidate model
          expect(candidate).not_to respond_to(:autocomplete_address)
          expect(candidate).not_to respond_to(:lat)
        end
      end

      context 'without existing candidate id in persist!' do
        # The persist! method can handle creating new candidates internally,
        # but since the initialize method requires an id, we test this indirectly
        
        it 'can create a new candidate when form.id is nil' do
          user = create(:user, :agent_user)
          Current.user = user
          
          # Create form with existing candidate, then nil out the id
          test_form = described_class.new(id: candidate.id)
          test_form.id = nil
          test_form.availability_notice = 'immediate'
          test_form.contract_type = 'cdi'
          test_form.salary_expectation = 50000
          
          expect {
            test_form.send(:persist!)
          }.to change { Candidate.count }.by(1)
          
          new_candidate = Candidate.last
          expect(new_candidate.agent).to eq(user)
          expect(new_candidate.availability_notice).to eq('immediate')
          expect(test_form.id).to eq(new_candidate.id)
          
          Current.user = nil
        end
      end
    end
  end
end