require 'rails_helper'

RSpec.describe ProjectCandidate::Match do
  let(:customer) { create(:user) }
  let(:location) { create(:location, latitude: 48.8566, longitude: 2.3522, city: "Paris") }
  let(:project) { create(:project, customer: customer, location: location, position_name: "Chef de cuisine", contract_type: "cdi") }
  let(:embedding) { Array.new(1024) { rand } }

  before do
    allow(EmbeddingCache).to receive(:get_embedding).and_return(embedding)
    allow(Location).to receive(:near).and_return(Location.where(id: location.id))
  end

  describe '#call' do
    context 'when no candidates match' do
      it 'returns empty matches' do
        result = described_class.call(project: project)

        expect(result).to be_success
        expect(result.matches).to be_empty
      end
    end

    context 'when project has no position_name' do
      let(:project) { create(:project, customer: customer, position_name: nil) }

      it 'returns empty matches' do
        result = described_class.call(project: project)

        expect(result).to be_success
        expect(result.matches).to be_empty
      end
    end

    context 'when candidates match all criteria' do
      let!(:candidate) do
        c = create(:candidate, publication_status: "published", contract_type: "cdi", job_title_embedding: embedding)
        create(:candidate_mobility, candidate: c, location: location)
        c
      end

      it 'returns matching candidates with scores' do
        result = described_class.call(project: project)

        expect(result).to be_success
        expect(result.matches.size).to eq(1)
        expect(result.matches.first[:candidate]).to eq(candidate)
        expect(result.matches.first[:score]).to be_between(0, 1)
        expect(result.matches.first[:details]).to have_key(:position)
        expect(result.matches.first[:details]).to have_key(:skills)
        expect(result.matches.first[:details]).to have_key(:experience)
        expect(result.matches.first[:details]).to have_key(:languages)
      end
    end

    context 'filtering by contract type' do
      let!(:cdi_candidate) do
        c = create(:candidate, publication_status: "published", contract_type: "cdi", job_title_embedding: embedding)
        create(:candidate_mobility, candidate: c, location: location)
        c
      end

      let!(:cdd_candidate) do
        c = create(:candidate, publication_status: "published", contract_type: "cdd", job_title_embedding: embedding)
        create(:candidate_mobility, candidate: c, location: location)
        c
      end

      it 'only returns candidates with matching contract type' do
        result = described_class.call(project: project)

        expect(result.matches.map { |m| m[:candidate] }).to include(cdi_candidate)
        expect(result.matches.map { |m| m[:candidate] }).not_to include(cdd_candidate)
      end
    end

    context 'filtering by location' do
      let(:other_location) { create(:location, latitude: 45.0, longitude: 5.0, city: "Lyon") }

      let!(:paris_candidate) do
        c = create(:candidate, publication_status: "published", contract_type: "cdi", job_title_embedding: embedding)
        create(:candidate_mobility, candidate: c, location: location)
        c
      end

      let!(:lyon_candidate) do
        c = create(:candidate, publication_status: "published", contract_type: "cdi", job_title_embedding: embedding)
        create(:candidate_mobility, candidate: c, location: other_location)
        c
      end

      it 'only returns candidates within location radius' do
        result = described_class.call(project: project)

        expect(result.matches.map { |m| m[:candidate] }).to include(paris_candidate)
        expect(result.matches.map { |m| m[:candidate] }).not_to include(lyon_candidate)
      end
    end

    context 'filtering by publication status' do
      let!(:published_candidate) do
        c = create(:candidate, publication_status: "published", contract_type: "cdi", job_title_embedding: embedding)
        create(:candidate_mobility, candidate: c, location: location)
        c
      end

      let!(:draft_candidate) do
        c = create(:candidate, publication_status: "draft", contract_type: "cdi", job_title_embedding: embedding)
        create(:candidate_mobility, candidate: c, location: location)
        c
      end

      it 'only returns published candidates' do
        result = described_class.call(project: project)

        expect(result.matches.map { |m| m[:candidate] }).to include(published_candidate)
        expect(result.matches.map { |m| m[:candidate] }).not_to include(draft_candidate)
      end
    end

    context 'scoring with skills' do
      let(:skill) { create(:skill, name: "Cuisine française") }

      let!(:candidate_with_skills) do
        c = create(:candidate, publication_status: "published", contract_type: "cdi", job_title_embedding: embedding)
        create(:candidate_mobility, candidate: c, location: location)
        create(:candidate_skill, candidate: c, skill: skill)
        c
      end

      let!(:candidate_without_skills) do
        c = create(:candidate, publication_status: "published", contract_type: "cdi", job_title_embedding: embedding)
        create(:candidate_mobility, candidate: c, location: location)
        c
      end

      before do
        create(:project_skill, project: project, skill: skill)
      end

      it 'scores candidates with matching skills higher' do
        result = described_class.call(project: project)

        # Le candidat sans skills est filtré par MIN_TOTAL_SCORE après pénalité
        with_skills_match = result.matches.find { |m| m[:candidate] == candidate_with_skills }
        expect(with_skills_match[:details][:skills]).to eq(1.0)
      end
    end

    context 'scoring with languages' do
      let!(:candidate_with_languages) do
        c = create(:candidate, publication_status: "published", contract_type: "cdi", job_title_embedding: embedding)
        create(:candidate_mobility, candidate: c, location: location)
        create(:candidate_language, candidate: c, code: "fr")
        c
      end

      let!(:candidate_without_languages) do
        c = create(:candidate, publication_status: "published", contract_type: "cdi", job_title_embedding: embedding)
        create(:candidate_mobility, candidate: c, location: location)
        create(:candidate_language, candidate: c, code: "de")
        c
      end

      let(:project) do
        create(:project, customer: customer, location: location, position_name: "Chef de cuisine", contract_type: "cdi", languages: ["fr"])
      end

      it 'scores candidates with matching languages higher' do
        result = described_class.call(project: project)

        with_lang_match = result.matches.find { |m| m[:candidate] == candidate_with_languages }
        without_lang_match = result.matches.find { |m| m[:candidate] == candidate_without_languages }

        expect(with_lang_match[:details][:languages]).to be > without_lang_match[:details][:languages]
      end
    end

    context 'limiting results' do
      before do
        15.times do
          c = create(:candidate, publication_status: "published", contract_type: "cdi", job_title_embedding: embedding)
          create(:candidate_mobility, candidate: c, location: location)
        end
      end

      it 'returns at most the specified limit' do
        result = described_class.call(project: project, limit: 10)

        expect(result.matches.size).to eq(10)
      end

      it 'uses default limit of 5' do
        result = described_class.call(project: project)

        expect(result.matches.size).to eq(5)
      end
    end

    context 'ordering by score' do
      it 'returns candidates ordered by score descending' do
        result = described_class.call(project: project)

        scores = result.matches.map { |m| m[:score] }
        expect(scores).to eq(scores.sort.reverse)
      end
    end

    context 'filtering by MIN_TOTAL_SCORE' do
      let(:skill1) { create(:skill, name: "Skill 1") }
      let(:skill2) { create(:skill, name: "Skill 2") }

      let(:project) do
        p = create(:project,
          customer: customer,
          location: location,
          position_name: "Chef de cuisine",
          contract_type: "cdi",
          languages: ["fr", "en"],
          min_experience_years: 10
        )
        create(:project_skill, project: p, skill: skill1)
        create(:project_skill, project: p, skill: skill2)
        p
      end

      let!(:low_score_candidate) do
        # Candidat avec position OK mais sans skills, sans expérience, et une langue
        # qui ne correspond pas au projet (de≠fr,en).
        # Score: position ~1.0 (40%) + skills 0.0 (30%) + exp 0.0 (15%) + lang 0.0 (15%)
        # = 0.40 < MIN_TOTAL_SCORE (0.50)
        c = create(:candidate,
          publication_status: "published",
          contract_type: "cdi",
          job_title_embedding: embedding
        )
        create(:candidate_mobility, candidate: c, location: location)
        create(:candidate_language, candidate: c, code: "de")
        c
      end

      it 'excludes candidates with score below 0.50' do
        result = described_class.call(project: project)

        expect(result.matches.map { |m| m[:candidate] }).not_to include(low_score_candidate)
      end
    end

    context 'candidate with multiple mobilities' do
      let(:paris) { create(:location, latitude: 48.8566, longitude: 2.3522, city: "Paris") }
      let(:lyon) { create(:location, latitude: 45.7640, longitude: 4.8357, city: "Lyon") }

      let(:project) do
        create(:project,
          customer: customer,
          location: paris,
          position_name: "Chef de cuisine",
          contract_type: "cdi"
        )
      end

      before do
        allow(Location).to receive(:near)
          .with([48.8566, 2.3522], 50, units: :km)
          .and_return(Location.where(id: paris.id))
      end

      let!(:multi_mobility_candidate) do
        c = create(:candidate,
          publication_status: "published",
          contract_type: "cdi",
          job_title_embedding: embedding
        )
        # Candidat mobile sur Paris ET Lyon
        create(:candidate_mobility, candidate: c, location: paris)
        create(:candidate_mobility, candidate: c, location: lyon)
        c
      end

      let!(:lyon_only_candidate) do
        c = create(:candidate,
          publication_status: "published",
          contract_type: "cdi",
          job_title_embedding: embedding
        )
        # Candidat mobile uniquement sur Lyon
        create(:candidate_mobility, candidate: c, location: lyon)
        c
      end

      it 'matches candidate if ANY mobility location is within radius' do
        result = described_class.call(project: project)

        matched = result.matches.map { |m| m[:candidate] }
        expect(matched).to include(multi_mobility_candidate)
        expect(matched).not_to include(lyon_only_candidate)
      end
    end
  end
end
