require 'rails_helper'

RSpec.describe ProjectCandidate::AnalyseJob do
  let(:customer) { create(:user) }
  let(:location) { create(:location, city: "Paris") }
  let(:project) { create(:project, customer: customer, location: location, position_name: "Chef") }
  let(:candidate) { create(:candidate, publication_status: "published") }
  let(:project_candidate) { create(:project_candidate, project: project, candidate: candidate, status: :pending) }

  let(:llm_response) do
    {
      "summary" => "Ce profil présente une bonne adéquation.",
      "strengths" => ["Expérience solide", "Compétences techniques"],
      "attention_points" => ["Manque de leadership"]
    }
  end

  describe '#perform' do
    context 'when project_candidate is already matched with analysis' do
      before do
        project_candidate.update!(status: :matched, llm_analysis: llm_response)
      end

      it 'skips analysis' do
        expect(ProjectCandidate::Analyse).not_to receive(:call)

        described_class.new.perform(project_candidate.id)
      end
    end

    context 'when project_candidate is pending (needs analysis)' do
      before do
        allow(ProjectCandidate::Analyse).to receive(:call)
          .and_return(OpenStruct.new(json_output: llm_response))
      end

      it 'calls the Analyse actor' do
        expect(ProjectCandidate::Analyse).to receive(:call)
          .with(project_candidate: project_candidate)

        described_class.new.perform(project_candidate.id)
      end

      it 'updates llm_analysis column' do
        described_class.new.perform(project_candidate.id)

        project_candidate.reload
        expect(project_candidate.llm_analysis).to eq(llm_response)
      end

      it 'changes status from pending to matched' do
        expect(project_candidate.status).to eq("pending")

        described_class.new.perform(project_candidate.id)

        project_candidate.reload
        expect(project_candidate.status).to eq("matched")
      end

      it 'sends notification email to agent' do
        expect(AgentMailer).to receive(:candidate_matched)
          .with(project_candidate.id)
          .and_return(double(deliver_later: true))

        described_class.new.perform(project_candidate.id)
      end
    end

    context 'when Analyse actor returns nil' do
      before do
        allow(ProjectCandidate::Analyse).to receive(:call)
          .and_return(OpenStruct.new(json_output: nil))
      end

      it 'raises an error for retry' do
        expect {
          described_class.new.perform(project_candidate.id)
        }.to raise_error(StandardError, /LLM analysis returned nil/)
      end
    end

    context 'when Analyse actor raises error' do
      before do
        allow(ProjectCandidate::Analyse).to receive(:call)
          .and_raise(StandardError.new("API error"))
      end

      it 're-raises the error for Sidekiq retry' do
        expect {
          described_class.new.perform(project_candidate.id)
        }.to raise_error(StandardError, "API error")
      end
    end
  end
end
