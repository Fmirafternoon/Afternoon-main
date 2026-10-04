require 'rails_helper'

RSpec.describe Education, type: :model do
  describe 'associations' do
    it { should belong_to(:candidate) }
  end

  describe 'default scope' do
    let(:candidate) { create(:candidate) }
    let!(:education1) { create(:education, candidate: candidate, from_year: 2020, from_month: 9) }
    let!(:education2) { create(:education, candidate: candidate, from_year: 2022, from_month: 1) }
    let!(:education3) { create(:education, candidate: candidate, from_year: 2020, from_month: 1) }

    it 'orders by from_year desc, then from_month desc' do
      expect(candidate.educations.to_a).to eq([education2, education1, education3])
    end
  end

  describe 'callbacks' do
    describe 'before_validation :set_duration_in_months' do
      context 'with complete date information' do
        let(:education) do
          build(:education,
            from_year: 2020, from_month: 9,
            to_year: 2022, to_month: 6
          )
        end

        it 'calculates duration in months correctly' do
          education.valid?
          expect(education.duration_in_months).to eq(21) # (2022-2020)*12 + (6-9) = 24-3 = 21
        end
      end

      context 'with missing date information' do
        let(:education) { build(:education, from_year: nil) }

        it 'does not set duration_in_months' do
          education.valid?
          expect(education.duration_in_months).to be_nil
        end
      end
    end
  end

  describe '#from_date' do
    context 'with month and year' do
      let(:education) { build(:education, from_month: 9, from_year: 2020) }

      it 'formats date correctly' do
        expect(education.from_date).to eq('09/2020')
      end
    end

    context 'with only year' do
      let(:education) { build(:education, from_month: nil, from_year: 2020) }

      it 'formats year only' do
        expect(education.from_date).to eq('2020')
      end
    end

    context 'with zero month' do
      let(:education) { build(:education, from_month: 0, from_year: 2020) }

      it 'treats zero month as nil' do
        expect(education.from_date).to eq('2020')
      end
    end

    context 'without year' do
      let(:education) { build(:education, from_month: 9, from_year: nil) }

      it 'returns nil' do
        expect(education.from_date).to be_nil
      end
    end

    context 'with zero year' do
      let(:education) { build(:education, from_month: 9, from_year: 0) }

      it 'returns nil' do
        expect(education.from_date).to be_nil
      end
    end
  end

  describe '#to_date' do
    context 'with month and year' do
      let(:education) { build(:education, to_month: 6, to_year: 2022) }

      it 'formats date correctly' do
        expect(education.to_date).to eq('06/2022')
      end
    end

    context 'with only year' do
      let(:education) { build(:education, to_month: nil, to_year: 2022) }

      it 'formats year only' do
        expect(education.to_date).to eq('2022')
      end
    end

    context 'with zero month' do
      let(:education) { build(:education, to_month: 0, to_year: 2022) }

      it 'treats zero month as nil' do
        expect(education.to_date).to eq('2022')
      end
    end

    context 'without year' do
      let(:education) { build(:education, to_month: 6, to_year: nil) }

      it 'returns nil' do
        expect(education.to_date).to be_nil
      end
    end

    context 'with zero year' do
      let(:education) { build(:education, to_month: 6, to_year: 0) }

      it 'returns nil' do
        expect(education.to_date).to be_nil
      end
    end
  end

  describe 'memoization' do
    let(:education) { build(:education, from_month: 9, from_year: 2020, to_month: 6, to_year: 2022) }

    it 'memoizes from_date' do
      expect(education).to receive(:format_date).with(9, 2020).once.and_call_original

      2.times { education.from_date }
    end

    it 'memoizes to_date' do
      expect(education).to receive(:format_date).with(6, 2022).once.and_call_original

      2.times { education.to_date }
    end
  end
end
