require 'rails_helper'

RSpec.describe ProjectCandidate::Analyse do
  let(:customer) { create(:user) }
  let(:location) { create(:location, city: "Paris", zip_code: "75001") }
  let(:project) { create(:project, customer: customer, location: location, position_name: "Chef de cuisine") }
  let(:candidate) { create(:candidate, publication_status: "published") }
  let(:project_candidate) { create(:project_candidate, project: project, candidate: candidate) }

  let(:llm_response) do
    {
      "summary" => "Ce profil présente une bonne adéquation.",
      "strengths" => ["Expérience solide", "Compétences techniques"],
      "attention_points" => ["Manque de leadership"]
    }
  end

  describe '#call' do
    context 'when API returns valid response' do
      before do
        stub_deepseek_streaming_response(llm_response)
      end

      it 'returns parsed JSON output' do
        result = described_class.call(project_candidate: project_candidate)

        expect(result.json_output).to eq(llm_response)
      end

      it 'includes summary, strengths and attention_points' do
        result = described_class.call(project_candidate: project_candidate)

        expect(result.json_output["summary"]).to be_present
        expect(result.json_output["strengths"]).to be_an(Array)
        expect(result.json_output["attention_points"]).to be_an(Array)
      end
    end

    context 'when API returns invalid JSON' do
      before do
        stub_deepseek_streaming_response_raw("invalid json {")
      end

      it 'raises an error' do
        expect {
          described_class.call(project_candidate: project_candidate)
        }.to raise_error(/Invalid JSON response/)
      end
    end
  end

  # Helper pour simuler la réponse streaming de Deepseek
  def stub_deepseek_streaming_response(response_hash)
    json_content = response_hash.to_json
    streaming_body = build_streaming_body(json_content)

    stub_request(:post, "https://api.deepseek.com/chat/completions")
      .to_return(
        status: 200,
        body: streaming_body,
        headers: { 'Content-Type' => 'text/event-stream' }
      )
  end

  def stub_deepseek_streaming_response_raw(content)
    streaming_body = build_streaming_body(content)

    stub_request(:post, "https://api.deepseek.com/chat/completions")
      .to_return(
        status: 200,
        body: streaming_body,
        headers: { 'Content-Type' => 'text/event-stream' }
      )
  end

  def build_streaming_body(content)
    chunks = content.chars.each_slice(10).map(&:join)
    body = ""
    chunks.each do |chunk|
      body += "data: #{JSON.dump({ choices: [{ delta: { content: chunk } }] })}\n\n"
    end
    body += "data: [DONE]\n\n"
    body
  end
end
