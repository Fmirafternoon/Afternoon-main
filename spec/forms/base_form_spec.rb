require 'rails_helper'

RSpec.describe BaseForm do
  # Create a test form class that inherits from BaseForm
  let(:test_form_class) do
    stub_const('TestForm', Class.new(BaseForm) do
      attribute :name, :string
      attribute :from_month, :integer
      attribute :from_year, :integer
      attribute :to_month, :integer
      attribute :to_year, :integer
      
      validates :name, presence: true
      
      self.model_class = OpenStruct
      
      private
      
      def persist!
        # Implementation for testing
        @persisted = true
      end
      
      def persisted?
        @persisted || false
      end
    end)
  end
  
  let(:form) { test_form_class.new(attributes) }
  let(:attributes) { {} }

  describe 'included modules' do
    it 'includes ActiveModel modules' do
      expect(test_form_class.ancestors).to include(ActiveModel::Model)
      expect(test_form_class.ancestors).to include(ActiveModel::Attributes)
      expect(test_form_class.ancestors).to include(ActiveModel::Validations)
      expect(test_form_class.ancestors).to include(ActiveModel::Translation)
    end
  end

  describe '#save' do
    context 'when form is valid' do
      let(:attributes) { { name: 'Test' } }
      
      it 'calls persist! and returns true' do
        expect(form).to receive(:persist!)
        expect(form.save).to be true
      end
      
      it 'persists the form' do
        form.save
        expect(form.send(:persisted?)).to be true
      end
    end
    
    context 'when form is invalid' do
      let(:attributes) { { name: '' } }
      
      it 'does not call persist! and returns false' do
        expect(form).not_to receive(:persist!)
        expect(form.save).to be false
      end
      
      it 'adds errors' do
        form.save
        expect(form.errors[:name]).to be_present
      end
    end
  end
  
  describe '#from_date=' do
    context 'with valid date format MM/YYYY' do
      it 'sets from_month and from_year' do
        form.from_date = '03/2023'
        expect(form.from_month).to eq(3)
        expect(form.from_year).to eq(2023)
      end
      
      it 'handles single digit months' do
        form.from_date = '3/2023'
        expect(form.from_month).to eq(3)
        expect(form.from_year).to eq(2023)
      end
    end
    
    context 'with invalid date format' do
      it 'does not set month and year for invalid format' do
        form.from_date = '2023-03'
        expect(form.from_month).to be_nil
        expect(form.from_year).to be_nil
      end
      
      it 'does not set month and year for text' do
        form.from_date = 'March 2023'
        expect(form.from_month).to be_nil
        expect(form.from_year).to be_nil
      end
    end
    
    context 'with blank value' do
      it 'does not change month and year' do
        form.from_month = 5
        form.from_year = 2022
        form.from_date = ''
        expect(form.from_month).to eq(5)
        expect(form.from_year).to eq(2022)
      end
      
      it 'handles nil' do
        form.from_date = nil
        expect(form.from_month).to be_nil
        expect(form.from_year).to be_nil
      end
    end
    
    it 'stores the original value' do
      form.from_date = '03/2023'
      expect(form.from_date).to eq('03/2023')
    end
  end
  
  describe '#to_date=' do
    context 'with valid date format MM/YYYY' do
      it 'sets to_month and to_year' do
        form.to_date = '12/2024'
        expect(form.to_month).to eq(12)
        expect(form.to_year).to eq(2024)
      end
    end
    
    context 'with invalid date format' do
      it 'does not set month and year' do
        form.to_date = 'invalid'
        expect(form.to_month).to be_nil
        expect(form.to_year).to be_nil
      end
    end
    
    it 'stores the original value' do
      form.to_date = '12/2024'
      expect(form.to_date).to eq('12/2024')
    end
  end
  
  describe '#from_date' do
    context 'when from_date was set' do
      it 'returns the set value' do
        form.from_date = '03/2023'
        expect(form.from_date).to eq('03/2023')
      end
    end
    
    context 'when only month and year are set' do
      it 'formats the date as MM/YYYY' do
        form.from_month = 3
        form.from_year = 2023
        expect(form.from_date).to eq('03/2023')
      end
      
      it 'pads single digit months' do
        form.from_month = 1
        form.from_year = 2023
        expect(form.from_date).to eq('01/2023')
      end
    end
    
    context 'when month or year is missing' do
      it 'returns nil when month is missing' do
        form.from_year = 2023
        expect(form.from_date).to be_nil
      end
      
      it 'returns nil when year is missing' do
        form.from_month = 3
        expect(form.from_date).to be_nil
      end
      
      it 'returns nil when both are missing' do
        expect(form.from_date).to be_nil
      end
    end
  end
  
  describe '#to_date' do
    context 'when to_date was set' do
      it 'returns the set value' do
        form.to_date = '12/2024'
        expect(form.to_date).to eq('12/2024')
      end
    end
    
    context 'when only month and year are set' do
      it 'formats the date as MM/YYYY' do
        form.to_month = 12
        form.to_year = 2024
        expect(form.to_date).to eq('12/2024')
      end
    end
  end
  
  describe '#persist!' do
    context 'when not implemented in subclass' do
      let(:base_form) do
        Class.new(BaseForm) do
          # Don't implement persist!
        end
      end
      
      it 'raises NotImplementedError' do
        form = base_form.new
        expect { form.send(:persist!) }.to raise_error(
          NotImplementedError, 
          /doit implémenter la méthode #persist!/
        )
      end
    end
  end
  
  describe '#assign_to' do
    let(:model) { double('Model') }
    let(:attributes) { { name: 'Test Name' } }
    
    it 'assigns form attributes to the model' do
      expect(model).to receive(:assign_attributes).with(anything)
      form.send(:assign_to, model)
    end
    
    it 'assigns all attributes including dates' do
      form_with_dates = test_form_class.new(name: 'Test')
      form_with_dates.from_month = 3
      form_with_dates.from_year = 2023
      form_with_dates.to_month = 12
      form_with_dates.to_year = 2024
      
      expect(model).to receive(:assign_attributes) do |attrs|
        expect(attrs["from_month"]).to eq(3)
        expect(attrs["from_year"]).to eq(2023)
        expect(attrs["to_month"]).to eq(12)
        expect(attrs["to_year"]).to eq(2024)
        expect(attrs["name"]).to eq('Test')
      end
      
      form_with_dates.send(:assign_to, model)
    end
  end
  
  describe '.model_class' do
    it 'can be set on the class' do
      test_class = Class.new(BaseForm)
      test_class.model_class = String
      expect(test_class.model_class).to eq(String)
    end
  end
  
  describe 'edge cases' do
    describe 'date parsing' do
      it 'handles dates with extra spaces' do
        form.from_date = ' 03/2023 '
        expect(form.from_month).to be_nil
        expect(form.from_year).to be_nil
      end
      
      it 'handles dates with invalid months' do
        form.from_date = '13/2023'
        expect(form.from_month).to eq(13) # It parses but doesn't validate
        expect(form.from_year).to eq(2023)
      end
      
      it 'handles dates with 2-digit years' do
        form.from_date = '03/23'
        expect(form.from_month).to be_nil # Doesn't match the regex
        expect(form.from_year).to be_nil
      end
    end
  end
end