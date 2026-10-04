require 'rails_helper'

RSpec.describe Project::MatchCandidatesJob do
  include ActiveJob::TestHelper

  let(:customer) { create(:user) }
  let(:location) { create(:location, latitude: 48.8566, longitude: 2.3522, city: "Paris") }
  let(:project) { create(:project, customer: customer, location: location, status: :active) }
  let(:embedding) { Array.new(1024) { rand } }

  before do
    allow(EmbeddingCache).to receive(:get_embedding).and_return(embedding)
    allow(Location).to receive(:near).and_return(Location.where(id: location.id))
  end

  describe '#perform' do
    context 'when project is not active' do
      let(:draft_project) { create(:project, customer: customer, status: :draft) }

      it 'does not create any project candidates' do
        expect {
          described_class.new.perform(draft_project.id)
        }.not_to change(ProjectCandidate, :count)
      end
    end

    context 'when matching candidates exist' do
      let!(:candidate) do
        c = create(:candidate, publication_status: "published", contract_type: "cdi", job_title_embedding: embedding)
        create(:candidate_mobility, candidate: c, location: location)
        c
      end

      it 'creates ProjectCandidate records' do
        expect {
          described_class.new.perform(project.id)
        }.to change(ProjectCandidate, :count).by(1)
      end

      it 'sets status to pending (awaiting LLM analysis)' do
        described_class.new.perform(project.id)

        project_candidate = ProjectCandidate.last
        expect(project_candidate.status).to eq("pending")
      end

      it 'sets match_score' do
        described_class.new.perform(project.id)

        project_candidate = ProjectCandidate.last
        expect(project_candidate.match_score).to be_present
        expect(project_candidate.match_score).to be_between(0, 1)
      end

      it 'enqueues ProjectCandidate::AnalyseJob' do
        expect(ProjectCandidate::AnalyseJob).to receive(:perform_async).with(kind_of(Integer))

        described_class.new.perform(project.id)
      end
    end

    context 'when project candidate already exists' do
      let!(:candidate) do
        c = create(:candidate, publication_status: "published", contract_type: "cdi", job_title_embedding: embedding)
        create(:candidate_mobility, candidate: c, location: location)
        c
      end

      let!(:existing_project_candidate) do
        create(:project_candidate, project: project, candidate: candidate, status: :validated)
      end

      it 'does not update existing project candidate with different status' do
        described_class.new.perform(project.id)

        existing_project_candidate.reload
        expect(existing_project_candidate.status).to eq("validated")
      end

      it 'does not create duplicate records' do
        expect {
          described_class.new.perform(project.id)
        }.not_to change(ProjectCandidate, :count)
      end
    end

    context 'when no candidates match' do
      it 'does not create any project candidates' do
        expect {
          described_class.new.perform(project.id)
        }.not_to change(ProjectCandidate, :count)
      end
    end
  end
end
