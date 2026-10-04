require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe 'modules' do
    it 'includes Pagy::Frontend' do
      expect(helper.class.included_modules).to include(Pagy::Frontend)
    end
  end

  describe '#format_indeterminate' do
    context 'when value is true' do
      it 'returns "Oui"' do
        expect(helper.format_indeterminate(true)).to eq("Oui")
      end
    end

    context 'when value is false' do
      it 'returns "Non"' do
        expect(helper.format_indeterminate(false)).to eq("Non")
      end
    end

    context 'when value is nil' do
      it 'returns "Non spécifié"' do
        expect(helper.format_indeterminate(nil)).to eq("Non spécifié")
      end
    end

    context 'when value is a string' do
      it 'returns "Non spécifié"' do
        expect(helper.format_indeterminate("something")).to eq("Non spécifié")
      end
    end

    context 'when value is a number' do
      it 'returns "Non spécifié"' do
        expect(helper.format_indeterminate(42)).to eq("Non spécifié")
      end
    end

    context 'when value is an empty string' do
      it 'returns "Non spécifié"' do
        expect(helper.format_indeterminate("")).to eq("Non spécifié")
      end
    end

    context 'when value is an object' do
      it 'returns "Non spécifié"' do
        expect(helper.format_indeterminate({})).to eq("Non spécifié")
      end
    end
  end

  describe '#datetime' do
    let(:datetime) { DateTime.new(2023, 12, 25, 14, 30, 0) }

    it 'formats datetime in DD/MM/YYYY à HH:MM format' do
      expect(helper.datetime(datetime)).to eq("25/12/2023 à 14:30")
    end

    context 'with different times' do
      it 'formats morning time correctly' do
        morning = DateTime.new(2023, 1, 1, 9, 5, 0)
        expect(helper.datetime(morning)).to eq("01/01/2023 à 09:05")
      end

      it 'formats evening time correctly' do
        evening = DateTime.new(2023, 6, 15, 23, 59, 0)
        expect(helper.datetime(evening)).to eq("15/06/2023 à 23:59")
      end

      it 'formats midnight correctly' do
        midnight = DateTime.new(2023, 3, 10, 0, 0, 0)
        expect(helper.datetime(midnight)).to eq("10/03/2023 à 00:00")
      end
    end

    context 'with Time objects' do
      it 'formats Time objects correctly' do
        time = Time.new(2023, 8, 20, 16, 45, 30)
        expect(helper.datetime(time)).to eq("20/08/2023 à 16:45")
      end
    end

    context 'with edge cases' do
      it 'handles leap year dates' do
        leap_day = DateTime.new(2024, 2, 29, 12, 0, 0)
        expect(helper.datetime(leap_day)).to eq("29/02/2024 à 12:00")
      end

      it 'handles single digit days and months' do
        single_digits = DateTime.new(2023, 3, 5, 7, 8, 0)
        expect(helper.datetime(single_digits)).to eq("05/03/2023 à 07:08")
      end
    end
  end

  describe 'integration with pagy' do
    it 'responds to pagy frontend methods' do
      # Test that helper has access to pagy methods
      expect(helper).to respond_to(:pagy_nav)
      expect(helper).to respond_to(:pagy_info)
    end
  end
end
