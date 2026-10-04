require 'rails_helper'

RSpec.describe "Candidate Matching Integration", type: :model do
  let(:embedding) { Array.new(1024) { rand } }
  let(:paris_location) { create(:location, latitude: 48.8566, longitude: 2.3522, city: "Paris") }
  let(:lyon_location) { create(:location, latitude: 45.7640, longitude: 4.8357, city: "Lyon") }
  let(:bordeaux_location) { create(:location, latitude: 44.8378, longitude: -0.5792, city: "Bordeaux") }

  before do
    allow(EmbeddingCache).to receive(:get_embedding).and_return(embedding)
    allow(Location).to receive(:near).with([48.8566, 2.3522], 50, units: :km).and_return(Location.where(id: paris_location.id))
    allow(Location).to receive(:near).with([45.7640, 4.8357], 50, units: :km).and_return(Location.where(id: lyon_location.id))
    allow(Location).to receive(:near).with([44.8378, -0.5792], 50, units: :km).and_return(Location.where(id: bordeaux_location.id))
  end

  describe "Scénario: Chef de cuisine à Paris vs Ingénieur à Lyon" do
    let(:customer) { create(:user) }

    # Projet: Chef de cuisine à Paris, CDI
    let!(:chef_project) do
      project = create(:project,
        customer: customer,
        position_name: "Chef de cuisine",
        contract_type: "cdi",
        location: paris_location,
        languages: ["fr"],
        min_experience_years: 5,
        status: :active
      )
      skill = create(:skill, name: "Cuisine française")
      create(:project_skill, project: project, skill: skill)
      project
    end

    # Candidat 1: Chef de cuisine expérimenté à Paris (DEVRAIT MATCHER)
    let!(:chef_paris) do
      c = create(:candidate,
        position: "Chef de cuisine",
        publication_status: "published",
        contract_type: "cdi",
        job_title_embedding: embedding
      )
      create(:candidate_mobility, candidate: c, location: paris_location)
      create(:candidate_language, candidate: c, code: "fr")
      create(:candidate_skill, candidate: c, skill: Skill.find_by(name: "Cuisine française"))
      # Ajouter de l'expérience (6 ans)
      create(:employment, candidate: c, duration_in_months: 72, from_year: 2018, to_year: 2024)
      c
    end

    # Candidat 2: Ingénieur commercial à Lyon (NE DEVRAIT PAS MATCHER - position différente + lieu)
    let!(:ingenieur_lyon) do
      c = create(:candidate,
        position: "Ingénieur commercial",
        publication_status: "published",
        contract_type: "cdi",
        job_title_embedding: embedding
      )
      create(:candidate_mobility, candidate: c, location: lyon_location)
      c
    end

    # Candidat 3: Chef de cuisine à Lyon (NE DEVRAIT PAS MATCHER - hors zone)
    let!(:chef_lyon) do
      c = create(:candidate,
        position: "Chef de cuisine",
        publication_status: "published",
        contract_type: "cdi",
        job_title_embedding: embedding
      )
      create(:candidate_mobility, candidate: c, location: lyon_location)
      c
    end

    # Candidat 4: Chef de cuisine CDD (NE DEVRAIT PAS MATCHER - type contrat)
    let!(:chef_cdd) do
      c = create(:candidate,
        position: "Chef de cuisine",
        publication_status: "published",
        contract_type: "cdd",
        job_title_embedding: embedding
      )
      create(:candidate_mobility, candidate: c, location: paris_location)
      c
    end

    # Candidat 5: Chef de cuisine draft (NE DEVRAIT PAS MATCHER - pas publié)
    let!(:chef_draft) do
      c = create(:candidate,
        position: "Chef de cuisine",
        publication_status: "draft",
        contract_type: "cdi",
        job_title_embedding: embedding
      )
      create(:candidate_mobility, candidate: c, location: paris_location)
      c
    end

    it "ne matche que le chef de cuisine publié CDI à Paris" do
      result = ProjectCandidate::Match.call(project: chef_project)

      matched_candidates = result.matches.map { |m| m[:candidate] }

      expect(matched_candidates).to include(chef_paris)
      expect(matched_candidates).not_to include(ingenieur_lyon)
      expect(matched_candidates).not_to include(chef_lyon)
      expect(matched_candidates).not_to include(chef_cdd)
      expect(matched_candidates).not_to include(chef_draft)
    end

    it "le chef Paris a un score élevé grâce aux skills et langues" do
      result = ProjectCandidate::Match.call(project: chef_project)

      chef_match = result.matches.find { |m| m[:candidate] == chef_paris }

      expect(chef_match[:score]).to be > 0.5
      expect(chef_match[:details][:skills]).to eq(1.0) # 100% skills match
      expect(chef_match[:details][:languages]).to eq(1.0) # 100% languages match
      expect(chef_match[:details][:experience]).to be >= 0.5 # A de l'expérience
    end
  end

  describe "Scénario: Projet sans critères stricts" do
    let(:customer) { create(:user) }

    let!(:flexible_project) do
      create(:project,
        customer: customer,
        position_name: "Serveur",
        contract_type: nil, # Tous types de contrat
        location: nil, # Pas de localisation
        languages: [],
        min_experience_years: nil,
        status: :active
      )
    end

    let!(:serveur_anywhere) do
      create(:candidate,
        position: "Serveur",
        publication_status: "published",
        contract_type: "cdi",
        job_title_embedding: embedding
      )
    end

    it "matche tous les candidats publiés avec position similaire" do
      result = ProjectCandidate::Match.call(project: flexible_project)

      expect(result.matches).not_to be_empty
      expect(result.matches.first[:candidate]).to eq(serveur_anywhere)
    end
  end

  describe "Scénario: Limite à 10 candidats" do
    let(:customer) { create(:user) }

    let!(:project) do
      create(:project,
        customer: customer,
        position_name: "Cuisinier",
        contract_type: "cdi",
        location: paris_location,
        status: :active
      )
    end

    before do
      20.times do |i|
        c = create(:candidate,
          position: "Cuisinier #{i}",
          publication_status: "published",
          contract_type: "cdi",
          job_title_embedding: embedding
        )
        create(:candidate_mobility, candidate: c, location: paris_location)
      end
    end

    it "retourne au maximum 5 candidats par défaut" do
      result = ProjectCandidate::Match.call(project: project)

      expect(result.matches.size).to eq(5)
    end

    it "retourne les candidats triés par score décroissant" do
      result = ProjectCandidate::Match.call(project: project)

      scores = result.matches.map { |m| m[:score] }
      expect(scores).to eq(scores.sort.reverse)
    end
  end

  describe "Job: Project::MatchCandidatesJob crée les ProjectCandidate" do
    let(:customer) { create(:user) }

    let!(:project) do
      create(:project,
        customer: customer,
        position_name: "Commis de cuisine",
        contract_type: "cdi",
        location: paris_location,
        status: :active
      )
    end

    let!(:matching_candidate) do
      c = create(:candidate,
        position: "Commis de cuisine",
        publication_status: "published",
        contract_type: "cdi",
        job_title_embedding: embedding
      )
      create(:candidate_mobility, candidate: c, location: paris_location)
      c
    end

    it "crée des enregistrements ProjectCandidate avec status pending et enqueue l'analyse" do
      expect {
        Project::MatchCandidatesJob.new.perform(project.id)
      }.to change(ProjectCandidate, :count).by(1)

      pc = ProjectCandidate.last
      expect(pc.project).to eq(project)
      expect(pc.candidate).to eq(matching_candidate)
      expect(pc.status).to eq("pending")
      expect(pc.match_score).to be_present
    end
  end

  describe "Callback: Publication de projet déclenche le matching" do
    let(:customer) { create(:user) }

    let!(:matching_candidate) do
      c = create(:candidate,
        position: "Barman",
        publication_status: "published",
        contract_type: "cdi",
        job_title_embedding: embedding
      )
      create(:candidate_mobility, candidate: c, location: paris_location)
      c
    end

    it "enqueue le job quand le projet passe à active" do
      project = create(:project,
        customer: customer,
        position_name: "Barman",
        contract_type: "cdi",
        location: paris_location,
        status: :draft
      )

      expect(Project::MatchCandidatesJob).to receive(:perform_async).with(project.id)

      project.update!(status: :active)
    end

    it "n'enqueue pas si le projet reste draft" do
      project = create(:project,
        customer: customer,
        position_name: "Barman",
        status: :draft
      )

      expect(Project::MatchCandidatesJob).not_to receive(:perform_async)

      project.update!(title: "Nouveau titre")
    end
  end

  describe "Callback: Publication de candidat déclenche le matching" do
    let(:customer) { create(:user) }

    let!(:active_project) do
      create(:project,
        customer: customer,
        position_name: "Sommelier",
        contract_type: "cdi",
        location: paris_location,
        status: :active
      )
    end

    it "enqueue le job quand le candidat passe à published" do
      candidate = create(:candidate,
        position: "Sommelier",
        publication_status: "draft",
        contract_type: "cdi",
        job_title_embedding: embedding
      )
      create(:candidate_mobility, candidate: candidate, location: paris_location)

      expect(Candidate::MatchProjectsJob).to receive(:perform_async).with(candidate.id)

      candidate.update!(publication_status: "published")
    end
  end
end
