require 'rails_helper'

RSpec.describe Resume::UpsertBatch do
  let(:user) { create(:user, :agent_user) }
  let(:candidate) { create(:candidate, agent: user) }
  let(:actor_result) { described_class.call(candidate: candidate, user: user) }
  
  # Mock Redis and Sidekiq::Batch
  let(:redis_mock) { double('Redis') }
  let(:batch_mock) { double('Sidekiq::Batch', bid: 'test-batch-id') }
  
  before do
    stub_const('REDIS', redis_mock)
    allow(Sidekiq::Batch).to receive(:new).and_return(batch_mock)
    allow(batch_mock).to receive(:description=)
    allow(batch_mock).to receive(:on)
    allow(batch_mock).to receive(:jobs).and_yield
    allow(Resume::AnalyseLlmJob).to receive(:perform_async)
  end

  describe '#call' do
    context 'when there is no active batch' do
      before do
        allow(redis_mock).to receive(:get).with("agent:#{user.id}:active_import_batch").and_return(nil)
        allow(redis_mock).to receive(:setex)
        allow(redis_mock).to receive(:rpush)
      end

      it 'sets candidate to import_pending state' do
        expect(candidate).to receive(:import_pending!)
        actor_result
      end

      it 'creates a new Sidekiq batch' do
        expect(Sidekiq::Batch).to receive(:new).with(no_args).and_return(batch_mock)
        actor_result
      end

      it 'sets batch description' do
        expect(batch_mock).to receive(:description=).with("Import batch for user #{user.id}")
        actor_result
      end

      it 'sets batch callback' do
        expect(batch_mock).to receive(:on).with(:success, Resume::BatchImportCallback, { user_id: user.id })
        actor_result
      end

      it 'enqueues Resume::AnalyseLlmJob' do
        expect(Resume::AnalyseLlmJob).to receive(:perform_async).with(candidate.id)
        actor_result
      end

      it 'stores batch ID in Redis with 10 minute expiration' do
        expect(redis_mock).to receive(:setex).with(
          "agent:#{user.id}:active_import_batch",
          600, # 10 minutes in seconds
          'test-batch-id'
        )
        actor_result
      end

      it 'adds candidate ID to batch candidates list' do
        expect(redis_mock).to receive(:rpush).with(
          "agent:#{user.id}:active_candidates_import",
          candidate.id
        )
        actor_result
      end
    end

    context 'when there is an active batch' do
      let(:existing_batch_id) { 'existing-batch-123' }
      let(:existing_batch_mock) { double('Sidekiq::Batch') }
      
      before do
        allow(redis_mock).to receive(:get).with("agent:#{user.id}:active_import_batch").and_return(existing_batch_id)
        allow(Sidekiq::Batch).to receive(:new).with(existing_batch_id).and_return(existing_batch_mock)
        allow(existing_batch_mock).to receive(:jobs).and_yield
        allow(redis_mock).to receive(:rpush)
      end

      it 'sets candidate to import_pending state' do
        expect(candidate).to receive(:import_pending!)
        actor_result
      end

      it 'uses existing batch' do
        expect(Sidekiq::Batch).to receive(:new).with(existing_batch_id).and_return(existing_batch_mock)
        expect(Sidekiq::Batch).not_to receive(:new).with(no_args)
        actor_result
      end

      it 'does not set batch description or callback' do
        expect(existing_batch_mock).not_to receive(:description=)
        expect(existing_batch_mock).not_to receive(:on)
        actor_result
      end

      it 'enqueues Resume::AnalyseLlmJob in existing batch' do
        expect(Resume::AnalyseLlmJob).to receive(:perform_async).with(candidate.id)
        actor_result
      end

      it 'does not create new batch in Redis' do
        expect(redis_mock).not_to receive(:setex)
        actor_result
      end

      it 'adds candidate ID to batch candidates list' do
        expect(redis_mock).to receive(:rpush).with(
          "agent:#{user.id}:active_candidates_import",
          candidate.id
        )
        actor_result
      end
    end

    context 'with different users' do
      let(:other_user) { create(:user, :agent_user) }
      let(:other_candidate) { create(:candidate, agent: other_user) }
      
      before do
        allow(redis_mock).to receive(:get).and_return(nil)
        allow(redis_mock).to receive(:setex)
        allow(redis_mock).to receive(:rpush)
      end

      it 'creates separate batches for different users' do
        # First user's batch
        expect(redis_mock).to receive(:get).with("agent:#{user.id}:active_import_batch").and_return(nil)
        expect(redis_mock).to receive(:setex).with("agent:#{user.id}:active_import_batch", 600, anything)
        expect(redis_mock).to receive(:rpush).with("agent:#{user.id}:active_candidates_import", candidate.id)
        
        described_class.call(candidate: candidate, user: user)
        
        # Second user's batch
        expect(redis_mock).to receive(:get).with("agent:#{other_user.id}:active_import_batch").and_return(nil)
        expect(redis_mock).to receive(:setex).with("agent:#{other_user.id}:active_import_batch", 600, anything)
        expect(redis_mock).to receive(:rpush).with("agent:#{other_user.id}:active_candidates_import", other_candidate.id)
        
        described_class.call(candidate: other_candidate, user: other_user)
      end
    end

    context 'when candidate import state change fails' do
      before do
        allow(redis_mock).to receive(:get).and_return(nil)
        allow(candidate).to receive(:import_pending!).and_raise(StandardError, "State transition error")
      end

      it 'raises the error' do
        expect { actor_result }.to raise_error(StandardError, "State transition error")
      end

      it 'does not create batch or enqueue job' do
        expect(Sidekiq::Batch).not_to receive(:new)
        expect(Resume::AnalyseLlmJob).not_to receive(:perform_async)
        expect(redis_mock).not_to receive(:setex)
        expect(redis_mock).not_to receive(:rpush)

        expect { actor_result }.to raise_error(StandardError)
      end
    end
  end
end