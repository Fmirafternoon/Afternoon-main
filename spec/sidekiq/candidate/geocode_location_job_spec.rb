require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe Candidate::GeocodeLocationJob, type: :job do
  let(:candidate) { create(:candidate) }
  let(:job) { described_class.new }
  let(:location) { create(:location, city: "Paris", zip_code: "75001") }
  
  before do
    Sidekiq::Testing.inline!
  end

  after do
    Sidekiq::Testing.fake!
  end

  describe '#perform' do
    context 'when candidate has an address' do
      before do
        candidate.update(address: "123 Rue de la Paix, 75001 Paris")
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
        
        # Mock Location::Geocode actor
        geocode_result = double('GeocodeResult', location: location)
        allow(Location::Geocode).to receive(:result).with(address: candidate.address).and_return(geocode_result)
        
        # Mock candidate update
        allow(candidate).to receive(:update)
      end

      it 'finds the candidate' do
        expect(Candidate).to receive(:find).with(candidate.id)
        job.perform(candidate.id)
      end

      it 'calls Location::Geocode with the candidate address' do
        expect(Location::Geocode).to receive(:result).with(address: "123 Rue de la Paix, 75001 Paris")
        job.perform(candidate.id)
      end

      it 'updates candidate with location_id' do
        expect(candidate).to receive(:update).with(location_id: location.id)
        job.perform(candidate.id)
      end

      context 'with different addresses' do
        it 'handles addresses with special characters' do
          candidate.update(address: "45 Avenue de l'Opéra, 75002 Paris")
          allow(candidate).to receive(:address).and_return("45 Avenue de l'Opéra, 75002 Paris")
          
          geocode_result = double('GeocodeResult', location: location)
          expect(Location::Geocode).to receive(:result).with(address: "45 Avenue de l'Opéra, 75002 Paris").and_return(geocode_result)
          job.perform(candidate.id)
        end

        it 'handles addresses with numbers and symbols' do
          candidate.update(address: "12-14 Bd Saint-Michel, 75006 Paris")
          allow(candidate).to receive(:address).and_return("12-14 Bd Saint-Michel, 75006 Paris")
          
          geocode_result = double('GeocodeResult', location: location)
          expect(Location::Geocode).to receive(:result).with(address: "12-14 Bd Saint-Michel, 75006 Paris").and_return(geocode_result)
          job.perform(candidate.id)
        end
      end

      context 'when geocoding returns different location' do
        let(:new_location) { create(:location, city: "Lyon", zip_code: "69001") }
        
        before do
          geocode_result = double('GeocodeResult', location: new_location)
          allow(Location::Geocode).to receive(:result).and_return(geocode_result)
        end

        it 'updates candidate with new location_id' do
          expect(candidate).to receive(:update).with(location_id: new_location.id)
          job.perform(candidate.id)
        end
      end
    end

    context 'when candidate has blank address' do
      before do
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
      end

      it 'returns early without geocoding when address is nil' do
        candidate.update(address: nil)
        
        expect(Location::Geocode).not_to receive(:result)
        expect(candidate).not_to receive(:update)
        
        job.perform(candidate.id)
      end

      it 'returns early without geocoding when address is empty string' do
        candidate.update(address: "")
        
        expect(Location::Geocode).not_to receive(:result)
        expect(candidate).not_to receive(:update)
        
        job.perform(candidate.id)
      end

      it 'returns early without geocoding when address has only whitespace' do
        candidate.update(address: "   ")
        
        expect(Location::Geocode).not_to receive(:result)
        expect(candidate).not_to receive(:update)
        
        job.perform(candidate.id)
      end
    end

    context 'when candidate not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          job.perform(999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when Location::Geocode returns nil location' do
      before do
        candidate.update(address: "Invalid Address XYZ")
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
        
        # Mock Location::Geocode returning nil location
        geocode_result = double('GeocodeResult', location: nil)
        allow(Location::Geocode).to receive(:result).and_return(geocode_result)
      end

      it 'raises error when trying to update with nil location_id' do
        expect {
          job.perform(candidate.id)
        }.to raise_error(NoMethodError)
      end
    end

    context 'error handling' do
      before do
        candidate.update(address: "123 Test Street")
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
      end

      it 'does not rescue Location::Geocode errors' do
        allow(Location::Geocode).to receive(:result).and_raise(StandardError.new('Geocoding API error'))
        
        expect {
          job.perform(candidate.id)
        }.to raise_error(StandardError, 'Geocoding API error')
      end

      it 'does not rescue update errors' do
        geocode_result = double('GeocodeResult', location: location)
        allow(Location::Geocode).to receive(:result).and_return(geocode_result)
        allow(candidate).to receive(:update).and_raise(ActiveRecord::RecordInvalid)
        
        expect {
          job.perform(candidate.id)
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'with existing location_id' do
      let(:old_location) { create(:location, city: "Marseille", zip_code: "13001") }
      
      before do
        candidate.update(address: "123 Rue de la Paix, 75001 Paris", location_id: old_location.id)
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
        
        geocode_result = double('GeocodeResult', location: location)
        allow(Location::Geocode).to receive(:result).and_return(geocode_result)
        allow(candidate).to receive(:update)
      end

      it 'overwrites existing location_id' do
        expect(candidate.location_id).to eq(old_location.id)
        expect(candidate).to receive(:update).with(location_id: location.id)
        job.perform(candidate.id)
      end
    end
  end

  describe 'Sidekiq configuration' do
    it 'includes Sidekiq::Job' do
      expect(described_class.ancestors).to include(Sidekiq::Job)
    end

    it 'can be enqueued' do
      Sidekiq::Testing.fake! do
        expect {
          described_class.perform_async(candidate.id)
        }.to change(described_class.jobs, :size).by(1)
      end
    end

    it 'enqueues with correct arguments' do
      Sidekiq::Testing.fake! do
        described_class.perform_async(candidate.id)
        
        job = described_class.jobs.last
        expect(job['args']).to eq([candidate.id])
      end
    end
  end

  describe 'integration scenarios' do
    context 'when called from Resume::ImportJob' do
      it 'processes candidate address after resume import' do
        candidate.update(address: "10 Downing Street, London")
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
        
        geocode_result = double('GeocodeResult', location: location)
        allow(Location::Geocode).to receive(:result).and_return(geocode_result)
        allow(candidate).to receive(:update)
        
        # Simulate being called after resume import
        expect(candidate).to have_attributes(address: "10 Downing Street, London")
        
        job.perform(candidate.id)
        
        expect(candidate).to have_received(:update).with(location_id: location.id)
      end
    end

    context 'when processing multiple candidates' do
      let(:candidate2) { create(:candidate, address: "456 Another Street") }
      let(:location2) { create(:location, city: "Nice", zip_code: "06000") }
      
      it 'handles multiple jobs independently' do
        # Setup for first candidate
        candidate.update(address: "123 First Street")
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
        geocode_result1 = double('GeocodeResult', location: location)
        allow(Location::Geocode).to receive(:result).with(address: "123 First Street").and_return(geocode_result1)
        allow(candidate).to receive(:update)
        
        # Setup for second candidate
        allow(Candidate).to receive(:find).with(candidate2.id).and_return(candidate2)
        geocode_result2 = double('GeocodeResult', location: location2)
        allow(Location::Geocode).to receive(:result).with(address: "456 Another Street").and_return(geocode_result2)
        allow(candidate2).to receive(:update)
        
        # Perform both jobs
        job.perform(candidate.id)
        job.perform(candidate2.id)
        
        # Verify each candidate got their respective location
        expect(candidate).to have_received(:update).with(location_id: location.id)
        expect(candidate2).to have_received(:update).with(location_id: location2.id)
      end
    end
  end
end