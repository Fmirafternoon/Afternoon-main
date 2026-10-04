require 'rails_helper'

RSpec.describe WeeklyDigestJob, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    let!(:customer_with_alerts) { create(:user, :customer, email: 'alerts@example.com') }
    let!(:customer_without_alerts) { create(:user, :customer, email: 'no-alerts@example.com') }
    let!(:non_customer) { create(:user, :agent_user) }

    let!(:enabled_search1) do
      create(:saved_search, 
        customer: customer_with_alerts, 
        email_alerts_enabled: true,
        last_alert_sent_at: 2.weeks.ago
      )
    end

    let!(:enabled_search2) do
      create(:saved_search, 
        customer: customer_with_alerts, 
        email_alerts_enabled: true,
        last_alert_sent_at: nil
      )
    end

    let!(:disabled_search) do
      create(:saved_search, 
        customer: customer_with_alerts, 
        email_alerts_enabled: false
      )
    end

    let!(:recent_alert_search) do
      create(:saved_search, 
        customer: customer_with_alerts, 
        email_alerts_enabled: true,
        last_alert_sent_at: 3.days.ago
      )
    end

    let!(:other_customer_search) do
      create(:saved_search, 
        customer: customer_without_alerts, 
        email_alerts_enabled: false
      )
    end

    let(:new_candidates) { create_list(:candidate, 3, publication_status: :published) }
    let(:job) { described_class.new }

    before do
      candidates_relation = Candidate.where(id: new_candidates.map(&:id))
      empty_relation = Candidate.none
      
      # Default mock for all searches
      allow_any_instance_of(SavedSearch).to receive(:find_new_candidates).and_return(candidates_relation)
      
      # Override for recent_alert_search to return no candidates (realistic behavior)
      allow(recent_alert_search).to receive(:find_new_candidates).and_return(empty_relation)
    end

    it 'processes only customers with enabled alerts' do
      expect(job).to receive(:process_customer_digest).with(customer_with_alerts).once
      expect(job).not_to receive(:process_customer_digest).with(customer_without_alerts)
      expect(job).not_to receive(:process_customer_digest).with(non_customer)
      
      job.perform
    end

    describe 'processing customer digest' do
      before do
        allow(DigestMailer).to receive(:weekly_alert).and_return(double(deliver_later: true))
      end

      it 'sends digest email with correct data' do
        expect(DigestMailer).to receive(:weekly_alert).with(
          customer: customer_with_alerts,
          alerts_data: array_including(
            hash_including(
              search: enabled_search1,
              candidates: array_including(*new_candidates),
              total_count: 3
            ),
            hash_including(
              search: enabled_search2,
              candidates: array_including(*new_candidates),
              total_count: 3
            )
          )
        ).and_return(double(deliver_later: true))

        job.send(:process_customer_digest, customer_with_alerts)
      end

      it 'marks candidates as seen for enabled searches only' do
        job.send(:process_customer_digest, customer_with_alerts)
        
        # Check that viewed candidates were created for searches with alerts enabled
        expect(SavedSearchViewedCandidate.where(saved_search: enabled_search1).count).to eq(3)
        expect(SavedSearchViewedCandidate.where(saved_search: enabled_search2).count).to eq(3)
        
        # Disabled searches should not have candidates marked as viewed
        expect(SavedSearchViewedCandidate.where(saved_search: disabled_search).count).to eq(0)
      end

      it 'updates last_alert_sent_at for all enabled searches' do
        freeze_time do
          job.send(:process_customer_digest, customer_with_alerts)

          expect(enabled_search1.reload.last_alert_sent_at).to eq(Time.current)
          expect(enabled_search2.reload.last_alert_sent_at).to eq(Time.current)
          expect(recent_alert_search.reload.last_alert_sent_at).to eq(Time.current)
        end
      end

      it 'updates last_alert_sent_at timestamp' do
        freeze_time do
          job.send(:process_customer_digest, customer_with_alerts)

          # Just verify that last_alert_sent_at was updated
          expect(enabled_search1.reload.last_alert_sent_at).to eq(Time.current)
          expect(enabled_search2.reload.last_alert_sent_at).to eq(Time.current)
        end
      end

      context 'when no new candidates are found' do
        before do
          allow_any_instance_of(SavedSearch).to receive(:find_new_candidates)
            .and_return(Candidate.none)
        end

        it 'does not send email' do
          expect(DigestMailer).not_to receive(:weekly_alert)
          job.send(:process_customer_digest, customer_with_alerts)
        end

        it 'does not update last_alert_sent_at' do
          expect { job.send(:process_customer_digest, customer_with_alerts) }
            .not_to change { enabled_search1.reload.last_alert_sent_at }
        end
      end

      context 'when only some searches have new candidates' do
        before do
          # Override the general mock by being more specific
          # We need to mock at the instance level, not the class level
          allow(customer_with_alerts).to receive_message_chain(:saved_searches, :with_alerts_enabled).and_return([enabled_search1, enabled_search2])
          
          # Mock find_new_candidates for each search individually
          allow(enabled_search1).to receive(:find_new_candidates) do
            Candidate.where(id: new_candidates.map(&:id))
          end
          
          allow(enabled_search2).to receive(:find_new_candidates) do
            Candidate.none
          end
        end

        it 'includes only searches with candidates in the digest' do
          expect(DigestMailer).to receive(:weekly_alert) do |args|
            expect(args[:customer]).to eq(customer_with_alerts)
            expect(args[:alerts_data].size).to eq(1)
            expect(args[:alerts_data][0][:search]).to eq(enabled_search1)
            expect(args[:alerts_data][0][:total_count]).to eq(3)
          end.and_return(double(deliver_later: true))

          job.send(:process_customer_digest, customer_with_alerts)
        end
      end

      context 'when limiting candidates per search' do
        let(:many_candidates) { create_list(:candidate, 10, publication_status: :published) }

        before do
          allow_any_instance_of(SavedSearch).to receive(:find_new_candidates)
            .and_return(Candidate.where(id: many_candidates.map(&:id)))
        end

        it 'limits to 5 candidates per search in email' do
          expect(DigestMailer).to receive(:weekly_alert).with(
            customer: customer_with_alerts,
            alerts_data: array_including(
              hash_including(
                search: enabled_search1,
                candidates: having_attributes(size: 5),
                total_count: 10
              )
            )
          ).and_return(double(deliver_later: true))

          job.send(:process_customer_digest, customer_with_alerts)
        end

        it 'marks only the sent candidates as seen' do
          job.send(:process_customer_digest, customer_with_alerts)
          
          # Should only mark 5 candidates as viewed even though there are 10
          expect(SavedSearchViewedCandidate.where(saved_search: enabled_search1).count).to eq(5)
        end
      end

      context 'when an error occurs' do
        before do
          allow(DigestMailer).to receive(:weekly_alert).and_raise(StandardError, 'Email error')
          allow(Rails.logger).to receive(:error)
          allow(Sentry).to receive(:capture_exception) if defined?(Sentry)
        end

        it 'logs the error' do
          expect(Rails.logger).to receive(:error).with(/Erreur digest pour customer #{customer_with_alerts.id}/)
          job.send(:process_customer_digest, customer_with_alerts)
        end

        it 'captures exception in Sentry if available' do
          if defined?(Sentry)
            expect(Sentry).to receive(:capture_exception).with(instance_of(StandardError))
          end
          job.send(:process_customer_digest, customer_with_alerts)
        end

        it 'continues processing other customers' do
          customer2 = create(:user, :customer)
          create(:saved_search, customer: customer2, email_alerts_enabled: true)
          
          allow(job).to receive(:process_customer_digest).and_call_original
          allow(job).to receive(:process_customer_digest).with(customer_with_alerts).and_raise(StandardError)
          
          expect(job).to receive(:process_customer_digest).with(customer2)
          job.perform
        end
      end
    end

    describe 'performance considerations' do
      it 'uses find_each for batch processing' do
        expect(User).to receive(:joins).with(:saved_searches).and_call_original
        expect_any_instance_of(ActiveRecord::Relation).to receive(:find_each)
        job.perform
      end

      it 'queries distinct customers only once' do
        expect(User).to receive(:joins).once.and_call_original
        job.perform
      end
    end
  end
end