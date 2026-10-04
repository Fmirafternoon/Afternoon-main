require 'rails_helper'

RSpec.describe Resume::AnalyseLlmJob, type: :job do
  let(:agent) { create(:user, :agent_user) }
  let(:candidate) { create(:candidate, agent: agent) }
  let(:job) { described_class.new }

  describe 'sidekiq options' do
    it 'has retry set to 5' do
      expect(described_class.sidekiq_options_hash['retry']).to eq(5)
    end

    it 'uses the llm queue' do
      expect(described_class.sidekiq_options_hash['queue']).to eq('llm')
    end
  end

  describe '#perform' do
    let(:llm_result) do
      {
        "first_name" => "John",
        "last_name" => "Doe",
        "position" => "Developer"
      }
    end

    before do
      # Mock external dependencies
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
      allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
    end

    context 'when LLM analysis succeeds' do
      before do
        analysis_result = double('AnalysisResult', json_output: llm_result)
        allow(Resume::Analyse).to receive(:call).with(candidate: candidate).and_return(analysis_result)
      end

      it 'calls Resume::Analyse' do
        expect(Resume::Analyse).to receive(:call).with(candidate: candidate)
        job.perform(candidate.id)
      end

      it 'caches the LLM result in llm_analysis_result' do
        job.perform(candidate.id)
        candidate.reload
        expect(candidate.llm_analysis_result).to eq(llm_result)
      end

      it 'enqueues Resume::UpdateCandidateJob with the candidate_id' do
        expect(Resume::UpdateCandidateJob).to receive(:perform_async).with(candidate.id)
        job.perform(candidate.id)
      end

      it 'broadcasts pending status via Turbo' do
        expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
          "candidates_#{agent.id}",
          hash_including(partial: "agent/candidates/upload")
        )
        job.perform(candidate.id)
      end

      context 'when llm_analysis_result already exists' do
        before do
          candidate.update_column(:llm_analysis_result, { "cached" => "data" })
        end

        it 'reuses cached result without calling Resume::Analyse' do
          expect(Resume::Analyse).not_to receive(:call)
          expect(Resume::UpdateCandidateJob).to receive(:perform_async).with(candidate.id)
          job.perform(candidate.id)
        end

        it 'does not overwrite the cache' do
          original_cache = candidate.llm_analysis_result
          job.perform(candidate.id)
          candidate.reload
          expect(candidate.llm_analysis_result).to eq(original_cache)
        end
      end
    end

    context 'when LLM analysis returns nil' do
      before do
        analysis_result = double('AnalysisResult', json_output: nil)
        allow(Resume::Analyse).to receive(:call).and_return(analysis_result)
      end

      it 'does not mark candidate as failed during perform (stays pending for retry)' do
        expect {
          job.perform(candidate.id)
        }.to raise_error(StandardError, /LLM analysis returned nil/)

        candidate.reload
        expect(candidate.import_status).not_to eq('failed')
      end

      it 'marks candidate as failed when retries are exhausted' do
        candidate.start_import_workflow!
        exception = StandardError.new('LLM analysis returned nil')
        described_class.sidekiq_retries_exhausted_block.call(
          { "args" => [candidate.id] },
          exception
        )

        candidate.reload
        expect(candidate.import_status).to eq('failed')
      end

      it 'does not enqueue UpdateCandidateJob' do
        expect(Resume::UpdateCandidateJob).not_to receive(:perform_async)

        begin
          job.perform(candidate.id)
        rescue StandardError
          # Expected
        end
      end

      it 'raises an error for Sidekiq retry' do
        expect {
          job.perform(candidate.id)
        }.to raise_error(StandardError)
      end
    end

    context 'when LLM analysis raises an error' do
      before do
        allow(Resume::Analyse).to receive(:call).and_raise(StandardError.new('API timeout'))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with("Candidate #{candidate.id}: LLM analysis failed: API timeout")
        expect(Rails.logger).to receive(:error).with(anything) # backtrace

        expect {
          job.perform(candidate.id)
        }.to raise_error(StandardError, 'API timeout')
      end

      it 'does not mark candidate as failed during perform (stays pending for retry)' do
        begin
          job.perform(candidate.id)
        rescue StandardError
          # Expected
        end

        candidate.reload
        expect(candidate.import_status).not_to eq('failed')
      end

      it 'marks candidate as failed when retries are exhausted' do
        candidate.start_import_workflow!
        exception = StandardError.new('API timeout')
        described_class.sidekiq_retries_exhausted_block.call(
          { "args" => [candidate.id] },
          exception
        )

        candidate.reload
        expect(candidate.import_status).to eq('failed')
      end

      it 'raises the error for Sidekiq retry' do
        expect {
          job.perform(candidate.id)
        }.to raise_error(StandardError, 'API timeout')
      end

      it 'preserves any previously cached LLM result' do
        candidate.update_column(:llm_analysis_result, { "previous" => "cache" })

        begin
          job.perform(candidate.id)
        rescue StandardError
          # Expected
        end

        candidate.reload
        expect(candidate.llm_analysis_result).to eq({ "previous" => "cache" })
      end
    end

    context 'when candidate is not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          job.perform(999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
