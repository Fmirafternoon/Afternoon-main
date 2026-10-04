require 'rails_helper'

RSpec.describe 'Candidate Import with LLM Caching', type: :integration do
  let(:agent) { create(:user, :agent_user) }
  let(:candidate) { create(:candidate, agent: agent) }

  let(:llm_analysis_result) do
    {
      "first_name" => "John",
      "last_name" => "Doe",
      "position" => "Software Developer",
      "gender" => "male",
      "skills" => [
        { "label" => "Ruby", "semantic" => "Programming language" }
      ]
    }
  end

  before do
    # Mock external dependencies
    allow(Resume::EmbedJob).to receive(:perform_async)
    allow(Candidate::GeocodeLocationJob).to receive(:perform_async)

    # Mock Turbo broadcasts to avoid errors
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
  end

  describe 'LLM result caching behavior' do
    context 'when importing a candidate for the first time' do
      it 'calls the LLM and caches the result' do
        # Mock LLM response
        analysis_result = double('AnalysisResult', json_output: llm_analysis_result)
        expect(Resume::Analyse).to receive(:call)
          .with(candidate: candidate)
          .and_return(analysis_result)

        # Execute the job
        Resume::ImportJob.new.perform(candidate.id)

        # Verify LLM result was cached
        candidate.reload
        expect(candidate.llm_analysis_result).to eq(llm_analysis_result)
        expect(candidate.import_status).to eq('completed')
        expect(candidate.first_name).to eq('John')
        expect(candidate.last_name).to eq('Doe')
      end
    end

    context 'when importing a candidate with cached LLM result' do
      before do
        # Pre-populate the cache
        candidate.update_column(:llm_analysis_result, llm_analysis_result)
        candidate.start_import_workflow!
      end

      it 'reuses cached result without calling the LLM' do
        # Ensure LLM is NOT called
        expect(Resume::Analyse).not_to receive(:call)

        # Execute the job
        Resume::ImportJob.new.perform(candidate.id)

        # Verify candidate was updated from cache
        candidate.reload
        expect(candidate.import_status).to eq('completed')
        expect(candidate.first_name).to eq('John')
        expect(candidate.last_name).to eq('Doe')
      end
    end

    context 'when import fails after LLM analysis' do
      it 'preserves the LLM cache for retry' do
        # Mock LLM response
        analysis_result = double('AnalysisResult', json_output: llm_analysis_result)
        allow(Resume::Analyse).to receive(:call)
          .with(candidate: candidate)
          .and_return(analysis_result)

        # Mock UpdateCandidate to fail
        allow(Resume::UpdateCandidate).to receive(:call).and_raise(StandardError.new('Update failed'))

        # Execute the job (should raise error)
        expect {
          Resume::ImportJob.new.perform(candidate.id)
        }.to raise_error(StandardError, 'Update failed')

        # Verify LLM result was cached despite the failure
        candidate.reload
        expect(candidate.llm_analysis_result).to eq(llm_analysis_result)
        expect(candidate.import_status).to eq('failed')
      end

      it 'can retry successfully using cached result' do
        # Pre-populate cache and set to failed state
        candidate.update_column(:llm_analysis_result, llm_analysis_result)
        candidate.update_column(:import_status, 'failed')

        # On retry, LLM should NOT be called
        expect(Resume::Analyse).not_to receive(:call)

        # Execute the job again (retry)
        Resume::ImportJob.new.perform(candidate.id)

        # Verify successful retry using cache
        candidate.reload
        expect(candidate.import_status).to eq('completed')
        expect(candidate.first_name).to eq('John')
      end
    end
  end

  describe 'Transaction rollback behavior' do
    it 'demonstrates transaction atomicity by mocking UpdateCandidate failure' do
      # Set initial state
      candidate.update!(first_name: 'Original', position: 'Original Position')

      # Mock LLM response
      analysis_result = double('AnalysisResult', json_output: llm_analysis_result)
      allow(Resume::Analyse).to receive(:call).and_return(analysis_result)

      # Mock Resume::UpdateCandidate to fail (simulating a transaction error)
      allow(Resume::UpdateCandidate).to receive(:call).and_raise(StandardError.new('Simulated transaction error'))

      # Execute should raise error
      expect {
        Resume::ImportJob.new.perform(candidate.id)
      }.to raise_error(StandardError, 'Simulated transaction error')

      # Verify candidate is marked as failed
      candidate.reload
      expect(candidate.import_status).to eq('failed')

      # LLM cache should still be preserved for retry
      expect(candidate.llm_analysis_result).to eq(llm_analysis_result)

      # Note: We can't verify rollback of candidate fields here since the update happens
      # in UpdateCandidate actor which is mocked. The actual transaction rollback behavior
      # is tested in the unit tests for Resume::UpdateCandidate
    end
  end

  describe 'Error handling and logging' do
    it 'logs errors and marks candidate as failed' do
      # Mock LLM to fail
      allow(Resume::Analyse).to receive(:call).and_raise(StandardError.new('LLM API error'))

      # Capture logs
      expect(Rails.logger).to receive(:error).with("Candidate #{candidate.id}: Import failed with error: LLM API error")
      expect(Rails.logger).to receive(:error).with(anything) # backtrace

      # Execute should raise error
      expect {
        Resume::ImportJob.new.perform(candidate.id)
      }.to raise_error(StandardError, 'LLM API error')

      # Verify candidate is marked as failed
      candidate.reload
      expect(candidate.import_status).to eq('failed')
    end
  end
end
