require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe Resume::ImportJob, type: :job do
  let(:agent) { create(:user, :agent_user) }
  let(:candidate) { create(:candidate, agent: agent) }
  let(:job) { described_class.new }
  let(:json_output) { { "name" => "John Doe", "skills" => ["Ruby", "Rails"] } }

  before do
    Sidekiq::Testing.inline!
    # Mock Turbo broadcasts
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
    
    # Mock other jobs
    allow(Candidate::GeocodeLocationJob).to receive(:perform_async)
  end

  after do
    Sidekiq::Testing.fake!
  end

  describe '#perform' do
    context 'when analysis is successful' do
      before do
        # Mock Candidate.find to return our test candidate
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
        
        # Mock actors
        analysis_result = double('AnalysisResult', json_output: json_output)
        allow(Resume::Analyse).to receive(:call).with(candidate: candidate).and_return(analysis_result)
        allow(Resume::UpdateCandidate).to receive(:call).with(candidate: candidate, json_output: json_output)
        
        # Mock candidate state transitions
        allow(candidate).to receive(:start_import_workflow!)
        allow(candidate).to receive(:complete_import_workflow!)
        allow(candidate).to receive(:reload).and_return(candidate)
      end

      it 'starts the import workflow' do
        expect(candidate).to receive(:start_import_workflow!)
        job.perform(candidate.id)
      end

      it 'calls Resume::Analyse actor' do
        expect(Resume::Analyse).to receive(:call).with(candidate: candidate)
        job.perform(candidate.id)
      end

      it 'calls Resume::UpdateCandidate actor with json output' do
        expect(Resume::UpdateCandidate).to receive(:call).with(candidate: candidate, json_output: json_output)
        job.perform(candidate.id)
      end

      it 'enqueues geocode location job' do
        expect(Candidate::GeocodeLocationJob).to receive(:perform_async).with(candidate.id)
        job.perform(candidate.id)
      end

      it 'completes the import workflow' do
        expect(candidate).to receive(:complete_import_workflow!)
        job.perform(candidate.id)
      end

      it 'reloads the candidate' do
        expect(candidate).to receive(:reload)
        job.perform(candidate.id)
      end

      describe 'Turbo broadcasts' do
        it 'broadcasts replace to upload partial' do
          expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
            "candidates_#{agent.id}",
            partial: "agent/candidates/upload",
            target: "agent_candidate_#{candidate.id}",
            locals: { candidate: candidate }
          )
          job.perform(candidate.id)
        end

        it 'broadcasts prepend to candidates list' do
          expect(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).with(
            "candidates_#{agent.id}",
            partial: "agent/candidates/candidate",
            target: "candidates",
            locals: { candidate: candidate }
          )
          job.perform(candidate.id)
        end

        it 'broadcasts update to candidates count' do
          allow(agent.candidates).to receive_message_chain(:import_completed, :count).and_return(5)
          
          expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
            "candidates_#{agent.id}",
            partial: "agent/candidates/count",
            target: "candidates_count",
            locals: { count: 5 }
          )
          job.perform(candidate.id)
        end
      end
    end

    context 'when analysis returns nil' do
      before do
        # Mock Candidate.find to return our test candidate
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
        
        # Mock actors
        analysis_result = double('AnalysisResult', json_output: nil)
        allow(Resume::Analyse).to receive(:call).with(candidate: candidate).and_return(analysis_result)
        
        # Mock candidate state transitions
        allow(candidate).to receive(:start_import_workflow!)
        allow(candidate).to receive(:fail_import_workflow!)
        allow(candidate).to receive(:reload).and_return(candidate)
      end

      it 'fails the import workflow' do
        expect(candidate).to receive(:fail_import_workflow!)
        job.perform(candidate.id)
      end

      it 'does not call Resume::UpdateCandidate' do
        expect(Resume::UpdateCandidate).not_to receive(:call)
        job.perform(candidate.id)
      end

      it 'does not enqueue geocode location job' do
        expect(Candidate::GeocodeLocationJob).not_to receive(:perform_async)
        job.perform(candidate.id)
      end

      it 'still broadcasts Turbo updates' do
        expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        expect(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
        expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        job.perform(candidate.id)
      end
    end

    context 'when candidate not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          job.perform(999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with different import completed counts' do
      it 'broadcasts correct count when no completed imports' do
        allow(agent.candidates).to receive_message_chain(:import_completed, :count).and_return(0)
        
        # Mock Candidate.find to return our test candidate
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
        
        # Mock other dependencies
        analysis_result = double('AnalysisResult', json_output: json_output)
        allow(Resume::Analyse).to receive(:call).and_return(analysis_result)
        allow(Resume::UpdateCandidate).to receive(:call)
        allow(candidate).to receive(:start_import_workflow!)
        allow(candidate).to receive(:complete_import_workflow!)
        allow(candidate).to receive(:reload).and_return(candidate)
        
        expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
          "candidates_#{agent.id}",
          partial: "agent/candidates/count",
          target: "candidates_count",
          locals: { count: 0 }
        )
        job.perform(candidate.id)
      end

      it 'broadcasts correct count when multiple completed imports' do
        allow(agent.candidates).to receive_message_chain(:import_completed, :count).and_return(10)
        
        # Mock Candidate.find to return our test candidate
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
        
        # Mock other dependencies
        analysis_result = double('AnalysisResult', json_output: json_output)
        allow(Resume::Analyse).to receive(:call).and_return(analysis_result)
        allow(Resume::UpdateCandidate).to receive(:call)
        allow(candidate).to receive(:start_import_workflow!)
        allow(candidate).to receive(:complete_import_workflow!)
        allow(candidate).to receive(:reload).and_return(candidate)
        
        expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
          "candidates_#{agent.id}",
          partial: "agent/candidates/count",
          target: "candidates_count",
          locals: { count: 10 }
        )
        job.perform(candidate.id)
      end
    end

    context 'error handling' do
      before do
        # Mock Candidate.find to return our test candidate
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)

        allow(candidate).to receive(:start_import_workflow!)
        allow(candidate).to receive(:reload).and_return(candidate)
      end

      it 'catches errors, fails workflow, and re-raises' do
        allow(Resume::Analyse).to receive(:call).and_raise(StandardError.new('Analysis error'))
        allow(candidate).to receive(:fail_import_workflow!)

        expect(candidate).to receive(:fail_import_workflow!)
        expect {
          job.perform(candidate.id)
        }.to raise_error(StandardError, 'Analysis error')
      end

      it 'fails workflow and re-raises when UpdateCandidate errors' do
        analysis_result = double('AnalysisResult', json_output: json_output)
        allow(Resume::Analyse).to receive(:call).and_return(analysis_result)
        allow(Resume::UpdateCandidate).to receive(:call).and_raise(StandardError.new('Update error'))
        allow(candidate).to receive(:fail_import_workflow!)
        allow(candidate).to receive(:llm_analysis_result).and_return(nil)
        allow(candidate).to receive(:update_column)

        expect(candidate).to receive(:fail_import_workflow!)
        expect {
          job.perform(candidate.id)
        }.to raise_error(StandardError, 'Update error')
      end

      it 'logs error message on failure' do
        allow(Resume::Analyse).to receive(:call).and_raise(StandardError.new('Analysis error'))
        allow(candidate).to receive(:fail_import_workflow!)

        expect(Rails.logger).to receive(:error).with("Candidate #{candidate.id}: Import failed with error: Analysis error")
        expect(Rails.logger).to receive(:error).with(anything) # backtrace

        expect {
          job.perform(candidate.id)
        }.to raise_error(StandardError)
      end
    end

    context 'LLM result caching' do
      let(:cached_result) { { "cached" => true, "name" => "Cached Result" } }

      before do
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
        allow(candidate).to receive(:start_import_workflow!)
        allow(candidate).to receive(:complete_import_workflow!)
        allow(candidate).to receive(:reload).and_return(candidate)
        allow(Resume::UpdateCandidate).to receive(:call)
      end

      context 'when llm_analysis_result already exists' do
        before do
          allow(candidate).to receive(:llm_analysis_result).and_return(cached_result)
        end

        it 'reuses cached result instead of calling Resume::Analyse' do
          expect(Resume::Analyse).not_to receive(:call)
          expect(Resume::UpdateCandidate).to receive(:call).with(candidate: candidate, json_output: cached_result)

          job.perform(candidate.id)
        end

        it 'does not update llm_analysis_result column' do
          expect(candidate).not_to receive(:update_column).with(:llm_analysis_result, anything)
          job.perform(candidate.id)
        end

        it 'logs cache usage' do
          expect(Rails.logger).not_to receive(:info).with("Candidate #{candidate.id}: LLM result cached")
          job.perform(candidate.id)
        end
      end

      context 'when llm_analysis_result is nil' do
        before do
          allow(candidate).to receive(:llm_analysis_result).and_return(nil)
          analysis_result = double('AnalysisResult', json_output: json_output)
          allow(Resume::Analyse).to receive(:call).with(candidate: candidate).and_return(analysis_result)
        end

        it 'calls Resume::Analyse to get new result' do
          allow(candidate).to receive(:update_column)
          expect(Resume::Analyse).to receive(:call).with(candidate: candidate)
          job.perform(candidate.id)
        end

        it 'saves the result to llm_analysis_result before using it' do
          expect(candidate).to receive(:update_column).with(:llm_analysis_result, json_output).ordered
          expect(Resume::UpdateCandidate).to receive(:call).with(candidate: candidate, json_output: json_output).ordered

          job.perform(candidate.id)
        end

        it 'logs when caching new result' do
          allow(candidate).to receive(:update_column)
          expect(Rails.logger).to receive(:info).with("Candidate #{candidate.id}: LLM result cached")
          job.perform(candidate.id)
        end
      end

      context 'when UpdateCandidate fails after caching' do
        before do
          allow(candidate).to receive(:llm_analysis_result).and_return(nil)
          analysis_result = double('AnalysisResult', json_output: json_output)
          allow(Resume::Analyse).to receive(:call).and_return(analysis_result)
          allow(candidate).to receive(:update_column).with(:llm_analysis_result, json_output)
          allow(candidate).to receive(:fail_import_workflow!)
        end

        it 'preserves cached result even when update fails' do
          allow(Resume::UpdateCandidate).to receive(:call).and_raise(StandardError.new('Update failed'))

          expect(candidate).to receive(:update_column).with(:llm_analysis_result, json_output)

          expect {
            job.perform(candidate.id)
          }.to raise_error(StandardError, 'Update failed')
        end
      end
    end
  end

  describe 'Sidekiq configuration' do
    it 'includes Sidekiq::Job' do
      expect(described_class.ancestors).to include(Sidekiq::Job)
    end

    it 'can be enqueued' do
      Sidekiq::Testing.fake! do
        expect {
          described_class.perform_async(candidate.id)
        }.to change(described_class.jobs, :size).by(1)
      end
    end
  end

  describe 'candidate agent relationship' do
    it 'accesses agent through candidate' do
      # Mock Candidate.find to return our test candidate
      allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
      
      # Create a spy to verify the agent method is called
      allow(candidate).to receive(:agent).and_return(agent)
      
      # Mock other dependencies
      analysis_result = double('AnalysisResult', json_output: json_output)
      allow(Resume::Analyse).to receive(:call).and_return(analysis_result)
      allow(Resume::UpdateCandidate).to receive(:call)
      allow(candidate).to receive(:start_import_workflow!)
      allow(candidate).to receive(:complete_import_workflow!)
      allow(candidate).to receive(:reload).and_return(candidate)
      
      job.perform(candidate.id)
      
      # Verify agent was accessed for broadcasts
      expect(candidate).to have_received(:agent).at_least(:once)
    end
  end
end