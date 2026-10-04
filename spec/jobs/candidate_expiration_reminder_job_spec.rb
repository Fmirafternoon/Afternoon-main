require 'rails_helper'

RSpec.describe CandidateExpirationReminderJob, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    let!(:expiring_candidate1) do
      create(:candidate,
             publication_status: :published,
             published_at: 12.days.ago,
             expires_at: 2.days.from_now,
             expiration_notified_at: nil)
    end

    let!(:expiring_candidate2) do
      create(:candidate,
             publication_status: :published,
             published_at: 12.days.ago,
             expires_at: 1.day.from_now,
             expiration_notified_at: nil)
    end

    let!(:already_notified) do
      create(:candidate,
             publication_status: :published,
             published_at: 12.days.ago,
             expires_at: 2.days.from_now,
             expiration_notified_at: 1.day.ago)
    end

    let!(:not_expiring_soon) do
      create(:candidate,
             publication_status: :published,
             published_at: 2.days.ago,
             expires_at: 12.days.from_now,
             expiration_notified_at: nil)
    end

    let!(:draft_candidate) do
      create(:candidate, publication_status: :draft)
    end

    before do
      allow(AgentMailer).to receive(:candidate_expiration_reminder).and_return(double(deliver_now: true))
    end

    it 'processes only candidates expiring soon' do
      expect(AgentMailer).to receive(:candidate_expiration_reminder).with(expiring_candidate1.id).once
      expect(AgentMailer).to receive(:candidate_expiration_reminder).with(expiring_candidate2.id).once
      expect(AgentMailer).not_to receive(:candidate_expiration_reminder).with(already_notified.id)
      expect(AgentMailer).not_to receive(:candidate_expiration_reminder).with(not_expiring_soon.id)
      expect(AgentMailer).not_to receive(:candidate_expiration_reminder).with(draft_candidate.id)

      described_class.new.perform
    end

    it 'marks candidates as notified' do
      described_class.new.perform

      expect(expiring_candidate1.reload.expiration_notified_at).to be_within(1.second).of(Time.current)
      expect(expiring_candidate2.reload.expiration_notified_at).to be_within(1.second).of(Time.current)
    end

    it 'does not update already notified candidates' do
      original_time = already_notified.expiration_notified_at
      described_class.new.perform

      expect(already_notified.reload.expiration_notified_at).to eq(original_time)
    end

    it 'enqueues mailer jobs' do
      expect(AgentMailer).to receive(:candidate_expiration_reminder).with(expiring_candidate1.id).and_return(double(deliver_now: true))
      expect(AgentMailer).to receive(:candidate_expiration_reminder).with(expiring_candidate2.id).and_return(double(deliver_now: true))

      described_class.new.perform
    end

    context 'when no candidates are expiring soon' do
      before do
        Candidate.expiring_soon.update_all(expiration_notified_at: Time.current)
      end

      it 'does not send any emails' do
        expect(AgentMailer).not_to receive(:candidate_expiration_reminder)
        described_class.new.perform
      end
    end

    context 'when an error occurs' do
      before do
        allow(AgentMailer).to receive(:candidate_expiration_reminder).and_raise(StandardError, 'Email error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and continues processing' do
        expect(Rails.logger).to receive(:error).at_least(:once)
        expect { described_class.new.perform }.not_to raise_error
      end
    end
  end
end
