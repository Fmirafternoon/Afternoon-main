require 'rails_helper'

RSpec.describe Candidate::EducationsForm do
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

    context 'with from_month and from_year' do
      let(:attributes) do
        {
          id: candidate.id,
          from_month: 9,
          from_year: 2020
        }
      end

      it 'formats from_date' do
        expect(form.from_date).to eq('09/2020')
      end
    end

    context 'with to_month and to_year' do
      let(:attributes) do
        {
          id: candidate.id,
          to_month: 6,
          to_year: 2024
        }
      end

      it 'formats to_date' do
        expect(form.to_date).to eq('06/2024')
      end
    end

    context 'without month/year values' do
      it 'does not set from_date or to_date' do
        expect(form.from_date).to be_nil
        expect(form.to_date).to be_nil
      end
    end

    context 'with partial date values' do
      it 'does not format from_date with only month' do
        form = described_class.new(id: candidate.id, from_month: 3)
        expect(form.from_date).to be_nil
      end

      it 'does not format from_date with only year' do
        form = described_class.new(id: candidate.id, from_year: 2023)
        expect(form.from_date).to be_nil
      end
    end
  end

  describe 'validations' do
    describe 'title validation' do
      it 'requires title' do
        form = described_class.new(id: candidate.id)
        expect(form).not_to be_valid
        expect(form.errors[:title]).to include("doit être rempli(e)")
      end

      it 'is valid with title' do
        form = described_class.new(id: candidate.id, title: 'Master in Computer Science')
        expect(form).to be_valid
      end
    end

    describe 'other fields' do
      let(:base_attributes) do
        {
          id: candidate.id,
          title: 'Bachelor Degree'
        }
      end

      it 'does not require issuing_organization' do
        form = described_class.new(base_attributes)
        expect(form).to be_valid
      end

      it 'does not require location' do
        form = described_class.new(base_attributes)
        expect(form).to be_valid
      end

      it 'does not require duration_in_months' do
        form = described_class.new(base_attributes)
        expect(form).to be_valid
      end

      it 'does not require dates' do
        form = described_class.new(base_attributes)
        expect(form).to be_valid
      end
    end
  end

  describe '#save' do
    context 'when form is valid' do
      let(:valid_attributes) do
        {
          id: candidate.id,
          title: 'Master of Science',
          issuing_organization: 'University of Paris',
          location: 'Paris, France',
          duration_in_months: 24,
          from_date: '09/2018',
          to_date: '06/2020'
        }
      end

      it 'creates a new education' do
        form = described_class.new(valid_attributes)
        expect {
          form.save
        }.to change { candidate.educations.count }.by(1)
      end

      it 'creates education with correct attributes' do
        form = described_class.new(valid_attributes)
        form.save
        
        education = candidate.educations.last
        expect(education.title).to eq('Master of Science')
        expect(education.issuing_organization).to eq('University of Paris')
        expect(education.location).to eq('Paris, France')
        # Duration is calculated automatically: from 09/2018 to 06/2020 = 21 months
        expect(education.duration_in_months).to eq(21)
        expect(education.from_year).to eq(2018)
        expect(education.from_month).to eq(9)
        expect(education.to_year).to eq(2020)
        expect(education.to_month).to eq(6)
      end

      it 'returns true' do
        form = described_class.new(valid_attributes)
        expect(form.save).to be true
      end

      context 'with minimal attributes' do
        let(:minimal_attributes) do
          {
            id: candidate.id,
            title: 'High School Diploma',
            from_date: '09/2015',
            to_date: '06/2018'
          }
        end

        it 'creates education with minimal data' do
          form = described_class.new(minimal_attributes)
          expect(form.save).to be true
          
          education = candidate.educations.last
          expect(education.title).to eq('High School Diploma')
          expect(education.issuing_organization).to be_nil
          expect(education.location).to be_nil
        end
      end
    end

    context 'when form is invalid' do
      let(:invalid_attributes) do
        {
          id: candidate.id,
          issuing_organization: 'Some University'
        }
      end

      it 'does not create education' do
        form = described_class.new(invalid_attributes)
        expect {
          form.save
        }.not_to change { Education.count }
      end

      it 'returns false' do
        form = described_class.new(invalid_attributes)
        expect(form.save).to be false
      end

      it 'populates errors' do
        form = described_class.new(invalid_attributes)
        form.save
        expect(form.errors[:title]).to be_present
      end
    end
  end

  describe 'private methods' do
    describe '#persist!' do
      let(:attributes) do
        {
          id: candidate.id,
          title: 'PhD in Physics',
          issuing_organization: 'MIT',
          location: 'Cambridge, MA',
          from_date: '09/2021',
          to_date: '06/2025',
          duration_in_months: 48
        }
      end

      it 'parses dates and creates education' do
        form = described_class.new(attributes)
        
        expect {
          form.send(:persist!)
        }.to change { candidate.educations.count }.by(1)
        
        education = candidate.educations.last
        expect(education.from_year).to eq(2021)
        expect(education.from_month).to eq(9)
        expect(education.to_year).to eq(2025)
        expect(education.to_month).to eq(6)
      end

      it 'excludes id, from_date, and to_date from attributes' do
        form = described_class.new(attributes)
        
        # Create the education and check what was saved
        form.send(:persist!)
        education = Education.last
        
        # These are virtual attributes not persisted to the database
        expect(education.attributes.keys).not_to include('from_date', 'to_date')
        expect(education.title).to eq('PhD in Physics')
      end

      it 'handles date parsing correctly' do
        # Test with different date formats
        attrs = attributes.merge(from_date: '1/2021', to_date: '12/2025')
        form = described_class.new(attrs)
        form.send(:persist!)
        
        education = candidate.educations.last
        expect(education.from_month).to eq(1)
        expect(education.from_year).to eq(2021)
        expect(education.to_month).to eq(12)
        expect(education.to_year).to eq(2025)
      end
    end
  end

  describe 'edge cases' do
    describe 'date parsing edge cases' do
      it 'handles single digit months in from_date' do
        form = described_class.new(
          id: candidate.id,
          title: 'Certificate',
          from_date: '3/2023',
          to_date: '9/2023'
        )
        
        form.send(:persist!)
        education = candidate.educations.last
        
        expect(education.from_month).to eq(3)
        expect(education.to_month).to eq(9)
      end

      it 'handles various date formats' do
        form = described_class.new(
          id: candidate.id,
          title: 'Diploma',
          from_date: '12/2022',
          to_date: '01/2023'
        )
        
        form.send(:persist!)
        education = candidate.educations.last
        
        expect(education.from_month).to eq(12)
        expect(education.from_year).to eq(2022)
        expect(education.to_month).to eq(1)
        expect(education.to_year).to eq(2023)
      end
    end

    describe 'attribute handling' do
      it 'handles nil values properly' do
        form = described_class.new(
          id: candidate.id,
          title: 'Basic Education',
          issuing_organization: nil,
          location: nil,
          duration_in_months: nil,
          from_date: '01/2020',
          to_date: '12/2020'
        )
        
        expect(form).to be_valid
        form.save
        
        education = candidate.educations.last
        expect(education.issuing_organization).to be_nil
        expect(education.location).to be_nil
        # Duration is calculated automatically: from 01/2020 to 12/2020 = 11 months
        expect(education.duration_in_months).to eq(11)
      end

      it 'handles empty strings' do
        form = described_class.new(
          id: candidate.id,
          title: 'Some Degree',
          issuing_organization: '',
          location: '',
          from_date: '01/2020',
          to_date: '12/2020'
        )
        
        expect(form).to be_valid
        form.save
        
        education = candidate.educations.last
        expect(education.issuing_organization).to eq('')
        expect(education.location).to eq('')
      end
    end
  end

  describe 'GLOBAL_VALIDATION constant' do
    it 'is set to false' do
      expect(described_class::GLOBAL_VALIDATION).to be false
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