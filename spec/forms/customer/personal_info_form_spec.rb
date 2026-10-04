require 'rails_helper'

RSpec.describe Customer::PersonalInfoForm do
  let(:user) { create(:user, :customer, first_name: 'Jane', last_name: 'Smith') }
  let(:form) { described_class.new(attributes) }
  let(:attributes) { {} }

  before do
    allow(Current).to receive(:user).and_return(user)
  end

  describe '#initialize' do
    it 'sets current user as customer' do
      expect(form.instance_variable_get(:@customer)).to eq(user)
    end

    it 'initializes with empty attributes' do
      form = described_class.new
      expect(form.instance_variable_get(:@customer)).to eq(user)
    end

    it 'initializes with provided attributes' do
      form = described_class.new(first_name: 'John', last_name: 'Doe')
      expect(form.first_name).to eq('John')
      expect(form.last_name).to eq('Doe')
    end
  end

  describe 'validations' do
    describe 'presence validations' do
      it 'requires first_name' do
        form = described_class.new(last_name: 'Doe', phone_number: '+1234567890')
        expect(form).not_to be_valid
        expect(form.errors[:first_name]).to include("doit être rempli(e)")
      end

      it 'requires last_name' do
        form = described_class.new(first_name: 'John', phone_number: '+1234567890')
        expect(form).not_to be_valid
        expect(form.errors[:last_name]).to include("doit être rempli(e)")
      end

      it 'requires phone_number' do
        form = described_class.new(first_name: 'John', last_name: 'Doe')
        expect(form).not_to be_valid
        expect(form.errors[:phone_number]).to include("doit être rempli(e)")
      end

      it 'does not require job_title' do
        form = described_class.new(
          first_name: 'John',
          last_name: 'Doe',
          phone_number: '+1234567890'
        )
        expect(form).to be_valid
      end
    end

    describe 'valid form' do
      it 'is valid with all required fields' do
        form = described_class.new(
          first_name: 'John',
          last_name: 'Doe',
          phone_number: '+1234567890',
          job_title: 'Manager'
        )
        expect(form).to be_valid
      end
    end
  end

  describe '#save' do
    context 'when form is valid' do
      let(:valid_attributes) do
        {
          first_name: 'John',
          last_name: 'Doe',
          phone_number: '+33612345678',
          job_title: 'Product Manager'
        }
      end

      it 'updates the current user' do
        form = described_class.new(valid_attributes)
        expect(form.save).to be true
        
        user.reload
        expect(user.first_name).to eq('John')
        expect(user.last_name).to eq('Doe')
        expect(user.phone_number).to eq('+33612345678')
        expect(user.job_title).to eq('Product Manager')
      end

      it 'returns true' do
        form = described_class.new(valid_attributes)
        expect(form.save).to be true
      end

      context 'with minimal attributes' do
        let(:minimal_attributes) do
          {
            first_name: 'Alice',
            last_name: 'Johnson',
            phone_number: '+1555123456'
          }
        end

        it 'updates user with minimal data' do
          form = described_class.new(minimal_attributes)
          expect(form.save).to be true
          
          user.reload
          expect(user.first_name).to eq('Alice')
          expect(user.last_name).to eq('Johnson')
          expect(user.phone_number).to eq('+1555123456')
        end
      end

      context 'updating existing user attributes' do
        it 'updates only provided attributes' do
          original_email = user.email
          form = described_class.new(
            first_name: 'Updated',
            last_name: 'Name',
            phone_number: '+33600000000'
          )
          
          expect(form.save).to be true
          
          user.reload
          expect(user.email).to eq(original_email) # Email should not change
          expect(user.first_name).to eq('Updated')
        end
      end
    end

    context 'when form is invalid' do
      let(:invalid_attributes) do
        {
          first_name: '',
          last_name: '',
          phone_number: ''
        }
      end

      it 'does not update user' do
        original_first_name = user.first_name
        form = described_class.new(invalid_attributes)
        
        expect(form.save).to be false
        expect(user.reload.first_name).to eq(original_first_name)
      end

      it 'returns false' do
        form = described_class.new(invalid_attributes)
        expect(form.save).to be false
      end

      it 'populates errors' do
        form = described_class.new(invalid_attributes)
        form.save
        
        expect(form.errors[:first_name]).to be_present
        expect(form.errors[:last_name]).to be_present
        expect(form.errors[:phone_number]).to be_present
      end
    end
  end

  describe 'private methods' do
    describe '#persist!' do
      let(:attributes) do
        {
          first_name: 'Test',
          last_name: 'User',
          phone_number: '+33699999999',
          job_title: 'CTO'
        }
      end

      it 'assigns attributes to current user' do
        form = described_class.new(attributes)
        
        # BaseForm converts attributes to ActiveSupport::HashWithIndifferentAccess, which uses string keys
        expect(user).to receive(:assign_attributes).with(hash_including(
          "first_name" => "Test",
          "last_name" => "User",
          "phone_number" => "+33699999999",
          "job_title" => "CTO"
        ))
        expect(user).to receive(:save!)
        
        form.send(:persist!)
      end

      it 'updates the user' do
        form = described_class.new(attributes)
        form.send(:persist!)
        
        user.reload
        expect(user.first_name).to eq('Test')
        expect(user.last_name).to eq('User')
        expect(user.phone_number).to eq('+33699999999')
        expect(user.job_title).to eq('CTO')
      end

      it 'raises error if save fails' do
        form = described_class.new(attributes)
        
        allow(user).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(user))
        
        expect {
          form.send(:persist!)
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    describe '#current_user' do
      it 'returns Current.user' do
        form = described_class.new
        expect(form.send(:current_user)).to eq(user)
      end

      it 'memoizes the current user' do
        form = described_class.new
        
        # Call it twice to ensure memoization
        first_call = form.send(:current_user)
        second_call = form.send(:current_user)
        
        expect(first_call).to eq(second_call)
        expect(Current).to have_received(:user).once
      end
    end
  end

  describe 'edge cases' do
    describe 'nil and empty values' do
      it 'handles nil job_title' do
        form = described_class.new(
          first_name: 'John',
          last_name: 'Doe',
          phone_number: '+33612345678',
          job_title: nil
        )
        
        expect(form).to be_valid
        form.save
        
        expect(user.reload.job_title).to be_nil
      end

      it 'handles empty string job_title' do
        form = described_class.new(
          first_name: 'John',
          last_name: 'Doe',
          phone_number: '+33612345678',
          job_title: ''
        )
        
        expect(form).to be_valid
        form.save
        
        expect(user.reload.job_title).to eq('')
      end
    end

    describe 'special characters in names' do
      it 'accepts names with hyphens' do
        form = described_class.new(
          first_name: 'Jean-Claude',
          last_name: 'Van-Damme',
          phone_number: '+33612345678'
        )
        
        expect(form).to be_valid
        form.save
        
        user.reload
        expect(user.first_name).to eq('Jean-Claude')
        expect(user.last_name).to eq('Van-Damme')
      end

      it 'accepts names with apostrophes' do
        form = described_class.new(
          first_name: "D'Angelo",
          last_name: "O'Brien",
          phone_number: '+33612345678'
        )
        
        expect(form).to be_valid
        form.save
        
        user.reload
        expect(user.first_name).to eq("D'Angelo")
        expect(user.last_name).to eq("O'Brien")
      end
    end

    describe 'phone number formats' do
      it 'accepts various phone number formats' do
        test_cases = [
          '+33612345678',
          '+1-555-123-4567',
          '0612345678',
          '06 12 34 56 78'
        ]
        
        test_cases.each do |phone|
          form = described_class.new(
            first_name: 'Test',
            last_name: 'User',
            phone_number: phone
          )
          
          expect(form).to be_valid, "Expected phone number '#{phone}' to be valid"
        end
      end
    end
  end

  describe 'model_class' do
    it 'is set to User' do
      expect(described_class.model_class).to eq(User)
    end
  end

  describe 'Current.user not set' do
    before do
      allow(Current).to receive(:user).and_return(nil)
    end

    it 'handles nil current user gracefully' do
      expect {
        described_class.new
      }.not_to raise_error
    end
  end
end