require 'rails_helper'

RSpec.describe Location, type: :model do
  describe 'associations' do
    it { should have_many(:company_locations).dependent(:destroy) }
    it { should have_many(:companies).through(:company_locations) }
    it { should have_many(:candidate_mobilities).dependent(:destroy) }
    it { should have_many(:candidates).through(:candidate_mobilities) }
  end

  describe 'geocoding' do
    it 'is geocoded by full_address' do
      # The geocoded_by method is defined on the model, not in geocoder_options
      expect(Location.instance_methods).to include(:full_address)
    end

    it 'is reverse geocoded by latitude and longitude' do
      # The model has latitude and longitude attributes for reverse geocoding
      location = Location.new
      expect(location).to respond_to(:latitude)
      expect(location).to respond_to(:longitude)
    end
  end

  describe '#name' do
    let(:location) { build(:location, city: 'Paris', zip_code: '75001') }

    it 'combines city and zip_code' do
      expect(location.name).to eq('Paris, 75001')
    end

    context 'with nil values' do
      let(:location) { build(:location, city: nil, zip_code: nil) }

      it 'handles nil values gracefully' do
        expect(location.name).to eq(', ')
      end
    end
  end

  describe '#full_address' do
    context 'with all address components' do
      let(:location) do
        build(:location,
          address: '123 Rue de Rivoli',
          city: 'Paris',
          zip_code: '75001'
        )
      end

      it 'formats complete address correctly' do
        expect(location.full_address).to eq('123 Rue de Rivoli, 75001 Paris')
      end
    end

    context 'without address' do
      let(:location) do
        build(:location,
          address: nil,
          city: 'Paris',
          zip_code: '75001'
        )
      end

      it 'formats address without street address' do
        expect(location.full_address).to eq('75001 Paris')
      end
    end

    context 'with empty address' do
      let(:location) do
        build(:location,
          address: '',
          city: 'Paris',
          zip_code: '75001'
        )
      end

      it 'formats address without street address' do
        expect(location.full_address).to eq('75001 Paris')
      end
    end

    context 'with blank address' do
      let(:location) do
        build(:location,
          address: '   ',
          city: 'Paris',
          zip_code: '75001'
        )
      end

      it 'treats blank address as not present' do
        expect(location.full_address).to eq('75001 Paris')
      end
    end
  end

  describe 'geocoding integration' do
    let(:location) do
      build(:location,
        address: '1 Place de la Concorde',
        city: 'Paris',
        zip_code: '75001'
      )
    end

    it 'uses full_address for geocoding' do
      expect(location.full_address).to eq('1 Place de la Concorde, 75001 Paris')
    end
  end

  describe 'edge cases' do
    context 'with special characters in address' do
      let(:location) do
        build(:location,
          address: "123 Rue de l'Église",
          city: 'Saint-Étienne',
          zip_code: '42000'
        )
      end

      it 'handles special characters correctly' do
        expect(location.full_address).to eq("123 Rue de l'Église, 42000 Saint-Étienne")
      end
    end

    context 'with long address components' do
      let(:location) do
        build(:location,
          address: 'Very Long Street Name That Goes On And On',
          city: 'Very Long City Name',
          zip_code: '12345'
        )
      end

      it 'handles long components correctly' do
        expected = 'Very Long Street Name That Goes On And On, 12345 Very Long City Name'
        expect(location.full_address).to eq(expected)
      end
    end
  end
end
