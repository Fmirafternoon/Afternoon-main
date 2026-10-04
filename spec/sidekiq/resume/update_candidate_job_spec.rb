require 'rails_helper'

RSpec.describe Resume::UpdateCandidateJob, type: :job do
  let(:agent) { create(:user, :agent_user) }
  let(:candidate) { create(:candidate, agent: agent) }
  let(:job) { described_class.new }

  let(:llm_result) do
    {
      "first_name" => "John",
      "last_name" => "Doe",
      "position" => "Software Developer"
    }
  end

  describe 'sidekiq options' do
    it 'has retry set to 0' do
      expect(described_class.sidekiq_options_hash['retry']).to eq(0)
    end

    it 'uses the default queue' do
      expect(described_class.sidekiq_options_hash['queue']).to eq('default')
    end
  end

  describe '#perform' do
    before do
      # Prerequisite: candidate must have llm_analysis_result and be in pending status
      # (AnalyseLlmJob sets these before calling UpdateCandidateJob)
      candidate.start_import_workflow! # uploading → pending
      candidate.update_column(:llm_analysis_result, llm_result)

      # Mock external dependencies
      allow(Resume::EmbedJob).to receive(:perform_async)
      allow(Candidate::GeocodeLocationJob).to receive(:perform_async)
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
      allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
    end

    context 'when update succeeds' do
      it 'calls Resume::UpdateCandidate with llm_analysis_result' do
        expect(Resume::UpdateCandidate).to receive(:call).with(
          candidate: candidate,
          json_output: llm_result
        )
        job.perform(candidate.id)
      end

      it 'marks candidate as completed' do
        job.perform(candidate.id)
        candidate.reload
        expect(candidate.import_status).to eq('completed')
      end

      it 'updates candidate attributes from LLM result' do
        job.perform(candidate.id)
        candidate.reload
        expect(candidate.first_name).to eq('John')
        expect(candidate.last_name).to eq('Doe')
        expect(candidate.position).to eq('Software Developer')
      end

      it 'enqueues Candidate::GeocodeLocationJob' do
        expect(Candidate::GeocodeLocationJob).to receive(:perform_async).with(candidate.id)
        job.perform(candidate.id)
      end

      it 'broadcasts completed status via Turbo' do
        expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
          "candidates_#{agent.id}",
          hash_including(partial: "agent/candidates/upload")
        )
        expect(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).with(
          "candidates_#{agent.id}",
          hash_including(partial: "agent/candidates/candidate")
        )
        job.perform(candidate.id)
      end
    end

    context 'when llm_analysis_result is missing' do
      before do
        # Override the before block: remove llm_analysis_result
        # but keep candidate in pending status
        candidate.update_column(:llm_analysis_result, nil)
      end

      it 'raises an error' do
        expect {
          job.perform(candidate.id)
        }.to raise_error(StandardError, /llm_analysis_result is missing/)
      end

      it 'marks candidate as failed' do
        begin
          job.perform(candidate.id)
        rescue StandardError
          # Expected
        end

        candidate.reload
        expect(candidate.import_status).to eq('failed')
      end

      it 'does not enqueue GeocodeLocationJob' do
        expect(Candidate::GeocodeLocationJob).not_to receive(:perform_async)

        begin
          job.perform(candidate.id)
        rescue StandardError
          # Expected
        end
      end
    end

    context 'when Resume::UpdateCandidate fails' do
      before do
        allow(Resume::UpdateCandidate).to receive(:call).and_raise(StandardError.new('Update error'))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with("Candidate #{candidate.id}: Update failed: Update error")
        expect(Rails.logger).to receive(:error).with(anything) # backtrace

        expect {
          job.perform(candidate.id)
        }.to raise_error(StandardError, 'Update error')
      end

      it 'marks candidate as failed' do
        begin
          job.perform(candidate.id)
        rescue StandardError
          # Expected
        end

        candidate.reload
        expect(candidate.import_status).to eq('failed')
      end

      it 'raises the error (no retry, so it goes to Dead queue)' do
        expect {
          job.perform(candidate.id)
        }.to raise_error(StandardError, 'Update error')
      end

      it 'does not enqueue GeocodeLocationJob' do
        expect(Candidate::GeocodeLocationJob).not_to receive(:perform_async)

        begin
          job.perform(candidate.id)
        rescue StandardError
          # Expected
        end
      end
    end

    context 'when candidate is not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          job.perform(999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    # Note: Transaction rollback behavior is tested in spec/actors/resume/update_candidate_spec.rb
    # where the actual Resume::UpdateCandidate actor is tested with real transactions
  end
end
