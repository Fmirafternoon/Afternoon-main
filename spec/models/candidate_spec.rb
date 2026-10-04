require 'rails_helper'

RSpec.describe Candidate, type: :model do
  describe 'associations' do
    it { should belong_to(:agent).class_name('User').with_foreign_key('agent_id') }
    it { should belong_to(:location).optional }

    it { should have_many(:candidate_skills).dependent(:destroy) }
    it { should have_many(:skills).through(:candidate_skills) }
    it { should have_many(:candidate_languages).dependent(:destroy) }
    it { should have_many(:employments).dependent(:destroy) }
    it { should have_many(:educations).dependent(:destroy) }
    it { should have_many(:trainings).dependent(:destroy) }
    it { should have_many(:referrals).dependent(:destroy) }
    it { should have_many(:candidate_mobilities).dependent(:destroy) }
    it { should have_many(:locations).through(:candidate_mobilities) }
    it { should have_many(:candidate_sectors).dependent(:destroy) }
    it { should have_many(:sectors).through(:candidate_sectors) }
    it { should have_many(:red_flags).dependent(:destroy) }
    it { should have_many(:candidate_documents).dependent(:destroy) }
  end

  describe 'enums' do
    it 'defines import_status enum' do
      expect(Candidate.import_statuses.keys).to include('uploading', 'pending', 'completed', 'failed')
    end

    it 'defines publication_status enum' do
      expect(Candidate.publication_statuses.keys).to include('draft', 'pending', 'published')
    end

    it 'defines gender enum' do
      expect(Candidate.genders.keys).to include('male', 'female')
    end

    it 'defines contract_type enum' do
      expect(Candidate.contract_types.keys).to include('cdi', 'cdd', 'interim')
    end

    it 'defines availability_notice enum' do
      expect(Candidate.availability_notices.keys).to include('immediate', 'two_to_three_weeks', 'four_to_six_weeks', 'two_months', 'three_months', 'four_months_plus')
    end
  end

  describe 'validations' do
    context 'when published' do
      subject { build(:candidate, publication_status: :published) }

      it { should validate_presence_of(:position) }
    end

    context 'when not published' do
      subject { build(:candidate, publication_status: :draft) }

      it { should_not validate_presence_of(:position) }
    end
  end

  describe 'scopes' do
    describe '.archived' do
      let!(:active_candidate) { create(:candidate) }
      let!(:archived_candidate) { create(:candidate, discarded_at: Time.current) }

      it 'returns only archived candidates' do
        expect(Candidate.archived).to include(archived_candidate)
        expect(Candidate.archived).not_to include(active_candidate)
      end
    end

    describe '.near_location' do
      let(:location1) { create(:location, latitude: 48.8566, longitude: 2.3522) } # Paris
      let(:location2) { create(:location, latitude: 43.2965, longitude: 5.3698) } # Marseille
      let(:candidate1) { create(:candidate) }
      let(:candidate2) { create(:candidate) }

      before do
        create(:candidate_mobility, candidate: candidate1, location: location1)
        create(:candidate_mobility, candidate: candidate2, location: location2)
      end

      it 'returns candidates within radius' do
        # Test near Paris (lat: 48.8566, lng: 2.3522)
        results = Candidate.near_location(48.8566, 2.3522, 50)
        expect(results).to include(candidate1)
        expect(results).not_to include(candidate2)
      end
    end
  end

  describe '#archived?' do
    it 'returns true when discarded' do
      candidate = create(:candidate, discarded_at: Time.current)
      expect(candidate.archived?).to be_truthy
    end

    it 'returns false when not discarded' do
      candidate = create(:candidate)
      expect(candidate.archived?).to be_falsey
    end
  end

  describe '#age' do
    context 'with birth_year' do
      it 'calculates age correctly' do
        candidate = build(:candidate, birth_year: Date.current.year - 30)
        expect(candidate.age).to eq(30)
      end
    end

    context 'without birth_year' do
      it 'returns nil' do
        candidate = build(:candidate, birth_year: nil)
        expect(candidate.age).to be_nil
      end
    end
  end

  describe '#full_name' do
    it 'combines first and last name' do
      candidate = build(:candidate, first_name: 'John', last_name: 'Doe')
      expect(candidate.full_name).to eq('John Doe')
    end
  end

  describe '#publishable?' do
    let(:candidate) { create(:candidate) }

    context 'when all conditions are met' do
      before do
        allow(candidate).to receive(:archived?).and_return(false)
        allow(candidate).to receive(:unanswered_red_flags_count).and_return(0)
        allow(candidate).to receive(:validation_errors).and_return({})
      end

      it 'returns true' do
        expect(candidate.publishable?).to be_truthy
      end
    end

    context 'when archived' do
      before do
        allow(candidate).to receive(:archived?).and_return(true)
        allow(candidate).to receive(:unanswered_red_flags_count).and_return(0)
        allow(candidate).to receive(:validation_errors).and_return({})
      end

      it 'returns false' do
        expect(candidate.publishable?).to be_falsey
      end
    end

    context 'with unanswered red flags' do
      before do
        allow(candidate).to receive(:archived?).and_return(false)
        allow(candidate).to receive(:unanswered_red_flags_count).and_return(1)
        allow(candidate).to receive(:validation_errors).and_return({})
      end

      it 'returns true (les red flags ne bloquent plus la publication)' do
        expect(candidate.publishable?).to be_truthy
      end
    end

    context 'with validation errors' do
      before do
        allow(candidate).to receive(:archived?).and_return(false)
        allow(candidate).to receive(:unanswered_red_flags_count).and_return(0)
        allow(candidate).to receive(:validation_errors).and_return({ personal_info: ['error'] })
      end

      it 'returns false' do
        expect(candidate.publishable?).to be_falsey
      end
    end
  end

  describe '#unanswered_red_flags_count' do
    let(:candidate) { create(:candidate) }

    it 'counts red flags without answer' do
      create(:red_flag, candidate: candidate, answer: nil)
      create(:red_flag, candidate: candidate, answer: 'resolved')
      create(:red_flag, candidate: candidate, answer: nil)

      expect(candidate.unanswered_red_flags_count).to eq(2)
    end
  end

  describe '#position' do
    context 'when position is set' do
      it 'returns the position' do
        candidate = build(:candidate, position: 'Developer')
        expect(candidate.position).to eq('Developer')
      end
    end

    context 'when position is not set' do
      it 'returns resume_file_name' do
        candidate = build(:candidate, position: nil, resume_file_name: 'resume.pdf')
        expect(candidate.position).to eq('resume.pdf')
      end
    end
  end

  describe '#output' do
    let(:candidate) { create(:candidate) }

    it 'returns json with included associations' do
      result = candidate.output

      expect(result).to be_a(Hash)
      expect(result).to have_key('skills')
      expect(result).to have_key('educations')
      expect(result).to have_key('employments')
      expect(result).to have_key('trainings')
      expect(result).to have_key('referrals')
      expect(result).to have_key('locations')
      expect(result).to have_key('candidate_languages')
    end
  end

  describe '.search_by_similarity' do
    let(:query) { 'developer' }
    let(:embedding) { Array.new(1024) { rand } }

    before do
      allow(Embedding::Create).to receive(:call).and_return(
        double(embedding: embedding)
      )
    end

    it 'calls Embedding::Create with the query' do
      expect(Embedding::Create).to receive(:call).with(text: [query])
      Candidate.search_by_similarity(query)
    end

    it 'returns candidates with similarity filtering' do
      # This test would need actual data with embeddings
      # For now, we just ensure the method executes without error
      expect { Candidate.search_by_similarity(query) }.not_to raise_error
    end
  end

  describe '.search_by_similarity_with_score' do
    let(:query) { 'developer' }
    let(:embedding) { Array.new(1024) { rand } }

    before do
      allow(Embedding::Create).to receive(:call).and_return(
        double(embedding: embedding)
      )
    end

    it 'includes similarity score in results' do
      expect(Embedding::Create).to receive(:call).with(text: [query])
      expect { Candidate.search_by_similarity_with_score(query) }.not_to raise_error
    end
  end

  describe '#validation_errors' do
    let(:candidate) { create(:candidate) }

    it 'returns a hash of validation errors by step' do
      # This is a complex method that depends on form classes
      # We test that it returns a hash structure
      result = candidate.validation_errors
      expect(result).to be_a(Hash)
    end
  end

  describe 'jsonb_accessor' do
    let(:candidate) { build(:candidate) }

    it 'has resume_summary jsonb field' do
      candidate.resume_summary = { "skills" => ["Ruby", "Rails"] }
      expect(candidate.resume_summary).to eq({ "skills" => ["Ruby", "Rails"] })
    end

    # Note: skills accessor is overridden by the has_many :skills association
    # so we can't test it directly as a jsonb accessor

    it 'has accomplishments accessor' do
      candidate.accomplishments = 'Led a team of 5'
      expect(candidate.accomplishments).to eq('Led a team of 5')
    end

    it 'has management accessor' do
      candidate.management = 'Team lead experience'
      expect(candidate.management).to eq('Team lead experience')
    end

    it 'has specializations accessor with default array' do
      expect(candidate.specializations).to eq([])
      candidate.specializations = ['Frontend', 'Backend']
      expect(candidate.specializations).to eq(['Frontend', 'Backend'])
    end

    it 'has security_qualifications accessor with default array' do
      expect(candidate.security_qualifications).to eq([])
      candidate.security_qualifications = ['CISSP', 'CISM']
      expect(candidate.security_qualifications).to eq(['CISSP', 'CISM'])
    end

    it 'has tools_and_technologies accessor with default array' do
      expect(candidate.tools_and_technologies).to eq([])
      candidate.tools_and_technologies = ['Docker', 'Kubernetes']
      expect(candidate.tools_and_technologies).to eq(['Docker', 'Kubernetes'])
    end
  end

  describe 'constants' do
    it 'has WIZARD_STEPS constant' do
      expected_steps = %i[personal_info motivations skills employments educations trainings referrals availability comission]
      expect(Candidate::WIZARD_STEPS).to eq(expected_steps)
    end
  end

  describe 'expiration feature' do
    describe 'scopes' do
      describe '.expiring_soon' do
        let!(:published_candidate) { create(:candidate, publication_status: :published, published_at: 12.days.ago, expires_at: 2.days.from_now, expiration_notified_at: nil) }
        let!(:already_notified) { create(:candidate, publication_status: :published, published_at: 12.days.ago, expires_at: 2.days.from_now, expiration_notified_at: 1.day.ago) }
        let!(:not_expiring) { create(:candidate, publication_status: :published, published_at: 2.days.ago, expires_at: 12.days.from_now) }
        let!(:already_expired) { create(:candidate, publication_status: :published, published_at: 15.days.ago, expires_at: 1.day.ago, expiration_notified_at: 3.days.ago) }
        let!(:draft_candidate) { create(:candidate, publication_status: :draft) }

        it 'returns published candidates expiring within 3 days that have not been notified' do
          expect(Candidate.expiring_soon).to include(published_candidate)
          expect(Candidate.expiring_soon).not_to include(already_notified)
          expect(Candidate.expiring_soon).not_to include(not_expiring)
          expect(Candidate.expiring_soon).not_to include(already_expired)
          expect(Candidate.expiring_soon).not_to include(draft_candidate)
        end
      end

      describe '.expired' do
        let!(:expired_notified) { create(:candidate, publication_status: :published, published_at: 15.days.ago, expires_at: 1.day.ago, expiration_notified_at: 3.days.ago) }
        let!(:expired_not_notified_recent) { create(:candidate, publication_status: :published, published_at: 15.days.ago, expires_at: 1.day.ago, expiration_notified_at: nil) }
        let!(:expired_not_notified_old) { create(:candidate, publication_status: :published, published_at: 25.days.ago, expires_at: 10.days.ago, expiration_notified_at: nil) }
        let!(:not_expired) { create(:candidate, publication_status: :published, published_at: 2.days.ago, expires_at: 12.days.from_now, expiration_notified_at: nil) }

        it 'returns published candidates that are expired and have been notified' do
          expect(Candidate.expired).to include(expired_notified)
        end

        it 'does not return recently expired candidates without notification' do
          expect(Candidate.expired).not_to include(expired_not_notified_recent)
        end

        it 'returns candidates expired more than 7 days ago even without notification (fallback)' do
          expect(Candidate.expired).to include(expired_not_notified_old)
        end

        it 'does not return non-expired candidates' do
          expect(Candidate.expired).not_to include(not_expired)
        end
      end
    end

    describe '#extend_publication!' do
      let(:candidate) { create(:candidate, publication_status: :published, published_at: 12.days.ago, expires_at: 2.days.from_now, expiration_notified_at: 1.day.ago) }

      it 'extends expires_at by 14 days from now' do
        freeze_time do
          candidate.extend_publication!
          expect(candidate.reload.expires_at).to be_within(1.second).of(14.days.from_now)
        end
      end

      it 'resets expiration_notified_at to nil' do
        candidate.extend_publication!
        expect(candidate.reload.expiration_notified_at).to be_nil
      end
    end

    describe 'publication callbacks' do
      let(:candidate) { create(:candidate, publication_status: :draft, position: 'Test Position') }

      before do
        allow(candidate).to receive(:publishable?).and_return(true)
      end

      context 'when transitioning to published' do
        it 'sets expires_at to 14 days from now' do
          freeze_time do
            candidate.publish_workflow
            expect(candidate.expires_at).to be_within(1.second).of(14.days.from_now)
          end
        end
      end

      context 'when transitioning from published to draft' do
        let(:published_candidate) { create(:candidate, publication_status: :published, published_at: 5.days.ago, expires_at: 9.days.from_now) }

        it 'clears expires_at' do
          published_candidate.unpublish_workflow
          expect(published_candidate.expires_at).to be_nil
        end
      end
    end

    describe '#expire_workflow' do
      let(:published_candidate) { create(:candidate, publication_status: :published, published_at: 15.days.ago, expires_at: 1.day.ago, expiration_notified_at: 3.days.ago) }

      it 'transitions from published to draft' do
        expect(published_candidate).to be_published
        published_candidate.expire_workflow
        expect(published_candidate).to be_draft
      end

      it 'clears published_at' do
        published_candidate.expire_workflow
        expect(published_candidate.published_at).to be_nil
      end

      it 'clears expires_at' do
        published_candidate.expire_workflow
        expect(published_candidate.expires_at).to be_nil
      end

      it 'clears expiration_notified_at' do
        published_candidate.expire_workflow
        expect(published_candidate.expiration_notified_at).to be_nil
      end
    end
  end

  describe 'completion' do
    describe '#calculate_completion_percentage' do
      it 'counts only filled fields, normalized to 100' do
        candidate = create(:candidate)
        # Factory remplit : téléphone (5), email (5), poste (10) + disponibilité par défaut (5)
        # => 25 points sur un total de 95 => 26 %
        expect(candidate.calculate_completion_percentage).to eq(26)
      end

      it 'increases when associations are added' do
        candidate = create(:candidate, :with_skills)
        expect(candidate.calculate_completion_percentage).to eq(47)
      end
    end

    describe '#missing_completion_fields' do
      it 'lists the labels of empty fields' do
        candidate = create(:candidate)
        expect(candidate.missing_completion_fields).to include('Localisation', 'CV', 'Compétences')
        expect(candidate.missing_completion_fields).not_to include('Téléphone', 'Email', 'Poste recherché', 'Disponibilité')
      end
    end

    describe 'recalculation callbacks' do
      it 'stores the percentage after a candidate update' do
        candidate = create(:candidate)
        expect(candidate.reload.completion_percentage).to eq(26)

        candidate.update!(salary_expectation: 45_000)
        expect(candidate.reload.completion_percentage).to eq(32)
      end

      it 'recalculates when an association is created or destroyed' do
        candidate = create(:candidate)
        employment = create(:employment, candidate: candidate)
        expect(candidate.reload.completion_percentage).to eq(47)

        employment.destroy
        expect(candidate.reload.completion_percentage).to eq(26)
      end
    end
  end
end
