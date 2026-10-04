require 'rails_helper'

RSpec.describe CandidateAutoExpirationJob, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    let!(:expired_candidate1) do
      create(:candidate,
             publication_status: :published,
             published_at: 15.days.ago,
             expires_at: 1.day.ago,
             expiration_notified_at: 3.days.ago)
    end

    let!(:expired_candidate2) do
      create(:candidate,
             publication_status: :published,
             published_at: 20.days.ago,
             expires_at: 5.days.ago,
             expiration_notified_at: 7.days.ago)
    end

    let!(:not_yet_expired) do
      create(:candidate,
             publication_status: :published,
             published_at: 12.days.ago,
             expires_at: 2.days.from_now,
             expiration_notified_at: nil)
    end

    # Recently expired without notification - should NOT be expired (grace period)
    let!(:expired_not_notified_recent) do
      create(:candidate,
             publication_status: :published,
             published_at: 15.days.ago,
             expires_at: 1.day.ago,
             expiration_notified_at: nil)
    end

    # Old expired without notification - SHOULD be expired (fallback after 7 days)
    let!(:expired_not_notified_old) do
      create(:candidate,
             publication_status: :published,
             published_at: 25.days.ago,
             expires_at: 10.days.ago,
             expiration_notified_at: nil)
    end

    let!(:draft_candidate) do
      create(:candidate, publication_status: :draft)
    end

    it 'expires only candidates that are expired and notified' do
      described_class.new.perform

      expect(expired_candidate1.reload).to be_draft
      expect(expired_candidate1.reload.published_at).to be_nil
      expect(expired_candidate1.reload.expires_at).to be_nil
      expect(expired_candidate1.reload.expiration_notified_at).to be_nil

      expect(expired_candidate2.reload).to be_draft
      expect(expired_candidate2.reload.published_at).to be_nil
      expect(expired_candidate2.reload.expires_at).to be_nil
      expect(expired_candidate2.reload.expiration_notified_at).to be_nil
    end

    it 'does not expire candidates that are not yet expired' do
      described_class.new.perform

      expect(not_yet_expired.reload).to be_published
      expect(not_yet_expired.reload.expires_at).to be_present
    end

    it 'does not expire recently expired candidates without notification (grace period)' do
      described_class.new.perform

      expect(expired_not_notified_recent.reload).to be_published
    end

    it 'expires old candidates without notification (fallback after 7 days)' do
      described_class.new.perform

      expect(expired_not_notified_old.reload).to be_draft
    end

    it 'does not affect draft candidates' do
      described_class.new.perform

      expect(draft_candidate.reload).to be_draft
    end

    context 'when no candidates are expired' do
      before do
        Candidate.expired.each { |c| c.update(expires_at: 2.days.from_now) }
      end

      it 'does not change any candidates' do
        expect do
          described_class.new.perform
        end.not_to change { Candidate.published.count }
      end
    end

    context 'when an error occurs' do
      before do
        allow_any_instance_of(Candidate).to receive(:expire_workflow!).and_raise(StandardError, 'State machine error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and continues processing' do
        expect(Rails.logger).to receive(:error).at_least(:once)
        expect { described_class.new.perform }.not_to raise_error
      end

      it 'continues processing other candidates after an error' do
        # Both candidates are in the expired scope
        # First candidate will raise error, but second should still be processed

        # Mock the first candidate to raise an error
        allow_any_instance_of(Candidate).to receive(:expire_workflow!).and_call_original
        allow(expired_candidate1).to receive(:may_expire_workflow?).and_return(true)
        allow(expired_candidate1).to receive(:expire_workflow!).and_raise(StandardError)

        described_class.new.perform

        # expired_candidate2 should still be processed despite the error on expired_candidate1
        expect(expired_candidate2.reload).to be_draft
      end
    end

    describe 'state machine integration' do
      it 'uses expire_workflow transition' do
        expect(expired_candidate1).to receive(:expire_workflow!)

        relation_double = double('ActiveRecord::Relation')
        allow(relation_double).to receive(:find_each) do |&block|
          [expired_candidate1].each(&block)
        end
        allow(Candidate).to receive(:expired).and_return(relation_double)

        described_class.new.perform
      end

      it 'checks may_expire_workflow? before transitioning' do
        expect(expired_candidate1).to receive(:may_expire_workflow?).and_return(true)

        relation_double = double('ActiveRecord::Relation')
        allow(relation_double).to receive(:find_each) do |&block|
          [expired_candidate1].each(&block)
        end
        allow(Candidate).to receive(:expired).and_return(relation_double)

        described_class.new.perform
      end
    end
  end
end
