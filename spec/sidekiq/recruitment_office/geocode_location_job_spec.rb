require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe RecruitmentOffice::GeocodeLocationJob, type: :job do
  let(:office) { create(:recruitment_office, address: "123 Main Street", zip_code: "75001", city: "Paris") }
  let(:location) { create(:location, city: "Paris", zip_code: "75001") }
  let(:job) { described_class.new }

  describe '#perform' do
    context 'when the office has an address' do
      before do
        geocode_result = double('GeocodeResult', location: location)
        allow(Location::Geocode).to receive(:result).and_return(geocode_result)
      end

      it 'geocodes the full address (address, zip code, city)' do
        expect(Location::Geocode).to receive(:result)
          .with(address: "123 Main Street, 75001, Paris")
        job.perform(office.id)
      end

      it 'updates the office with the location_id' do
        job.perform(office.id)
        expect(office.reload.location_id).to eq(location.id)
      end
    end

    context 'when the office has a partial address' do
      let(:office) { create(:recruitment_office, address: nil, zip_code: "69001", city: "Lyon") }

      it 'geocodes with the available parts only' do
        geocode_result = double('GeocodeResult', location: location)
        expect(Location::Geocode).to receive(:result)
          .with(address: "69001, Lyon").and_return(geocode_result)
        job.perform(office.id)
      end
    end

    context 'when the office has no address at all' do
      let(:office) { create(:recruitment_office, address: nil, zip_code: nil, city: nil) }

      it 'returns early without geocoding' do
        expect(Location::Geocode).not_to receive(:result)
        job.perform(office.id)
      end
    end

    context 'when geocoding finds no result' do
      it 'does not update the office' do
        geocode_result = double('GeocodeResult', location: nil)
        allow(Location::Geocode).to receive(:result).and_return(geocode_result)

        job.perform(office.id)
        expect(office.reload.location_id).to be_nil
      end
    end

    context 'when the office is not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect { job.perform(999_999) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'automatic enqueueing', :enable_callbacks do
    it 'enqueues a job when the address changes' do
      office
      expect {
        office.update!(city: "Marseille")
      }.to change(described_class.jobs, :size).by(1)
    end

    it 'does not enqueue a job when an unrelated attribute changes' do
      office
      expect {
        office.update!(name: "Nouveau nom")
      }.not_to change(described_class.jobs, :size)
    end

    it 'does not enqueue a job when the job itself sets location_id' do
      office
      expect {
        office.update!(location_id: location.id)
      }.not_to change(described_class.jobs, :size)
    end
  end
end
