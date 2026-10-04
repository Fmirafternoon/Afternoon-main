require 'rails_helper'

RSpec.describe ProjectCandidate, type: :model do
  describe 'associations' do
    it { should belong_to(:project) }
    it { should belong_to(:candidate) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(pending: -1, matched: 0, validated: 1, pushed: 2, interested: 3, rejected: 4, hired: 5) }
  end

  describe 'scopes' do
    let!(:pending) { create(:project_candidate, status: :pending) }
    let!(:matched) { create(:project_candidate, status: :matched) }
    let!(:pushed) { create(:project_candidate, status: :pushed, viewed_at: nil) }
    let!(:interested) { create(:project_candidate, status: :interested) }

    describe '.for_customer' do
      it 'returns only pushed, interested, rejected, hired candidates' do
        expect(ProjectCandidate.for_customer).to include(pushed, interested)
        expect(ProjectCandidate.for_customer).not_to include(matched, pending)
      end
    end

    describe '.for_agent' do
      it 'returns all candidates except pending' do
        expect(ProjectCandidate.for_agent).to include(matched, pushed, interested)
        expect(ProjectCandidate.for_agent).not_to include(pending)
      end
    end

    describe '.new_for_customer' do
      it 'returns pushed candidates not yet viewed' do
        expect(ProjectCandidate.new_for_customer).to include(pushed)
        expect(ProjectCandidate.new_for_customer).not_to include(interested)
      end
    end
  end

  describe '#anonymized_number' do
    it 'returns the candidate public_token' do
      pc = create(:project_candidate)
      expect(pc.anonymized_number).to eq(pc.candidate.public_token)
    end
  end

  describe '#initials' do
    it 'returns first letters of first and last name' do
      candidate = build(:candidate, first_name: 'Jean', last_name: 'Dupont')
      pc = build(:project_candidate, candidate: candidate)
      expect(pc.initials).to eq('JD')
    end
  end

  describe '#mark_as_viewed!' do
    it 'sets viewed_at when nil' do
      pc = create(:project_candidate, viewed_at: nil)
      pc.mark_as_viewed!
      expect(pc.viewed_at).to be_present
    end

    it 'does not update when already viewed' do
      original_time = 1.day.ago
      pc = create(:project_candidate, viewed_at: original_time)
      pc.mark_as_viewed!
      expect(pc.viewed_at).to be_within(1.second).of(original_time)
    end
  end

  describe '#express_interest!' do
    it 'updates status and timestamps' do
      pc = create(:project_candidate, status: :pushed)
      pc.express_interest!(message: 'Very interested')

      expect(pc.interested?).to be true
      expect(pc.interest_expressed_at).to be_present
      expect(pc.interest_message).to eq('Very interested')
    end
  end

  describe '#reject!' do
    it 'updates status with reason' do
      pc = create(:project_candidate, status: :pushed)
      pc.reject!(reason: 'Not a fit')

      expect(pc.rejected?).to be true
      expect(pc.interest_message).to eq('Not a fit')
    end
  end
end
