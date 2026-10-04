require 'rails_helper'

RSpec.describe Agent::PersonalInfoForm do
  let(:agent_user) { create(:user, :agent_user) }
  let(:form) { described_class.new(attributes) }
  let(:attributes) { {} }

  before do
    Current.user = agent_user
  end

  after do
    Current.user = nil
  end

  describe '#initialize' do
    it 'sets @agent to current user' do
      expect(form.instance_variable_get(:@agent)).to eq(agent_user)
    end

    it 'initializes with provided attributes' do
      form = described_class.new(
        first_name: 'John',
        last_name: 'Doe',
        phone_number: '+33612345678'
      )
      expect(form.first_name).to eq('John')
      expect(form.last_name).to eq('Doe')
      expect(form.phone_number).to eq('+33612345678')
    end

    it 'handles nil attributes' do
      form = described_class.new(nil)
      expect(form.instance_variable_get(:@agent)).to eq(agent_user)
    end
  end

  describe 'validations' do
    describe 'presence validations' do
      it 'requires first_name' do
        form = described_class.new(last_name: 'Doe')
        expect(form).not_to be_valid
        expect(form.errors[:first_name]).to include("doit être rempli(e)")
      end

      it 'requires last_name' do
        form = described_class.new(first_name: 'John')
        expect(form).not_to be_valid
        expect(form.errors[:last_name]).to include("doit être rempli(e)")
      end

      it 'is valid with required fields' do
        form = described_class.new(first_name: 'John', last_name: 'Doe')
        expect(form).to be_valid
      end

      it 'does not require phone_number' do
        form = described_class.new(first_name: 'John', last_name: 'Doe')
        expect(form).to be_valid
      end

      it 'does not require avatar_url' do
        form = described_class.new(first_name: 'John', last_name: 'Doe')
        expect(form).to be_valid
      end

      it 'does not require description' do
        form = described_class.new(first_name: 'John', last_name: 'Doe')
        expect(form).to be_valid
      end
    end
  end

  describe '#save' do
    context 'when form is valid' do
      let(:valid_attributes) do
        {
          first_name: 'Updated',
          last_name: 'Agent',
          phone_number: '+33698765432',
          description: 'Experienced agent'
        }
      end

      it 'updates the current user' do
        form = described_class.new(valid_attributes)
        expect(form.save).to be true
        
        agent_user.reload
        expect(agent_user.first_name).to eq('Updated')
        expect(agent_user.last_name).to eq('Agent')
        expect(agent_user.phone_number).to eq('+33698765432')
        expect(agent_user.description).to eq('Experienced agent')
      end

      it 'returns true' do
        form = described_class.new(valid_attributes)
        expect(form.save).to be true
      end

      context 'with avatar_url' do
        let(:avatar_attributes) do
          valid_attributes.merge(
            avatar_url: 'https://res.cloudinary.com/test/image/upload/v123/avatar.jpg'
          )
        end

        it 'updates avatar_url' do
          form = described_class.new(avatar_attributes)
          form.save
          
          expect(agent_user.reload.avatar_url).to eq('https://res.cloudinary.com/test/image/upload/v123/avatar.jpg')
        end
      end

      context 'with avatar_url_file' do
        let(:file_attributes) do
          valid_attributes.merge(
            avatar_url: 'https://res.cloudinary.com/test/image/upload/v123/avatar.jpg',
            avatar_url_file: 'some_file_data'
          )
        end

        it 'ignores avatar_url_file and uses avatar_url' do
          form = described_class.new(file_attributes)
          form.save
          
          expect(agent_user.reload.avatar_url).to eq('https://res.cloudinary.com/test/image/upload/v123/avatar.jpg')
          # avatar_url_file should not be a user attribute
          expect(agent_user).not_to respond_to(:avatar_url_file)
        end
      end
    end

    context 'when form is invalid' do
      let(:invalid_attributes) do
        {
          first_name: '',
          last_name: 'Agent'
        }
      end

      it 'returns false' do
        form = described_class.new(invalid_attributes)
        expect(form.save).to be false
      end

      it 'does not update the user' do
        original_first_name = agent_user.first_name
        form = described_class.new(invalid_attributes)
        form.save
        
        expect(agent_user.reload.first_name).to eq(original_first_name)
      end

      it 'populates errors' do
        form = described_class.new(invalid_attributes)
        form.save
        expect(form.errors[:first_name]).to be_present
      end
    end
  end

  describe 'private methods' do
    describe '#persist!' do
      let(:attributes) do
        {
          first_name: 'New',
          last_name: 'Name',
          phone_number: '+33611111111',
          avatar_url: 'https://example.com/avatar.jpg',
          avatar_url_file: 'should_be_removed',
          description: 'Test description'
        }
      end

      it 'assigns attributes to current user' do
        form = described_class.new(attributes)
        
        expect(agent_user).to receive(:assign_attributes).with(
          hash_including(
            'first_name' => 'New',
            'last_name' => 'Name',
            'phone_number' => '+33611111111',
            'avatar_url' => 'https://example.com/avatar.jpg',
            'description' => 'Test description'
          )
        )
        expect(agent_user).to receive(:save!)
        
        form.send(:persist!)
      end

      it 'removes avatar_url_file from attributes' do
        form = described_class.new(attributes)
        
        expect(agent_user).to receive(:assign_attributes) do |attrs|
          expect(attrs.keys).not_to include('avatar_url_file')
        end
        expect(agent_user).to receive(:save!)
        
        form.send(:persist!)
      end

      it 'handles indifferent access' do
        form = described_class.new(attributes)
        
        # Should work with both string and symbol keys
        expect(agent_user).to receive(:assign_attributes) do |attrs|
          expect(attrs['first_name']).to eq('New')
          expect(attrs[:first_name]).to eq('New')
        end
        expect(agent_user).to receive(:save!)
        
        form.send(:persist!)
      end
    end

    describe '#current_user' do
      it 'returns Current.user' do
        expect(form.send(:current_user)).to eq(agent_user)
      end

      it 'memoizes the current user' do
        first_call = form.send(:current_user)
        second_call = form.send(:current_user)
        expect(first_call).to equal(second_call)
      end
    end
  end

  describe 'edge cases' do
    describe 'without Current.user' do
      before do
        Current.user = nil
      end

      it 'handles missing current user gracefully' do
        expect { described_class.new }.not_to raise_error
      end
    end

    describe 'attribute handling' do
      it 'handles all attribute types' do
        form = described_class.new(
          first_name: 'String',
          last_name: 'Values',
          phone_number: nil,
          avatar_url: '',
          avatar_url_file: 'ignored',
          description: nil
        )
        
        expect(form.first_name).to eq('String')
        expect(form.last_name).to eq('Values')
        expect(form.phone_number).to be_nil
        expect(form.avatar_url).to eq('')
        expect(form.avatar_url_file).to eq('ignored')
        expect(form.description).to be_nil
      end
    end
  end
end