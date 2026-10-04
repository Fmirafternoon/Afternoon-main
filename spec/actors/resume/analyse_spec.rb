require 'rails_helper'

RSpec.describe Resume::Analyse do
  describe '#call' do
    before do
      # Suppress output in tests
      allow($stdout).to receive(:puts)
      allow_any_instance_of(described_class).to receive(:p)
      
      # Stub environment variable
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('DEEPSEEK_API_KEY').and_return('test-api-key')
      
      # Stub file reads for prompts
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(Rails.root.join("config/prompts/analyze_resume.md"))
        .and_return("Analyze this resume")
      allow(File).to receive(:read).with(Rails.root.join("config/prompts/resume_schema.json"))
        .and_return('{"type": "object", "properties": {"skills": {"type": "array"}}}')
    end

    context 'when candidate is nil' do
      it 'returns success with nil json_output' do
        result = described_class.call(candidate: nil)
        expect(result).to be_success
        expect(result.json_output).to be_nil
      end

      it 'does not make API calls' do
        expect(Net::HTTP).not_to receive(:new)
        described_class.call(candidate: nil)
      end
    end

    context 'when candidate is blank' do
      let(:candidate) { "" }
      
      it 'returns success with nil json_output' do
        result = described_class.call(candidate: candidate)
        expect(result).to be_success
        expect(result.json_output).to be_nil
      end
    end

    context 'when candidate is present' do
      let(:candidate) do
        double("Candidate",
          blank?: false,
          resume_file_name: "resume.pdf",
          resume_url: "https://example.com/resume.pdf",
          output: "Candidate JSON output",
          candidate_documents: []
        )
      end

      before do
        # Stub Resume::ExtractText
        allow(Resume::ExtractText).to receive(:call)
          .and_return(OpenStruct.new(extracted_text: "John Doe\nSoftware Engineer\nExperience: 5 years"))
        
        # Stub Sector.all
        sectors = [
          double("Sector", id: 1, name: "IT"),
          double("Sector", id: 2, name: "Finance")
        ]
        # Allow both hash and keyword argument styles
        allow(sectors[0]).to receive(:as_json).and_return({ id: 1, name: "IT" })
        allow(sectors[1]).to receive(:as_json).and_return({ id: 2, name: "Finance" })
        allow(Sector).to receive(:all).and_return(sectors)
      end

      context 'when API returns successful streaming response' do
        let(:streaming_response) do
          [
            "data: {\"choices\":[{\"delta\":{\"content\":\"{\\\"skills\\\":\"}}]}\n",
            "data: {\"choices\":[{\"delta\":{\"content\":\"[\\\"Ruby\\\",\"}}]}\n",
            "data: {\"choices\":[{\"delta\":{\"content\":\"\\\"Rails\\\"]\"}}]}\n",
            "data: {\"choices\":[{\"delta\":{\"content\":\"}\"}}]}\n",
            "data: [DONE]\n"
          ].join
        end

        before do
          # Mock HTTP response
          response_mock = double('response')
          allow(response_mock).to receive(:read_body).and_yield(streaming_response)
          
          http_mock = double('http')
          allow(http_mock).to receive(:use_ssl=)
          allow(http_mock).to receive(:request).and_yield(response_mock)
          
          allow(Net::HTTP).to receive(:new).and_return(http_mock)
          allow(Net::HTTP::Post).to receive(:new).and_return(double(
            :[]= => nil,
            :body= => nil
          ))
        end

        it 'returns success' do
          result = described_class.call(candidate: candidate)
          expect(result).to be_success
        end

        it 'parses the streaming JSON correctly' do
          result = described_class.call(candidate: candidate)
          expect(result.json_output).to eq({
            "skills" => ["Ruby", "Rails"]
          })
        end
      end

      context 'when API returns invalid JSON in stream' do
        let(:streaming_response) do
          "data: {\"choices\":[{\"delta\":{\"content\":\"invalid json\"}}]}\ndata: [DONE]\n"
        end

        before do
          response_mock = double('response')
          allow(response_mock).to receive(:read_body).and_yield(streaming_response)
          
          http_mock = double('http')
          allow(http_mock).to receive(:use_ssl=)
          allow(http_mock).to receive(:request).and_yield(response_mock)
          
          allow(Net::HTTP).to receive(:new).and_return(http_mock)
          allow(Net::HTTP::Post).to receive(:new).and_return(double(
            :[]= => nil,
            :body= => nil
          ))
        end

        it 'returns success but json_output is nil' do
          result = described_class.call(candidate: candidate)
          expect(result).to be_success
          expect(result.json_output).to be_nil
        end
      end

      context 'when API returns malformed streaming data' do
        let(:streaming_response) do
          "data: malformed\ndata: [DONE]\n"
        end

        before do
          response_mock = double('response')
          allow(response_mock).to receive(:read_body).and_yield(streaming_response)
          
          http_mock = double('http')
          allow(http_mock).to receive(:use_ssl=)
          allow(http_mock).to receive(:request).and_yield(response_mock)
          
          allow(Net::HTTP).to receive(:new).and_return(http_mock)
          allow(Net::HTTP::Post).to receive(:new).and_return(double(
            :[]= => nil,
            :body= => nil
          ))
        end

        it 'raises JSON parse error' do
          expect { described_class.call(candidate: candidate) }.to raise_error(RuntimeError, /Erreur de parsing JSON/)
        end
      end

      context 'with candidate documents' do
        let(:document1) { double("Document", file_name: "doc1.pdf", url: "https://example.com/doc1.pdf") }
        let(:document2) { double("Document", file_name: "doc2.pdf", url: "https://example.com/doc2.pdf") }
        
        before do
          allow(candidate).to receive(:candidate_documents).and_return([document1, document2])
          
          # Mock Resume::ExtractText for documents
          allow(Resume::ExtractText).to receive(:call).with(document: document1)
            .and_return(OpenStruct.new(extracted_text: "Document 1 content"))
          allow(Resume::ExtractText).to receive(:call).with(document: document2)
            .and_return(OpenStruct.new(extracted_text: "Document 2 content"))
          
          # Keep the original mock for the main resume
          allow(Resume::ExtractText).to receive(:call).with(document: instance_of(OpenStruct))
            .and_return(OpenStruct.new(extracted_text: "John Doe\nSoftware Engineer\nExperience: 5 years"))
        end

        it 'includes document content in the prompt' do
          request_mock = double('request')
          allow(request_mock).to receive(:[]=)
          
          expect(request_mock).to receive(:body=) do |body|
            parsed = JSON.parse(body)
            prompt_content = parsed["messages"][0]["content"]
            expect(prompt_content).to include("Document 1 content")
            expect(prompt_content).to include("Document 2 content")
            expect(prompt_content).to include("doc1.pdf")
            expect(prompt_content).to include("doc2.pdf")
          end
          
          allow(Net::HTTP::Post).to receive(:new).and_return(request_mock)
          
          # Mock successful response
          response_mock = double('response')
          allow(response_mock).to receive(:read_body).and_yield("data: {\"choices\":[{\"delta\":{\"content\":\"{}\"}}]}\ndata: [DONE]\n")
          
          http_mock = double('http')
          allow(http_mock).to receive(:use_ssl=)
          allow(http_mock).to receive(:request).and_yield(response_mock)
          
          allow(Net::HTTP).to receive(:new).and_return(http_mock)
          
          described_class.call(candidate: candidate)
        end
      end
    end
  end
end