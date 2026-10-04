require 'rails_helper'

RSpec.describe SavedSearch, type: :model do
  describe 'associations' do
    it { should belong_to(:customer).class_name('User').with_foreign_key('customer_id') }
    it { should have_one(:project) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:criteria) }

    describe 'uniqueness of name' do
      let(:customer) { create(:user, :customer) }
      let!(:existing_search) { create(:saved_search, customer: customer, name: 'My Search') }

      it 'validates uniqueness of name scoped to customer' do
        new_search = build(:saved_search, customer: customer, name: 'My Search')
        expect(new_search).not_to be_valid
        expect(new_search.errors[:name]).to include('est déjà utilisé(e)')
      end

      it 'allows same name for different customers' do
        other_customer = create(:user, :customer)
        new_search = build(:saved_search, customer: other_customer, name: 'My Search')
        expect(new_search).to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.ordered' do
      let(:customer) { create(:user, :customer) }
      let!(:search1) { create(:saved_search, customer: customer, created_at: 3.days.ago) }
      let!(:search2) { create(:saved_search, customer: customer, created_at: 1.day.ago, last_used_at: 2.hours.ago) }
      let!(:search3) { create(:saved_search, customer: customer, created_at: 2.days.ago, last_used_at: 1.hour.ago) }

      it 'orders by created_at desc' do
        expect(customer.saved_searches.ordered).to eq([search2, search3, search1])
      end
    end

    describe '.active' do
      let(:customer) { create(:user, :customer) }
      let!(:active_search) { create(:saved_search, customer: customer, archived: false) }
      let!(:archived_search) { create(:saved_search, customer: customer, archived: true) }

      it 'returns only non-archived searches' do
        expect(SavedSearch.active).to include(active_search)
        expect(SavedSearch.active).not_to include(archived_search)
      end
    end

    describe '.archived' do
      let(:customer) { create(:user, :customer) }
      let!(:active_search) { create(:saved_search, customer: customer, archived: false) }
      let!(:archived_search) { create(:saved_search, customer: customer, archived: true) }

      it 'returns only archived searches' do
        expect(SavedSearch.archived).to include(archived_search)
        expect(SavedSearch.archived).not_to include(active_search)
      end
    end
  end

  describe '#formatted_criteria' do
    let(:customer) { create(:user, :customer) }
    let(:sector1) { create(:sector, name: 'BTP') }
    let(:sector2) { create(:sector, name: 'Industrie') }

    context 'with all criteria' do
      let(:saved_search) do
        create(:saved_search,
          customer: customer,
          criteria: {
            'query' => 'développeur',
            'city' => 'Paris',
            'sector_ids' => [sector1.id, sector2.id],
            'skills' => ['Ruby', 'Rails']
          }
        )
      end

      it 'formats all criteria correctly' do
        expect(saved_search.formatted_criteria).to eq('développeur, Paris, BTP, Industrie, Ruby, Rails')
      end
    end

    context 'with partial criteria' do
      let(:saved_search) do
        create(:saved_search,
          customer: customer,
          criteria: {
            'query' => 'manager',
            'skills' => ['Leadership']
          }
        )
      end

      it 'formats only present criteria' do
        expect(saved_search.formatted_criteria).to eq('manager, Leadership')
      end
    end

    context 'with empty criteria' do
      let(:saved_search) do
        build(:saved_search,
          customer: customer,
          criteria: {}
        )
      end

      it 'returns empty string' do
        # Note: criteria validation might prevent empty criteria,
        # but the method should handle it gracefully
        expect(saved_search.formatted_criteria).to eq('')
      end
    end
  end

  describe '#touch_last_used_at!' do
    let(:saved_search) { create(:saved_search) }

    it 'updates last_used_at to current time' do
      freeze_time do
        expect { saved_search.touch_last_used_at! }
          .to change { saved_search.reload.last_used_at }
          .to(Time.current)
      end
    end
  end

  describe 'email alerts functionality' do
    let(:customer) { create(:user, :customer) }
    let(:saved_search) { create(:saved_search, customer: customer) }


    describe 'scopes' do
      describe '.with_alerts_enabled' do
        let!(:enabled_search) { create(:saved_search, email_alerts_enabled: true) }
        let!(:disabled_search) { create(:saved_search, email_alerts_enabled: false) }

        it 'returns only saved searches with alerts enabled' do
          expect(SavedSearch.with_alerts_enabled).to include(enabled_search)
          expect(SavedSearch.with_alerts_enabled).not_to include(disabled_search)
        end
      end

    end

    describe '#toggle_email_alerts!' do
      context 'when alerts are disabled' do
        let(:saved_search) { create(:saved_search, email_alerts_enabled: false) }

        it 'enables alerts' do
          expect { saved_search.toggle_email_alerts! }
            .to change { saved_search.reload.email_alerts_enabled }
            .from(false).to(true)
        end
      end

      context 'when alerts are enabled' do
        let(:saved_search) { create(:saved_search, email_alerts_enabled: true) }

        it 'disables alerts' do
          expect { saved_search.toggle_email_alerts! }
            .to change { saved_search.reload.email_alerts_enabled }
            .from(true).to(false)
        end
      end
    end

    describe '#mark_candidates_as_viewed' do
      let(:saved_search) { create(:saved_search) }
      let(:candidates) { create_list(:candidate, 3) }

      context 'with candidates' do
        it 'creates SavedSearchViewedCandidate records for all candidates' do
          expect { saved_search.mark_candidates_as_viewed(candidates) }
            .to change { SavedSearchViewedCandidate.count }
            .by(3)
          
          # Verify all candidates are marked as viewed
          candidates.each do |candidate|
            expect(SavedSearchViewedCandidate.exists?(
              saved_search: saved_search,
              candidate: candidate
            )).to be true
          end
        end

        it 'uses upsert to avoid duplicates' do
          # First call
          saved_search.mark_candidates_as_viewed(candidates)
          
          # Second call with same candidates
          expect { saved_search.mark_candidates_as_viewed(candidates) }
            .not_to change { SavedSearchViewedCandidate.count }
        end

        it 'sets viewed_at timestamp' do
          freeze_time do
            saved_search.mark_candidates_as_viewed(candidates)
            
            SavedSearchViewedCandidate.where(saved_search: saved_search).each do |record|
              expect(record.viewed_at).to eq(Time.current)
            end
          end
        end
      end

      context 'with empty candidates array' do
        it 'does not create any records' do
          expect { saved_search.mark_candidates_as_viewed([]) }
            .not_to change { SavedSearchViewedCandidate.count }
        end
      end
    end

    describe '#find_new_candidates' do
      let(:saved_search) { create(:saved_search, criteria: { 'query' => 'developer' }) }
      
      # Candidates with different publication states and creation dates
      let!(:old_published) { create(:candidate, publication_status: :published, created_at: 2.weeks.ago) }
      let!(:new_published) { create(:candidate, publication_status: :published, created_at: 1.day.ago) }
      let!(:old_draft) { create(:candidate, publication_status: :draft, created_at: 2.weeks.ago) }
      let!(:new_draft) { create(:candidate, publication_status: :draft, created_at: 1.day.ago) }
      let!(:viewed_candidate) { create(:candidate, publication_status: :published, created_at: 4.days.ago) }

      before do
        allow(Candidate::Search).to receive(:call).and_return(
          OpenStruct.new(candidates: Candidate.all)
        )
      end

      context 'when some candidates have been viewed' do
        before do
          SavedSearchViewedCandidate.create!(
            saved_search: saved_search,
            candidate: viewed_candidate,
            viewed_at: 2.days.ago
          )
        end

        it 'excludes viewed candidates' do
          result = saved_search.find_new_candidates
          expect(result).not_to include(viewed_candidate)
          # Should include only published candidates that haven't been viewed
          expect(result).to include(old_published, new_published)
          # Draft candidates should not be returned by the search
          expect(result).not_to include(old_draft, new_draft)
        end
      end

      context 'when last_alert_sent_at is present' do
        before do 
          saved_search.update!(last_alert_sent_at: 1.week.ago)
          # Mark viewed_candidate as viewed
          SavedSearchViewedCandidate.create!(
            saved_search: saved_search,
            candidate: viewed_candidate,
            viewed_at: 2.days.ago
          )
        end

        it 'returns only published candidates created after last alert' do
          result = saved_search.find_new_candidates
          # Should include only new published candidate
          expect(result).to include(new_published)
          # Should exclude: old published (created before last alert)
          expect(result).not_to include(old_published)
          # viewed_candidate should be excluded because it's viewed
          expect(result).not_to include(viewed_candidate)
        end

        it 'filters by created_at for published candidates' do
          # Create a candidate that was just published but created long ago
          recently_published = create(:candidate, 
            publication_status: :published, 
            created_at: 2.weeks.ago,
            updated_at: 1.hour.ago
          )
          result = saved_search.find_new_candidates
          expect(result).not_to include(recently_published) # Should use created_at
        end
      end

      context 'when no candidates have been viewed and no alert sent' do
        it 'returns all published candidates matching the search' do
          result = saved_search.find_new_candidates
          # Should only return published candidates (3 total: old_published, new_published, viewed_candidate)
          expect(result.count).to eq(3)
          expect(result).to include(old_published, new_published, viewed_candidate)
          expect(result).not_to include(old_draft, new_draft)
        end
      end

      context 'with upsert behavior for viewed candidates' do
        it 'handles duplicate viewing gracefully' do
          # Mark as viewed once
          saved_search.mark_candidates_as_viewed([viewed_candidate])
          
          # Mark as viewed again - should not raise error
          expect {
            saved_search.mark_candidates_as_viewed([viewed_candidate])
          }.not_to raise_error
          
          # Should still have only one record
          expect(SavedSearchViewedCandidate.where(
            saved_search: saved_search,
            candidate: viewed_candidate
          ).count).to eq(1)
        end
      end
    end

  end
end
