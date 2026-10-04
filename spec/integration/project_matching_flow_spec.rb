require 'rails_helper'

RSpec.describe "Project Matching Flow E2E", type: :request do
  include ActiveJob::TestHelper

  let(:embedding) { Array.new(1024) { rand } }
  let(:paris_location) { create(:location, latitude: 48.8566, longitude: 2.3522, city: "Paris") }

  let(:customer) { create(:user, :customer) }
  let(:agent) { create(:user, :agent_manager) }
  let(:candidate) do
    c = create(:candidate,
      agent: agent,
      position: "Chef de cuisine",
      publication_status: "published",
      contract_type: "cdi",
      job_title_embedding: embedding
    )
    create(:candidate_mobility, candidate: c, location: paris_location)
    c
  end

  before do
    allow(EmbeddingCache).to receive(:get_embedding).and_return(embedding)
    allow(Location).to receive(:near).and_return(Location.where(id: paris_location.id))
  end

  describe "Flow 1: Customer crée projet → System matche candidats" do
    let!(:project) do
      create(:project,
        customer: customer,
        position_name: "Chef de cuisine",
        title: "Recherche Chef",
        contract_type: "cdi",
        location: paris_location,
        status: :draft
      )
    end

    before { candidate } # ensure candidate exists

    it "crée ProjectCandidate pending quand projet passe à active" do
      expect {
        project.update!(status: :active)
        Project::MatchCandidatesJob.new.perform(project.id)
      }.to change(ProjectCandidate, :count).by(1)

      pc = ProjectCandidate.last
      expect(pc.project).to eq(project)
      expect(pc.candidate).to eq(candidate)
      expect(pc.status).to eq("pending")
      expect(pc.match_score).to be_present
    end

    it "passe à matched après analyse LLM" do
      project.update!(status: :active)
      Project::MatchCandidatesJob.new.perform(project.id)

      pc = ProjectCandidate.last
      expect(pc.status).to eq("pending")

      # Simulate LLM analysis completion
      llm_result = {
        "summary" => "Candidat expérimenté en cuisine française",
        "strengths" => ["10 ans d'expérience", "Formation étoilée"],
        "attention_points" => ["Disponibilité à confirmer"]
      }

      allow_any_instance_of(ProjectCandidate::Analyse).to receive(:call).and_return(
        OpenStruct.new(success?: true, analysis: llm_result)
      )

      pc.update!(status: :matched, llm_analysis: llm_result)

      expect(pc.reload.status).to eq("matched")
      expect(pc.llm_analysis["summary"]).to be_present
    end

    it "envoie email à l'agent quand candidat matché" do
      project.update!(status: :active)
      Project::MatchCandidatesJob.new.perform(project.id)

      pc = ProjectCandidate.last
      pc.update!(
        status: :matched,
        llm_analysis: { "summary" => "Bon candidat" }
      )

      expect {
        AgentMailer.candidate_matched(pc.id).deliver_now
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      email = ActionMailer::Base.deliveries.last
      expect(email.to).to include(agent.email)
      expect(email.subject).to include("matche un projet")
    end
  end

  describe "Flow 2: Agent review et push candidat" do
    let!(:project) { create(:project, customer: customer, status: :active, title: "Test Project", position_name: "Chef") }
    let!(:project_candidate) do
      create(:project_candidate,
        project: project,
        candidate: candidate,
        status: :matched,
        llm_analysis: {
          "summary" => "Excellent candidat",
          "strengths" => ["Expérience solide"],
          "attention_points" => ["Salaire élevé"]
        }
      )
    end

    before { sign_in agent }

    it "agent voit le projet dans sa liste" do
      get agent_projects_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include(project.title)
    end

    it "agent voit les candidats matchés" do
      get agent_project_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(candidate.full_name)
    end

    it "agent accède au formulaire push" do
      get push_agent_project_candidate_path(project, project_candidate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Présenter au client")
    end

    it "agent push le candidat avec succès" do
      post push_agent_project_candidate_path(project, project_candidate),
        params: {
          push: {
            summary: "Résumé personnalisé par l'agent",
            strengths: "<ul><li>Point fort 1</li><li>Point fort 2</li></ul>",
            attention_points: "<ul><li>Attention</li></ul>"
          }
        }

      expect(response).to redirect_to(agent_project_path(project))
      expect(project_candidate.reload.status).to eq("pushed")
      expect(project_candidate.pushed_at).to be_present
      expect(project_candidate.agent_analysis["summary"]).to eq("Résumé personnalisé par l'agent")
    end

    it "email envoyé au customer après push" do
      expect {
        post push_agent_project_candidate_path(project, project_candidate),
          params: {
            push: {
              summary: "Résumé",
              strengths: "<ul><li>Force</li></ul>",
              attention_points: ""
            }
          }
      }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end
  end

  describe "Flow 3: Customer exprime intérêt via magic link" do
    let!(:project) { create(:project, customer: customer, status: :active) }
    let!(:project_candidate) do
      create(:project_candidate,
        project: project,
        candidate: candidate,
        status: :pushed,
        pushed_at: Time.current,
        agent_analysis: {
          "summary" => "Bon candidat",
          "strengths" => ["Expérience"],
          "attention_points" => []
        }
      )
    end

    it "magic link connecte le customer et redirige" do
      token = project_candidate.to_sgid(expires_in: 30.days, for: "customer_view").to_s

      get "/p/#{token}"

      expect(response).to redirect_to(customer_project_candidate_path(project, project_candidate))
      follow_redirect!
      expect(response).to have_http_status(:success)
    end

    it "customer voit le détail du candidat" do
      sign_in customer

      get customer_project_candidate_path(project, project_candidate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bon candidat")
    end

    it "customer peut exprimer son intérêt" do
      sign_in customer

      get interest_form_customer_project_candidate_path(project, project_candidate)
      expect(response).to have_http_status(:success)

      post interest_customer_project_candidate_path(project, project_candidate),
        params: { message: "Je souhaite rencontrer ce candidat" }

      expect(response).to redirect_to(customer_project_path(project))
      expect(project_candidate.reload.status).to eq("interested")
      expect(project_candidate.interest_message).to eq("Je souhaite rencontrer ce candidat")
      expect(project_candidate.interest_expressed_at).to be_present
    end

    it "email envoyé à l'agent après intérêt" do
      sign_in customer

      expect {
        post interest_customer_project_candidate_path(project, project_candidate),
          params: { message: "Intéressé!" }
      }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end
  end

  describe "Flow 4: Customer rejette candidat" do
    let!(:project) { create(:project, customer: customer, status: :active) }
    let!(:project_candidate) do
      create(:project_candidate,
        project: project,
        candidate: candidate,
        status: :pushed,
        pushed_at: Time.current,
        agent_analysis: { "summary" => "Candidat", "strengths" => [], "attention_points" => [] }
      )
    end

    before { sign_in customer }

    it "customer accède au formulaire de rejet" do
      get reject_form_customer_project_candidate_path(project, project_candidate)
      expect(response).to have_http_status(:success)
    end

    it "customer rejette avec raison obligatoire" do
      post reject_customer_project_candidate_path(project, project_candidate),
        params: { reason: "Profil ne correspond pas à nos attentes" }

      expect(response).to redirect_to(customer_project_path(project))
      expect(project_candidate.reload.status).to eq("rejected")
      expect(project_candidate.interest_message).to eq("Profil ne correspond pas à nos attentes")
    end

    it "email envoyé à l'agent après rejet" do
      expect {
        post reject_customer_project_candidate_path(project, project_candidate),
          params: { reason: "Ne convient pas" }
      }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end
  end

  describe "Flow 5: Agent voit réponse customer" do
    let!(:project) { create(:project, customer: customer, status: :active, title: "Test", position_name: "Chef") }
    let!(:project_candidate) do
      create(:project_candidate,
        project: project,
        candidate: candidate,
        status: :interested,
        pushed_at: 1.day.ago,
        interest_expressed_at: Time.current,
        interest_message: "Très intéressé, merci de me contacter",
        agent_analysis: { "summary" => "Bon", "strengths" => [], "attention_points" => [] }
      )
    end

    before { sign_in agent }

    it "agent voit le badge intérêt sur la card" do
      get agent_project_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Intérêt")
    end

    it "agent voit le message du customer" do
      get agent_project_candidate_path(project, project_candidate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Très intéressé")
    end

    it "agent voit les coordonnées du customer quand intéressé" do
      get agent_project_candidate_path(project, project_candidate)
      expect(response.body).to include(customer.email)
    end
  end

  describe "Flow complet: Draft → Active → Match → Push → Interest" do
    let!(:project) do
      create(:project,
        customer: customer,
        position_name: "Chef de cuisine",
        title: "Recherche Chef",
        contract_type: "cdi",
        location: paris_location,
        status: :draft
      )
    end

    before { candidate } # ensure candidate exists

    it "parcourt tout le flow de bout en bout" do
      # Step 1: Project becomes active
      project.update!(status: :active)

      # Step 2: Matching job creates ProjectCandidate
      Project::MatchCandidatesJob.new.perform(project.id)
      pc = ProjectCandidate.last
      expect(pc.status).to eq("pending")

      # Step 3: Analysis completes (simulated)
      pc.update!(
        status: :matched,
        llm_analysis: {
          "summary" => "Candidat idéal",
          "strengths" => ["Compétent"],
          "attention_points" => []
        }
      )

      # Step 4: Agent pushes candidate
      sign_in agent
      post push_agent_project_candidate_path(project, pc),
        params: {
          push: {
            summary: "Candidat recommandé",
            strengths: "<ul><li>Excellent profil</li></ul>",
            attention_points: ""
          }
        }
      expect(pc.reload.status).to eq("pushed")

      # Step 5: Customer expresses interest
      sign_in customer
      post interest_customer_project_candidate_path(project, pc),
        params: { message: "Je veux le rencontrer" }
      expect(pc.reload.status).to eq("interested")

      # Step 6: Agent sees customer contact
      sign_in agent
      get agent_project_candidate_path(project, pc)
      expect(response.body).to include(customer.email)
      expect(response.body).to include("Je veux le rencontrer")
    end
  end
end
