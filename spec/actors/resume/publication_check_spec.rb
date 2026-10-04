require 'rails_helper'

RSpec.describe Resume::PublicationCheck do
  describe '#call' do
    before do
      # Suppress output in tests
      allow($stdout).to receive(:puts)
      allow_any_instance_of(described_class).to receive(:p)
      
      # Stub environment variable
      allow(ENV).to receive(:[]).with('DEEPSEEK_API_KEY').and_return('test-api-key')
      
      # Stub file reads for prompts
      allow(File).to receive(:read).with(Rails.root.join("config/prompts/publication_check_resume.md"))
        .and_return("Check publication status")
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
          output: "Candidate JSON output"
        )
      end

      context 'when API returns successful streaming response' do
        let(:streaming_response) do
          [
            "data: {\"choices\":[{\"delta\":{\"content\":\"{\\\"publishable\\\":\"}}]}\n",
            "data: {\"choices\":[{\"delta\":{\"content\":\"true,\"}}]}\n",
            "data: {\"choices\":[{\"delta\":{\"content\":\"\\\"issues\\\":[]\"}}]}\n",
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
            "publishable" => true,
            "issues" => []
          })
        end

        it 'sends correct request headers' do
          request_mock = double('request')
          expect(request_mock).to receive(:[]=).with("Content-Type", "application/json")
          expect(request_mock).to receive(:[]=).with("Accept", "application/json")
          expect(request_mock).to receive(:[]=).with("Authorization", "Bearer test-api-key")
          expect(request_mock).to receive(:body=)
          
          allow(Net::HTTP::Post).to receive(:new).and_return(request_mock)
          
          described_class.call(candidate: candidate)
        end

        it 'includes current date in prompt' do
          request_mock = double('request')
          allow(request_mock).to receive(:[]=)
          
          expect(request_mock).to receive(:body=) do |body|
            parsed = JSON.parse(body)
            prompt_content = parsed["messages"][0]["content"]
            expect(prompt_content).to include("[DATE_ACTUELLE] = #{I18n.l(Date.today)}")
          end
          
          allow(Net::HTTP::Post).to receive(:new).and_return(request_mock)
          
          described_class.call(candidate: candidate)
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

      context 'with empty response chunks' do
        let(:streaming_response) do
          [
            ":",
            "",
            "data: {\"choices\":[{\"delta\":{\"content\":\"{}\"}}]}",
            "",
            "data: [DONE]",
            ""
          ].join("\n")
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

        it 'handles empty lines and colon prefixed lines correctly' do
          result = described_class.call(candidate: candidate)
          expect(result).to be_success
          expect(result.json_output).to eq({})
        end
      end
    end
  end
end