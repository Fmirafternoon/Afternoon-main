require 'rails_helper'

RSpec.describe Embedding::Create do
  let(:text) { ["Hello world"] }
  let(:actor_result) { described_class.call(text: text) }
  let(:embedding_response) { Array.new(1024) { rand } }
  
  before do
    # Stub environment variables
    allow(ENV).to receive(:fetch).with("EMBEDDING_MODEL_ID").and_return("text-embedding-model")
    allow(ENV).to receive(:fetch).with("EMBEDDING_URL").and_return("https://api.example.com")
    allow(ENV).to receive(:fetch).with("EMBEDDING_KEY").and_return("test-api-key")
  end

  describe '#call' do
    context 'when API request is successful' do
      let(:mock_response) do
        instance_double(Net::HTTPSuccess,
          body: {
            data: [{ embedding: embedding_response }]
          }.to_json,
          is_a?: true
        )
      end

      before do
        allow(Net::HTTP).to receive(:start).and_yield(double(request: mock_response))
      end

      it 'returns success' do
        expect(actor_result).to be_success
      end

      it 'returns the embedding array' do
        expect(actor_result.embedding).to eq(embedding_response)
      end

      it 'makes the correct API request' do
        uri = URI.join("https://api.example.com", "/v1/embeddings")
        
        expect(Net::HTTP).to receive(:start).with(
          uri.hostname,
          uri.port,
          use_ssl: true
        ).and_yield(double(request: mock_response))
        
        actor_result
      end

      it 'sends correct headers and body' do
        http_double = double('http')
        request_double = instance_double(Net::HTTP::Post)
        
        allow(Net::HTTP::Post).to receive(:new).and_return(request_double)
        allow(Net::HTTP).to receive(:start).and_yield(http_double)
        allow(http_double).to receive(:request).and_return(mock_response)
        
        expect(request_double).to receive(:[]=).with("Authorization", "Bearer test-api-key")
        expect(request_double).to receive(:[]=).with("Content-Type", "application/json")
        expect(request_double).to receive(:body=).with({
          model: "text-embedding-model",
          input: text,
          input_type: "search_document",
          encoding_format: "raw"
        }.to_json)
        
        actor_result
      end
    end

    context 'when API request fails' do
      let(:mock_response) do
        instance_double(Net::HTTPBadRequest,
          code: "400",
          body: "Bad request",
          is_a?: false
        )
      end

      before do
        allow(Net::HTTP).to receive(:start).and_yield(double(request: mock_response))
        allow($stdout).to receive(:puts) # Suppress error output in tests
      end

      it 'returns success but with empty array embedding' do
        expect(actor_result).to be_success
        expect(actor_result.embedding).to eq([])
      end

      it 'prints error message' do
        expect($stdout).to receive(:puts).with("Request failed: 400, Bad request")
        actor_result
      end
    end

    context 'with multiple texts' do
      let(:text) { ["Hello world", "Another text", "Third text"] }

      let(:mock_response) do
        instance_double(Net::HTTPSuccess,
          body: {
            data: [
              { embedding: Array.new(1024) { rand } },
              { embedding: Array.new(1024) { rand } },
              { embedding: Array.new(1024) { rand } }
            ]
          }.to_json,
          is_a?: true
        )
      end

      before do
        allow(Net::HTTP).to receive(:start).and_yield(double(request: mock_response))
      end

      it 'sends all texts in the input array' do
        uri = URI.join("https://api.example.com", "/v1/embeddings")
        request_double = instance_double(Net::HTTP::Post)
        
        allow(Net::HTTP::Post).to receive(:new).with(uri).and_return(request_double)
        allow(Net::HTTP).to receive(:start).and_yield(double(request: mock_response))
        allow(request_double).to receive(:[]=)
        
        expect(request_double).to receive(:body=).with({
          model: "text-embedding-model",
          input: text,
          input_type: "search_document",
          encoding_format: "raw"
        }.to_json)
        
        actor_result
      end

      it 'returns the first embedding' do
        response_data = JSON.parse(mock_response.body)
        expect(actor_result.embedding).to eq(response_data["data"][0]["embedding"])
      end
    end

    context 'with empty text array' do
      let(:text) { [] }

      it 'uses the default empty array' do
        uri = URI.join("https://api.example.com", "/v1/embeddings")
        request_double = instance_double(Net::HTTP::Post)
        
        allow(Net::HTTP::Post).to receive(:new).with(uri).and_return(request_double)
        allow(Net::HTTP).to receive(:start).and_yield(double(request: instance_double(Net::HTTPSuccess, body: { data: [{ embedding: [] }] }.to_json, is_a?: true)))
        allow(request_double).to receive(:[]=)
        
        expect(request_double).to receive(:body=).with({
          model: "text-embedding-model",
          input: [],
          input_type: "search_document",
          encoding_format: "raw"
        }.to_json)
        
        actor_result
      end
    end

    context 'when environment variables are missing' do
      it 'raises KeyError for missing EMBEDDING_MODEL_ID' do
        allow(ENV).to receive(:fetch).with("EMBEDDING_MODEL_ID").and_raise(KeyError)
        
        expect { actor_result }.to raise_error(KeyError)
      end

      it 'raises KeyError for missing EMBEDDING_URL' do
        allow(ENV).to receive(:fetch).with("EMBEDDING_URL").and_raise(KeyError)
        
        expect { actor_result }.to raise_error(KeyError)
      end

      it 'raises KeyError for missing EMBEDDING_KEY' do
        allow(ENV).to receive(:fetch).with("EMBEDDING_KEY").and_raise(KeyError)
        
        expect { actor_result }.to raise_error(KeyError)
      end
    end

    context 'when API response has unexpected format' do
      let(:mock_response) do
        instance_double(Net::HTTPSuccess,
          body: { unexpected: "format" }.to_json,
          is_a?: true
        )
      end

      before do
        allow(Net::HTTP).to receive(:start).and_yield(double(request: mock_response))
      end

      it 'returns empty array embedding' do
        expect(actor_result).to be_success
        expect(actor_result.embedding).to eq([])
      end
    end
  end
end