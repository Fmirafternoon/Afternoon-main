require 'rails_helper'

RSpec.describe Candidate::PersonalInfoForm do
  let(:candidate) { create(:candidate) }
  let(:form) { described_class.new(attributes) }
  let(:attributes) { { id: candidate.id } }

  describe '#initialize' do
    context 'with existing candidate' do
      it 'finds the candidate by id' do
        expect(form.instance_variable_get(:@candidate)).to eq(candidate)
      end

      it 'handles indifferent access for id' do
        form = described_class.new('id' => candidate.id)
        expect(form.instance_variable_get(:@candidate)).to eq(candidate)
      end

      context 'when candidate has location' do
        let(:location) { create(:location, address: '123 Main St', city: 'Paris', zip_code: '75001') }
        
        before do
          candidate.update!(location: location)
        end

        it 'sets autocomplete_address from candidate location' do
          form = described_class.new(id: candidate.id)
          expect(form.autocomplete_address).to eq(location.full_address)
        end
      end

      context 'when candidate has no location' do
        it 'does not set autocomplete_address' do
          form = described_class.new(id: candidate.id)
          expect(form.autocomplete_address).to be_nil
        end
      end
    end

    context 'with new candidate' do
      it 'initializes a new candidate' do
        form = described_class.new({})
        expect(form.instance_variable_get(:@candidate)).to be_a(Candidate)
        expect(form.instance_variable_get(:@candidate)).to be_new_record
      end
    end
  end

  describe 'validations' do
    describe 'email validation' do
      it 'accepts valid email' do
        form = described_class.new(id: candidate.id, email: 'test@example.com')
        form.valid?
        expect(form.errors[:email]).to be_empty
      end

      it 'rejects invalid email' do
        form = described_class.new(id: candidate.id, email: 'invalid-email')
        form.valid?
        expect(form.errors[:email]).to include("n'est pas valide")
      end

      it 'allows blank email' do
        form = described_class.new(id: candidate.id, email: '')
        form.valid?
        expect(form.errors[:email]).to be_empty
      end

      it 'allows nil email' do
        form = described_class.new(id: candidate.id, email: nil)
        form.valid?
        expect(form.errors[:email]).to be_empty
      end
    end

    describe 'gender validation' do
      it 'accepts male' do
        form = described_class.new(id: candidate.id, gender: 'male')
        form.valid?
        expect(form.errors[:gender]).to be_empty
      end

      it 'accepts female' do
        form = described_class.new(id: candidate.id, gender: 'female')
        form.valid?
        expect(form.errors[:gender]).to be_empty
      end

      it 'rejects invalid gender' do
        form = described_class.new(id: candidate.id, gender: 'other')
        form.valid?
        expect(form.errors[:gender]).to include("n'est pas inclus(e) dans la liste")
      end

      it 'allows blank gender' do
        form = described_class.new(id: candidate.id, gender: '')
        form.valid?
        expect(form.errors[:gender]).to be_empty
      end
    end

    describe 'birth_year validation' do
      let(:current_year) { Date.today.year }

      it 'accepts valid birth year' do
        form = described_class.new(id: candidate.id, birth_year: 1990)
        form.valid?
        expect(form.errors[:birth_year]).to be_empty
      end

      it 'rejects birth year before 1940' do
        form = described_class.new(id: candidate.id, birth_year: 1939)
        form.valid?
        expect(form.errors[:birth_year]).to include("doit être supérieur ou égal à 1940")
      end

      it 'rejects birth year for age less than 15' do
        form = described_class.new(id: candidate.id, birth_year: current_year - 14)
        form.valid?
        expect(form.errors[:birth_year]).to include("doit être inférieur ou égal à #{current_year - 15}")
      end

      it 'accepts birth year for exactly 15 years old' do
        form = described_class.new(id: candidate.id, birth_year: current_year - 15)
        form.valid?
        expect(form.errors[:birth_year]).to be_empty
      end

      it 'allows blank birth year' do
        form = described_class.new(id: candidate.id, birth_year: nil)
        form.valid?
        expect(form.errors[:birth_year]).to be_empty
      end
    end

    describe 'autocomplete_address validation' do
      it 'requires autocomplete_address' do
        form = described_class.new(id: candidate.id)
        expect(form).not_to be_valid
        expect(form.errors[:autocomplete_address]).to include("Veuillez sélectionner au moins une ville dans la liste des suggestions")
      end

      it 'is valid with autocomplete_address' do
        form = described_class.new(id: candidate.id, autocomplete_address: '123 Main St')
        expect(form).to be_valid
      end
    end
  end

  describe '#save' do
    let(:user) { create(:user, :agent_user) }
    
    before do
      Current.user = user
    end

    after do
      Current.user = nil
    end

    context 'when form is valid' do
      let(:valid_attributes) do
        {
          id: candidate.id,
          first_name: 'John',
          last_name: 'Doe',
          email: 'john@example.com',
          phone_number: '+33612345678',
          gender: 'male',
          birth_year: 1990,
          autocomplete_address: '123 Main St, Paris'
        }
      end

      it 'updates the candidate' do
        form = described_class.new(valid_attributes)
        expect(form.save).to be true
        
        candidate.reload
        expect(candidate.first_name).to eq('John')
        expect(candidate.last_name).to eq('Doe')
        expect(candidate.email).to eq('john@example.com')
        expect(candidate.phone_number).to eq('+33612345678')
        expect(candidate.gender).to eq('male')
        expect(candidate.birth_year).to eq(1990)
      end

      context 'with location data' do
        let(:location_attributes) do
          valid_attributes.merge(
            address: '123 Main St',
            city: 'Paris',
            zip_code: '75001',
            lat: 48.8566,
            lng: 2.3522
          )
        end

        it 'creates or updates location' do
          form = described_class.new(location_attributes)
          
          expect {
            form.save
          }.to change { Location.count }.by(1)
          
          candidate.reload
          expect(candidate.location).to be_present
          expect(candidate.location.address).to eq('123 Main St')
          expect(candidate.location.city).to eq('Paris')
          expect(candidate.location.zip_code).to eq('75001')
          expect(candidate.location.latitude).to eq(48.8566)
          expect(candidate.location.longitude).to eq(2.3522)
        end

        context 'when location already exists' do
          let!(:existing_location) do
            create(:location, 
              address: '123 Main St',
              city: 'Paris',
              zip_code: '75001',
              latitude: 48.8566,
              longitude: 2.3522
            )
          end

          it 'uses existing location' do
            form = described_class.new(location_attributes)
            
            expect {
              form.save
            }.not_to change { Location.count }
            
            candidate.reload
            expect(candidate.location).to eq(existing_location)
          end
        end
      end

      it 'returns true' do
        form = described_class.new(valid_attributes)
        expect(form.save).to be true
      end
    end

    context 'when creating new candidate' do
      let(:new_attributes) do
        {
          first_name: 'Jane',
          last_name: 'Smith',
          email: 'jane@example.com',
          autocomplete_address: '456 Oak St'
        }
      end

      it 'creates a new candidate for current user' do
        form = described_class.new(new_attributes)
        
        expect {
          form.save
        }.to change { Candidate.count }.by(1)
        
        new_candidate = Candidate.last
        expect(new_candidate.agent).to eq(user)
        expect(new_candidate.first_name).to eq('Jane')
        expect(new_candidate.last_name).to eq('Smith')
      end

      it 'sets the id after saving' do
        form = described_class.new(new_attributes)
        form.save
        
        expect(form.id).to be_present
        expect(form.id).to eq(Candidate.last.id)
      end
    end

    context 'when form is invalid' do
      let(:invalid_attributes) do
        {
          id: candidate.id,
          email: 'invalid-email'
        }
      end

      it 'returns false' do
        form = described_class.new(invalid_attributes)
        expect(form.save).to be false
      end

      it 'does not update the candidate' do
        original_email = candidate.email
        form = described_class.new(invalid_attributes)
        form.save
        
        expect(candidate.reload.email).to eq(original_email)
      end
    end
  end

  describe 'private methods' do
    describe '#persist!' do
      let(:user) { create(:user, :agent_user) }
      
      before do
        Current.user = user
      end

      after do
        Current.user = nil
      end

      context 'with existing candidate' do
        let(:attributes) do
          {
            id: candidate.id,
            first_name: 'Updated',
            last_name: 'Name',
            autocomplete_address: 'Some address'
          }
        end

        it 'updates the existing candidate' do
          form = described_class.new(attributes)
          form.send(:persist!)
          
          candidate.reload
          expect(candidate.first_name).to eq('Updated')
          expect(candidate.last_name).to eq('Name')
        end

        it 'excludes location-related attributes from assignment' do
          location_attrs = attributes.merge(
            address: '123 Main St',
            city: 'Paris',
            zip_code: '75001',
            lat: 48.8566,
            lng: 2.3522
          )
          
          form = described_class.new(location_attrs)
          form.send(:persist!)
          
          # These attributes should not be on the candidate model
          expect(candidate).not_to respond_to(:autocomplete_address)
          expect(candidate).not_to respond_to(:lat)
          expect(candidate).not_to respond_to(:lng)
        end
      end

      context 'without id' do
        let(:attributes) do
          {
            first_name: 'New',
            last_name: 'Candidate',
            autocomplete_address: 'Some address'
          }
        end

        it 'creates a new candidate' do
          form = described_class.new(attributes)
          
          expect {
            form.send(:persist!)
          }.to change { Candidate.count }.by(1)
        end

        it 'assigns to current user' do
          form = described_class.new(attributes)
          form.send(:persist!)
          
          new_candidate = Candidate.last
          expect(new_candidate.agent).to eq(user)
        end

        it 'sets the form id' do
          form = described_class.new(attributes)
          form.send(:persist!)
          
          expect(form.id).to eq(Candidate.last.id)
        end
      end

      context 'with address data' do
        let(:attributes) do
          {
            id: candidate.id,
            address: '789 Elm St',
            city: 'Lyon',
            zip_code: '69001',
            lat: 45.7640,
            lng: 4.8357,
            autocomplete_address: '789 Elm St, Lyon'
          }
        end

        it 'creates or finds location' do
          form = described_class.new(attributes)
          
          expect {
            form.send(:persist!)
          }.to change { Location.count }.by(1)
          
          location = Location.last
          expect(location.address).to eq('789 Elm St')
          expect(location.city).to eq('Lyon')
        end

        it 'assigns location to candidate' do
          form = described_class.new(attributes)
          form.send(:persist!)
          
          candidate.reload
          expect(candidate.location).to be_present
          expect(candidate.location.address).to eq('789 Elm St')
        end
      end

      context 'without address data' do
        let(:attributes) do
          {
            id: candidate.id,
            first_name: 'No',
            last_name: 'Address',
            autocomplete_address: 'Something'
          }
        end

        it 'does not create location' do
          form = described_class.new(attributes)
          
          expect {
            form.send(:persist!)
          }.not_to change { Location.count }
        end

        it 'does not assign location' do
          form = described_class.new(attributes)
          form.send(:persist!)
          
          candidate.reload
          expect(candidate.location).to be_nil
        end
      end
    end

    describe '#autocomplete_address_presence' do
      it 'adds error when autocomplete_address is blank' do
        form = described_class.new(id: candidate.id, autocomplete_address: '')
        form.send(:autocomplete_address_presence)
        expect(form.errors[:autocomplete_address]).to include("Veuillez sélectionner au moins une ville dans la liste des suggestions")
      end

      it 'adds error when autocomplete_address is nil' do
        form = described_class.new(id: candidate.id, autocomplete_address: nil)
        form.send(:autocomplete_address_presence)
        expect(form.errors[:autocomplete_address]).to include("Veuillez sélectionner au moins une ville dans la liste des suggestions")
      end

      it 'does not add error when autocomplete_address is present' do
        form = described_class.new(id: candidate.id, autocomplete_address: '123 Main St')
        form.send(:autocomplete_address_presence)
        expect(form.errors[:autocomplete_address]).to be_empty
      end
    end
  end

  describe 'edge cases' do
    it 'handles find_or_initialize_by correctly' do
      # With nil id
      form = described_class.new(id: nil)
      expect(form.instance_variable_get(:@candidate)).to be_new_record
      
      # With non-existent id
      form = described_class.new(id: 999999)
      expect(form.instance_variable_get(:@candidate)).to be_new_record
      
      # With existing id
      form = described_class.new(id: candidate.id)
      expect(form.instance_variable_get(:@candidate)).to eq(candidate)
    end
  end
end