require 'rails_helper'

RSpec.describe 'Candidate Batch Import with LLM Retries', type: :integration do
  let(:agent) { create(:user, :agent_user) }
  let(:candidate1) { create(:candidate, agent: agent) }
  let(:candidate2) { create(:candidate, agent: agent) }
  let(:candidate3) { create(:candidate, agent: agent) }

  let(:llm_result1) do
    {
      "first_name" => "John",
      "last_name" => "Doe",
      "position" => "Developer"
    }
  end

  let(:llm_result2) do
    {
      "first_name" => "Jane",
      "last_name" => "Smith",
      "position" => "Designer"
    }
  end

  let(:llm_result3) do
    {
      "first_name" => "Bob",
      "last_name" => "Johnson",
      "position" => "Manager"
    }
  end

  before do
    # Mock external dependencies
    allow(Resume::EmbedJob).to receive(:perform_async)
    allow(Candidate::GeocodeLocationJob).to receive(:perform_async)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
    allow(AgentMailer).to receive_message_chain(:import_complete, :deliver_later)
  end

  describe 'Two-step import flow' do
    context 'when all LLM analyses succeed on first try' do
      it 'enqueues AnalyseLlmJob first, then UpdateCandidateJob' do
        # Mock Resume::Analyse to succeed
        allow(Resume::Analyse).to receive(:call) do |args|
          case args[:candidate].id
          when candidate1.id
            double('Result', json_output: llm_result1)
          when candidate2.id
            double('Result', json_output: llm_result2)
          when candidate3.id
            double('Result', json_output: llm_result3)
          end
        end

        # Execute AnalyseLlmJob for all candidates
        Resume::AnalyseLlmJob.new.perform(candidate1.id)
        Resume::AnalyseLlmJob.new.perform(candidate2.id)
        Resume::AnalyseLlmJob.new.perform(candidate3.id)

        # Verify LLM results are cached
        [candidate1, candidate2, candidate3].each(&:reload)
        expect(candidate1.llm_analysis_result).to eq(llm_result1)
        expect(candidate2.llm_analysis_result).to eq(llm_result2)
        expect(candidate3.llm_analysis_result).to eq(llm_result3)

        # All candidates should still be pending (waiting for UpdateCandidateJob)
        expect(candidate1.import_status).to eq('pending')
        expect(candidate2.import_status).to eq('pending')
        expect(candidate3.import_status).to eq('pending')

        # Execute UpdateCandidateJob for all candidates
        Resume::UpdateCandidateJob.new.perform(candidate1.id)
        Resume::UpdateCandidateJob.new.perform(candidate2.id)
        Resume::UpdateCandidateJob.new.perform(candidate3.id)

        # All candidates should now be completed
        [candidate1, candidate2, candidate3].each(&:reload)
        expect(candidate1.import_status).to eq('completed')
        expect(candidate2.import_status).to eq('completed')
        expect(candidate3.import_status).to eq('completed')

        # Verify candidate data was updated
        expect(candidate1.first_name).to eq('John')
        expect(candidate2.first_name).to eq('Jane')
        expect(candidate3.first_name).to eq('Bob')
      end
    end

    context 'when one LLM analysis fails and requires retry' do
      it 'retries the LLM job without affecting other candidates' do
        # Mock Resume::Analyse to fail for candidate2 first, then succeed
        call_count_candidate2 = 0
        allow(Resume::Analyse).to receive(:call) do |args|
          case args[:candidate].id
          when candidate1.id
            double('Result', json_output: llm_result1)
          when candidate2.id
            call_count_candidate2 += 1
            if call_count_candidate2 == 1
              raise StandardError.new('LLM API timeout')
            else
              double('Result', json_output: llm_result2)
            end
          when candidate3.id
            double('Result', json_output: llm_result3)
          end
        end

        # Execute AnalyseLlmJob - candidate1 and candidate3 succeed
        Resume::AnalyseLlmJob.new.perform(candidate1.id)
        Resume::AnalyseLlmJob.new.perform(candidate3.id)

        # candidate2 fails on first try — stays pending (not failed) for retry
        expect {
          Resume::AnalyseLlmJob.new.perform(candidate2.id)
        }.to raise_error(StandardError, 'LLM API timeout')

        candidate2.reload
        expect(candidate2.import_status).not_to eq('failed')
        expect(candidate2.llm_analysis_result).to be_nil

        # Retry candidate2 (simulating Sidekiq retry)
        Resume::AnalyseLlmJob.new.perform(candidate2.id)

        # Now candidate2 should succeed
        candidate2.reload
        expect(candidate2.import_status).to eq('pending') # Waiting for UpdateCandidateJob
        expect(candidate2.llm_analysis_result).to eq(llm_result2)

        # All candidates can now proceed to UpdateCandidateJob
        Resume::UpdateCandidateJob.new.perform(candidate1.id)
        Resume::UpdateCandidateJob.new.perform(candidate2.id)
        Resume::UpdateCandidateJob.new.perform(candidate3.id)

        # All should be completed now
        [candidate1, candidate2, candidate3].each(&:reload)
        expect(candidate1.import_status).to eq('completed')
        expect(candidate2.import_status).to eq('completed')
        expect(candidate3.import_status).to eq('completed')
      end
    end

    context 'when UpdateCandidateJob fails (no retry)' do
      it 'marks candidate as failed immediately without retry' do
        # Setup: LLM analysis succeeds, cache is populated
        allow(Resume::Analyse).to receive(:call).and_return(
          double('Result', json_output: llm_result1)
        )
        Resume::AnalyseLlmJob.new.perform(candidate1.id)

        candidate1.reload
        expect(candidate1.llm_analysis_result).to eq(llm_result1)

        # Mock Resume::UpdateCandidate to fail
        allow(Resume::UpdateCandidate).to receive(:call).and_raise(
          StandardError.new('Validation failed')
        )

        # Execute UpdateCandidateJob - should fail and NOT retry
        expect {
          Resume::UpdateCandidateJob.new.perform(candidate1.id)
        }.to raise_error(StandardError, 'Validation failed')

        candidate1.reload
        expect(candidate1.import_status).to eq('failed')

        # LLM cache is preserved for potential manual intervention
        expect(candidate1.llm_analysis_result).to eq(llm_result1)
      end
    end

    context 'when LLM fails permanently after all retries' do
      it 'marks candidate as failed and does not enqueue UpdateCandidateJob' do
        # Mock Resume::Analyse to always fail
        allow(Resume::Analyse).to receive(:call).and_raise(
          StandardError.new('LLM service unavailable')
        )

        # Each perform raises but does NOT mark the candidate as failed
        # (Sidekiq will retry automatically up to 5 times)
        expect {
          Resume::AnalyseLlmJob.new.perform(candidate1.id)
        }.to raise_error(StandardError, 'LLM service unavailable')

        candidate1.reload
        expect(candidate1.import_status).not_to eq('failed')

        # Simulate Sidekiq exhausting all retries
        candidate1.start_import_workflow!
        exception = StandardError.new('LLM service unavailable')
        Resume::AnalyseLlmJob.sidekiq_retries_exhausted_block.call(
          { "args" => [candidate1.id] },
          exception
        )

        # After all retries exhausted, candidate should be in failed state
        candidate1.reload
        expect(candidate1.import_status).to eq('failed')
        expect(candidate1.llm_analysis_result).to be_nil

        # UpdateCandidateJob should never be called
        expect(Resume::UpdateCandidateJob).not_to receive(:perform_async)
      end
    end

    context 'LLM cache reuse across retries' do
      it 'does not call LLM again if result is already cached' do
        # First attempt: LLM succeeds and caches result
        allow(Resume::Analyse).to receive(:call).and_return(
          double('Result', json_output: llm_result1)
        ).once # Should only be called ONCE

        Resume::AnalyseLlmJob.new.perform(candidate1.id)

        candidate1.reload
        expect(candidate1.llm_analysis_result).to eq(llm_result1)

        # Simulate retry (for whatever reason)
        # LLM should NOT be called again, cache should be reused
        Resume::AnalyseLlmJob.new.perform(candidate1.id)

        # Verify Resume::Analyse was only called once (in the first attempt)
        expect(Resume::Analyse).to have_received(:call).once
      end
    end
  end

  describe 'Sidekiq queue configuration' do
    it 'AnalyseLlmJob uses llm queue with 5 retries' do
      expect(Resume::AnalyseLlmJob.sidekiq_options_hash['queue']).to eq('llm')
      expect(Resume::AnalyseLlmJob.sidekiq_options_hash['retry']).to eq(5)
    end

    it 'UpdateCandidateJob uses default queue with 0 retries' do
      expect(Resume::UpdateCandidateJob.sidekiq_options_hash['queue']).to eq('default')
      expect(Resume::UpdateCandidateJob.sidekiq_options_hash['retry']).to eq(0)
    end
  end
end
