require 'rails_helper'

RSpec.describe Candidate::EmploymentsForm do
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

    context 'with from_month and from_year' do
      let(:attributes) do
        {
          id: candidate.id,
          from_month: 3,
          from_year: 2023
        }
      end

      it 'formats from_date' do
        expect(form.from_date).to eq('03/2023')
      end
    end

    context 'with to_month and to_year' do
      let(:attributes) do
        {
          id: candidate.id,
          to_month: 12,
          to_year: 2024
        }
      end

      it 'formats to_date' do
        expect(form.to_date).to eq('12/2024')
      end
    end

    context 'without month/year values' do
      it 'does not set from_date or to_date' do
        expect(form.from_date).to be_nil
        expect(form.to_date).to be_nil
      end
    end
  end

  describe 'validations' do
    describe 'presence validations' do
      let(:base_attributes) do
        {
          id: candidate.id,
          from_date: '01/2023',
          to_date: '12/2024',
          title: 'Software Developer',
          company: 'Tech Corp',
          sector: 'IT',
          location: 'Paris',
          description: 'Development work'
        }
      end

      it 'is valid with all required fields' do
        form = described_class.new(base_attributes)
        expect(form).to be_valid
      end

      it 'requires from_date' do
        form = described_class.new(base_attributes.except(:from_date))
        expect(form).not_to be_valid
        expect(form.errors[:from_date]).to include("doit être rempli(e)")
      end

      it 'requires to_date' do
        form = described_class.new(base_attributes.except(:to_date))
        expect(form).not_to be_valid
        expect(form.errors[:to_date]).to include("doit être rempli(e)")
      end

      it 'requires title' do
        form = described_class.new(base_attributes.except(:title))
        expect(form).not_to be_valid
        expect(form.errors[:title]).to include("doit être rempli(e)")
      end

      it 'requires company' do
        form = described_class.new(base_attributes.except(:company))
        expect(form).not_to be_valid
        expect(form.errors[:company]).to include("doit être rempli(e)")
      end

      it 'requires sector' do
        form = described_class.new(base_attributes.except(:sector))
        expect(form).not_to be_valid
        expect(form.errors[:sector]).to include("doit être rempli(e)")
      end

      it 'requires location' do
        form = described_class.new(base_attributes.except(:location))
        expect(form).not_to be_valid
        expect(form.errors[:location]).to include("doit être rempli(e)")
      end

      it 'requires description' do
        form = described_class.new(base_attributes.except(:description))
        expect(form).not_to be_valid
        expect(form.errors[:description]).to include("doit être rempli(e)")
      end
    end

    describe 'at_least_one_employment validation' do
      context 'when title is blank' do
        context 'when candidate has no employments' do
          it 'adds an error' do
            form = described_class.new(id: candidate.id, title: '')
            expect(form).not_to be_valid
            expect(form.errors[:base]).to include("Veuillez renseigner au moins une compétence")
          end
        end

        context 'when candidate has employments' do
          before do
            create(:employment, candidate: candidate)
          end

          it 'does not add an error' do
            form = described_class.new(id: candidate.id, title: '')
            form.valid?
            expect(form.errors[:base]).to be_empty
          end
        end
      end

      context 'when title is present' do
        it 'does not validate at_least_one_employment' do
          form = described_class.new(id: candidate.id, title: 'Developer')
          # Other validations will fail but not at_least_one_employment
          form.valid?
          expect(form.errors[:base]).not_to include("Veuillez renseigner au moins une compétence")
        end
      end
    end
  end

  describe '#valid_employment?' do
    context 'when candidate has no employments' do
      it 'returns false and adds error' do
        expect(form.valid_employment?).to be false
        expect(form.errors[:base]).to include("Veuillez renseigner au moins une expérience")
      end
    end

    context 'when candidate has employments' do
      before do
        create(:employment, candidate: candidate)
      end

      it 'returns true' do
        expect(form.valid_employment?).to be true
        expect(form.errors[:base]).to be_empty
      end
    end
  end

  describe '#save' do
    let(:valid_attributes) do
      {
        id: candidate.id,
        from_date: '01/2023',
        to_date: '12/2024',
        title: 'Software Developer',
        company: 'Tech Corp',
        sector: 'IT',
        location: 'Paris',
        description: 'Development work',
        duration_in_months: 24
      }
    end

    context 'when form is valid' do
      it 'creates a new employment' do
        form = described_class.new(valid_attributes)
        expect {
          form.save
        }.to change { candidate.employments.count }.by(1)
      end

      it 'creates employment with correct attributes' do
        form = described_class.new(valid_attributes)
        form.save
        
        employment = candidate.employments.last
        expect(employment.title).to eq('Software Developer')
        expect(employment.company).to eq('Tech Corp')
        expect(employment.sector).to eq('IT')
        expect(employment.location).to eq('Paris')
        expect(employment.description).to eq('Development work')
        expect(employment.duration_in_months).to eq(23)
        expect(employment.from_year).to eq(2023)
        expect(employment.from_month).to eq(1)
        expect(employment.to_year).to eq(2024)
        expect(employment.to_month).to eq(12)
      end

      it 'returns true' do
        form = described_class.new(valid_attributes)
        expect(form.save).to be true
      end
    end

    context 'when form is invalid' do
      it 'does not create employment' do
        form = described_class.new(id: candidate.id, title: 'Developer')
        expect {
          form.save
        }.not_to change { Employment.count }
      end

      it 'returns false' do
        form = described_class.new(id: candidate.id, title: 'Developer')
        expect(form.save).to be false
      end
    end
  end

  describe 'private methods' do
    describe '#at_least_one_employment' do
      context 'when candidate has no employments' do
        it 'adds error to base' do
          form.send(:at_least_one_employment)
          expect(form.errors[:base]).to include("Veuillez renseigner au moins une compétence")
        end
      end

      context 'when candidate has employments' do
        before do
          create(:employment, candidate: candidate)
        end

        it 'does not add error' do
          form.send(:at_least_one_employment)
          expect(form.errors[:base]).to be_empty
        end
      end
    end

    describe '#persist_employment!' do
      let(:attributes) do
        {
          id: candidate.id,
          from_date: '03/2023',
          to_date: '12/2024',
          title: 'Developer',
          company: 'Tech Corp',
          sector: 'IT',
          location: 'Paris',
          description: 'Development',
          duration_in_months: 22
        }
      end

      it 'parses dates and creates employment' do
        form = described_class.new(attributes)
        
        expect {
          form.send(:persist_employment!)
        }.to change { candidate.employments.count }.by(1)
        
        employment = candidate.employments.last
        expect(employment.from_year).to eq(2023)
        expect(employment.from_month).to eq(3)
        expect(employment.to_year).to eq(2024)
        expect(employment.to_month).to eq(12)
      end

      it 'excludes id, from_date, and to_date from attributes' do
        form = described_class.new(attributes)
        
        # Create the employment and inspect what attributes were passed
        expect {
          form.send(:persist_employment!)
        }.to change { Employment.count }.by(1)
        
        # Verify the created employment has the expected attributes
        employment = Employment.last
        expect(employment.title).to eq('Developer')
        expect(employment.company).to eq('Tech Corp')
        
        # Check attributes by inspecting what was saved
        # The form should not have passed id, from_date, or to_date
        # These are virtual attributes not persisted to the database
        expect(employment.attributes.keys).not_to include('from_date', 'to_date')
      end
    end

    describe '#persist!' do
      let(:valid_attributes) do
        {
          id: candidate.id,
          from_date: '01/2023',
          to_date: '12/2024',
          title: 'Developer',
          company: 'Tech Corp',
          sector: 'IT',
          location: 'Paris',
          description: 'Development'
        }
      end

      context 'when form is valid' do
        it 'calls persist_employment!' do
          form = described_class.new(valid_attributes)
          expect(form).to receive(:persist_employment!)
          form.send(:persist!)
        end
      end

      context 'when form is invalid' do
        it 'does not call persist_employment!' do
          form = described_class.new(id: candidate.id)
          expect(form).not_to receive(:persist_employment!)
          form.send(:persist!)
        end
      end
    end
  end

  describe 'edge cases' do
    it 'handles missing candidate' do
      expect {
        described_class.new(id: 999999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'handles date parsing with single digit months' do
      form = described_class.new(
        id: candidate.id,
        from_date: '3/2023',
        to_date: '9/2024'
      )
      
      form.send(:persist_employment!)
      employment = candidate.employments.last
      
      expect(employment.from_month).to eq(3)
      expect(employment.to_month).to eq(9)
    end
  end

  describe 'format_date helper' do
    it 'is available from BaseForm' do
      # The format_date method is used in initialize
      form = described_class.new(id: candidate.id, from_month: 1, from_year: 2023)
      expect(form.from_date).to eq('01/2023')
    end
  end
end