require 'rails_helper'

RSpec.describe Employment, type: :model do
  describe 'associations' do
    it { should belong_to(:candidate) }
  end

  describe 'default scope' do
    let(:candidate) { create(:candidate) }
    let!(:employment1) { create(:employment, candidate: candidate, from_year: 2020, from_month: 9) }
    let!(:employment2) { create(:employment, candidate: candidate, from_year: 2022, from_month: 1) }
    let!(:employment3) { create(:employment, candidate: candidate, from_year: 2020, from_month: 1) }

    it 'orders by from_year desc, then from_month desc' do
      expect(candidate.employments.to_a).to eq([employment2, employment1, employment3])
    end
  end

  describe 'callbacks' do
    describe 'before_validation :set_duration_in_months' do
      context 'with complete date information' do
        let(:employment) do
          build(:employment,
            from_year: 2020, from_month: 1,
            to_year: 2022, to_month: 6
          )
        end

        it 'calculates duration in months correctly' do
          employment.valid?
          expect(employment.duration_in_months).to eq(29) # (2022-2020)*12 + (6-1) = 24+5 = 29
        end
      end

      context 'with missing date information' do
        let(:employment) { build(:employment, from_year: nil) }

        it 'does not set duration_in_months' do
          employment.valid?
          expect(employment.duration_in_months).to be_nil
        end
      end
    end
  end

  describe '#from_date' do
    context 'with month and year' do
      let(:employment) { build(:employment, from_month: 9, from_year: 2020) }

      it 'formats date correctly' do
        expect(employment.from_date).to eq('09/2020')
      end
    end

    context 'without month' do
      let(:employment) { build(:employment, from_month: nil, from_year: 2020) }

      it 'returns nil when month is missing' do
        expect(employment.from_date).to be_nil
      end
    end

    context 'without year' do
      let(:employment) { build(:employment, from_month: 9, from_year: nil) }

      it 'returns nil when year is missing' do
        expect(employment.from_date).to be_nil
      end
    end
  end

  describe '#to_date' do
    context 'with month and year' do
      let(:employment) { build(:employment, to_month: 6, to_year: 2022) }

      it 'formats date correctly' do
        expect(employment.to_date).to eq('06/2022')
      end
    end

    context 'without month' do
      let(:employment) { build(:employment, to_month: nil, to_year: 2022) }

      it 'returns nil when month is missing' do
        expect(employment.to_date).to be_nil
      end
    end

    context 'without year' do
      let(:employment) { build(:employment, to_month: 6, to_year: nil) }

      it 'returns nil when year is missing' do
        expect(employment.to_date).to be_nil
      end
    end
  end

  describe 'memoization' do
    let(:employment) { build(:employment, from_month: 9, from_year: 2020, to_month: 6, to_year: 2022) }

    it 'memoizes from_date when both month and year present' do
      # First call should compute and memoize
      first_result = employment.from_date
      expect(first_result).to eq('09/2020')

      # Second call should return memoized value
      second_result = employment.from_date
      expect(second_result).to eq('09/2020')
      expect(second_result).to be(first_result) # Same object reference
    end

    it 'memoizes to_date when both month and year present' do
      # First call should compute and memoize
      first_result = employment.to_date
      expect(first_result).to eq('06/2022')

      # Second call should return memoized value
      second_result = employment.to_date
      expect(second_result).to eq('06/2022')
      expect(second_result).to be(first_result) # Same object reference
    end
  end

  describe 'edge cases' do
    context 'with single digit month' do
      let(:employment) { build(:employment, from_month: 5, from_year: 2020) }

      it 'zero-pads the month' do
        expect(employment.from_date).to eq('05/2020')
      end
    end

    context 'with year formatting' do
      let(:employment) { build(:employment, from_month: 12, from_year: 2020) }

      it 'formats year to 4 digits' do
        expect(employment.from_date).to eq('12/2020')
      end
    end
  end
end
