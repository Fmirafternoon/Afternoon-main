require 'rails_helper'

RSpec.describe Resume::BatchImportCallback do
  let(:callback) { described_class.new }
  let(:user) { create(:user, :agent_user) }
  let(:candidate_ids) { [1, 2, 3] }
  let(:status) { double('BatchStatus') }
  let(:options) { { "user_id" => user.id } }
  
  before do
    # Mock Redis
    stub_const('REDIS', double('Redis'))
    allow(REDIS).to receive(:lrange).and_return(candidate_ids.map(&:to_s))
    allow(REDIS).to receive(:del)
    
    # Mock mailer
    allow(AgentMailer).to receive(:import_complete).and_return(double(deliver_later: true))
    
    # Mock logger
    allow(Rails.logger).to receive(:info)
  end

  describe '#on_success' do
    it 'retrieves candidate IDs from Redis' do
      expect(REDIS).to receive(:lrange).with("agent:#{user.id}:active_candidates_import", 0, -1)
      callback.on_success(status, options)
    end

    it 'sends import complete email' do
      expect(AgentMailer).to receive(:import_complete).with(user.id, candidate_ids.map(&:to_s))
      callback.on_success(status, options)
    end

    it 'delivers email later' do
      mail_double = double('Mail')
      allow(AgentMailer).to receive(:import_complete).and_return(mail_double)
      expect(mail_double).to receive(:deliver_later)
      callback.on_success(status, options)
    end

    it 'logs import completion' do
      expect(Rails.logger).to receive(:info).with("Import batch terminé pour l'utilisateur #{user.id}")
      callback.on_success(status, options)
    end

    it 'deletes the batch candidates key from Redis' do
      expect(REDIS).to receive(:del).with("agent:#{user.id}:active_candidates_import")
      callback.on_success(status, options)
    end

    it 'deletes the active batch key from Redis' do
      expect(REDIS).to receive(:del).with("agent:#{user.id}:active_import_batch")
      callback.on_success(status, options)
    end

    it 'finds the user by ID' do
      expect(User).to receive(:find).with(user.id).and_return(user)
      callback.on_success(status, options)
    end

    context 'with string user_id' do
      let(:options) { { "user_id" => user.id.to_s } }
      
      it 'still finds the user' do
        expect(User).to receive(:find).with(user.id.to_s).and_return(user)
        callback.on_success(status, options)
      end
    end

    context 'when no candidates in Redis' do
      before do
        allow(REDIS).to receive(:lrange).and_return([])
      end

      it 'sends email with empty candidate list' do
        expect(AgentMailer).to receive(:import_complete).with(user.id, [])
        callback.on_success(status, options)
      end
    end

    context 'with multiple candidates' do
      let(:candidate_ids) { [10, 20, 30, 40, 50] }
      
      before do
        allow(REDIS).to receive(:lrange).and_return(candidate_ids.map(&:to_s))
      end

      it 'passes all candidate IDs to mailer' do
        expect(AgentMailer).to receive(:import_complete).with(user.id, candidate_ids.map(&:to_s))
        callback.on_success(status, options)
      end
    end

    context 'when user not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        allow(User).to receive(:find).and_raise(ActiveRecord::RecordNotFound)
        expect {
          callback.on_success(status, options)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'execution order' do
      it 'retrieves candidates before sending email' do
        call_order = []
        
        allow(REDIS).to receive(:lrange) do
          call_order << :lrange
          candidate_ids.map(&:to_s)
        end
        
        allow(AgentMailer).to receive(:import_complete) do
          call_order << :mail
          double(deliver_later: true)
        end
        
        callback.on_success(status, options)
        expect(call_order).to eq([:lrange, :mail])
      end

      it 'sends email before deleting Redis keys' do
        call_order = []
        
        allow(AgentMailer).to receive(:import_complete) do
          call_order << :mail
          double(deliver_later: true)
        end
        
        allow(REDIS).to receive(:del) do |key|
          call_order << :del
        end
        
        callback.on_success(status, options)
        expect(call_order).to eq([:mail, :del, :del])
      end
    end
  end

  describe 'Redis key structure' do
    it 'uses correct active batch key format' do
      expect(REDIS).to receive(:del).with("agent:#{user.id}:active_import_batch")
      callback.on_success(status, options)
    end

    it 'uses correct candidates import key format' do
      expect(REDIS).to receive(:del).with("agent:#{user.id}:active_candidates_import")
      callback.on_success(status, options)
    end
  end

  describe 'error handling' do
    context 'when Redis operations fail' do
      it 'does not rescue Redis errors' do
        allow(REDIS).to receive(:lrange).and_raise(Redis::BaseError.new('Connection lost'))
        expect {
          callback.on_success(status, options)
        }.to raise_error(Redis::BaseError)
      end
    end

    context 'when mailer fails' do
      it 'does not rescue mailer errors' do
        allow(AgentMailer).to receive(:import_complete).and_raise(StandardError.new('Mail error'))
        expect {
          callback.on_success(status, options)
        }.to raise_error(StandardError, 'Mail error')
      end
    end
  end
end