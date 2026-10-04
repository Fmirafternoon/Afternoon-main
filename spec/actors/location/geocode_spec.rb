require 'rails_helper'

RSpec.describe Location::Geocode do
  let(:address) { "1 rue de la Paix, 75001 Paris" }
  let(:actor_result) { described_class.call(address: address) }

  describe '#call' do
    context 'when API returns results' do
      let(:api_response) do
        {
          "features" => [
            {
              "properties" => {
                "name" => "1 rue de la Paix",
                "city" => "Paris",
                "postcode" => "75001"
              },
              "geometry" => {
                "coordinates" => [2.3312, 48.8696]
              }
            }
          ]
        }
      end

      before do
        stub_request(:get, "https://api-adresse.data.gouv.fr/search/?q=1+rue+de+la+Paix%2C+75001+Paris")
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      context 'when location does not exist' do
        it 'returns success' do
          expect(actor_result).to be_success
        end

        it 'creates a new location' do
          expect { actor_result }.to change(Location, :count).by(1)
        end

        it 'returns the created location' do
          location = actor_result.location
          expect(location).to be_a(Location)
          expect(location.address).to eq("1 rue de la Paix")
          expect(location.city).to eq("Paris")
          expect(location.zip_code).to eq("75001")
          expect(location.latitude).to eq(48.8696)
          expect(location.longitude).to eq(2.3312)
        end
      end

      context 'when location already exists' do
        let!(:existing_location) do
          Location.create!(
            address: "1 rue de la Paix",
            city: "Paris",
            zip_code: "75001",
            latitude: 48.8696,
            longitude: 2.3312
          )
        end

        it 'returns success' do
          expect(actor_result).to be_success
        end

        it 'does not create a new location' do
          expect { actor_result }.not_to change(Location, :count)
        end

        it 'returns the existing location' do
          expect(actor_result.location).to eq(existing_location)
        end
      end
    end

    context 'when API returns no results' do
      let(:api_response) do
        {
          "features" => []
        }
      end

      before do
        stub_request(:get, "https://api-adresse.data.gouv.fr/search/?q=1+rue+de+la+Paix%2C+75001+Paris")
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns success' do
        expect(actor_result).to be_success
      end

      it 'does not create a location' do
        expect { actor_result }.not_to change(Location, :count)
      end

      it 'returns nil location' do
        expect(actor_result.location).to be_nil
      end
    end

    context 'with special characters in address' do
      let(:address) { "Rue de l'École & Café, 69001 Lyon" }
      
      before do
        stub_request(:get, "https://api-adresse.data.gouv.fr/search/?q=Rue+de+l%27%C3%89cole+%26+Caf%C3%A9%2C+69001+Lyon")
          .to_return(status: 200, body: { "features" => [] }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'properly encodes the URL' do
        actor_result
        expect(WebMock).to have_requested(:get, "https://api-adresse.data.gouv.fr/search/?q=Rue+de+l%27%C3%89cole+%26+Caf%C3%A9%2C+69001+Lyon")
      end
    end

    context 'when API request fails' do
      before do
        stub_request(:get, "https://api-adresse.data.gouv.fr/search/?q=1+rue+de+la+Paix%2C+75001+Paris")
          .to_return(status: 500, body: "Internal Server Error")
      end

      it 'raises an error' do
        expect { actor_result }.to raise_error(JSON::ParserError)
      end
    end

    context 'when network error occurs' do
      before do
        stub_request(:get, "https://api-adresse.data.gouv.fr/search/?q=1+rue+de+la+Paix%2C+75001+Paris")
          .to_timeout
      end

      it 'raises a timeout error' do
        expect { actor_result }.to raise_error(Net::OpenTimeout)
      end
    end

    context 'with empty address' do
      let(:address) { "" }

      before do
        stub_request(:get, "https://api-adresse.data.gouv.fr/search/?q=")
          .to_return(status: 200, body: { "features" => [] }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns success' do
        expect(actor_result).to be_success
      end

      it 'returns nil location' do
        expect(actor_result.location).to be_nil
      end
    end

    context 'with multiple results' do
      let(:api_response) do
        {
          "features" => [
            {
              "properties" => {
                "name" => "1 rue de la Paix",
                "city" => "Paris",
                "postcode" => "75001"
              },
              "geometry" => {
                "coordinates" => [2.3312, 48.8696]
              }
            },
            {
              "properties" => {
                "name" => "1 rue de la Paix",
                "city" => "Lyon",
                "postcode" => "69001"
              },
              "geometry" => {
                "coordinates" => [4.8357, 45.7640]
              }
            }
          ]
        }
      end

      before do
        stub_request(:get, "https://api-adresse.data.gouv.fr/search/?q=1+rue+de+la+Paix%2C+75001+Paris")
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'uses the first result' do
        location = actor_result.location
        expect(location.city).to eq("Paris")
        expect(location.zip_code).to eq("75001")
      end
    end
  end
end