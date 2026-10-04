require 'rails_helper'

RSpec.describe "Agent::Projects::Candidates", type: :request do
  let(:agent) { create(:user, :agent_manager) }
  let(:customer) { create(:user, :customer) }
  let(:project) { create(:project, customer: customer, status: :active) }
  let(:candidate) { create(:candidate, agent: agent) }
  let!(:project_candidate) { create(:project_candidate, project: project, candidate: candidate, status: :matched) }

  before { sign_in agent }

  describe "GET /agent/projects/:project_id/candidates/:id" do
    it "returns success" do
      get agent_project_candidate_path(project, project_candidate)
      expect(response).to have_http_status(:success)
    end

    it "shows candidate details" do
      get agent_project_candidate_path(project, project_candidate)
      expect(response.body).to include(candidate.full_name)
    end
  end

  describe "GET /agent/projects/:project_id/candidates/:id/push (push_form)" do
    context "when candidate is matched with analysis" do
      before do
        project_candidate.update!(
          llm_analysis: {
            "summary" => "Bon candidat",
            "strengths" => ["Point fort 1", "Point fort 2"],
            "attention_points" => ["Attention 1"]
          }
        )
      end

      it "returns success" do
        get push_agent_project_candidate_path(project, project_candidate)
        expect(response).to have_http_status(:success)
      end

      it "shows pre-filled form with LLM analysis" do
        get push_agent_project_candidate_path(project, project_candidate)
        expect(response.body).to include("Présenter au client")
        expect(response.body).to include("Bon candidat")
        expect(response.body).to include("Point fort 1")
      end
    end

    context "when candidate has no analysis" do
      it "redirects with error" do
        get push_agent_project_candidate_path(project, project_candidate)
        expect(response).to redirect_to(agent_project_path(project))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "POST /agent/projects/:project_id/candidates/:id/push" do
    context "when candidate is matched with analysis" do
      before do
        project_candidate.update!(
          llm_analysis: { "summary" => "Analyse LLM", "strengths" => ["Force"], "attention_points" => [] }
        )
      end

      it "pushes the candidate to the client" do
        post push_agent_project_candidate_path(project, project_candidate),
          params: { push: { summary: "Résumé", strengths: "Force", attention_points: "" } }

        expect(response).to redirect_to(agent_project_path(project))
        expect(project_candidate.reload.status).to eq("pushed")
        expect(project_candidate.pushed_at).to be_present
      end

      it "saves agent_analysis with edited values" do
        post push_agent_project_candidate_path(project, project_candidate),
          params: {
            push: {
              summary: "Résumé modifié par l'agent",
              strengths: "<ul><li>Force 1</li><li>Force 2</li></ul>",
              attention_points: "<ul><li>Attention</li></ul>"
            }
          }

        project_candidate.reload
        expect(project_candidate.agent_analysis["summary"]).to eq("Résumé modifié par l'agent")
        expect(project_candidate.agent_analysis["strengths"]).to eq(["Force 1", "Force 2"])
        expect(project_candidate.agent_analysis["attention_points"]).to eq(["Attention"])
      end

      it "parses HTML list from Trix into array" do
        post push_agent_project_candidate_path(project, project_candidate),
          params: {
            push: {
              summary: "Test",
              strengths: "<ul><li>Ligne 1</li><li>Ligne 2</li><li>Ligne 3</li></ul>",
              attention_points: ""
            }
          }

        project_candidate.reload
        expect(project_candidate.agent_analysis["strengths"]).to eq(["Ligne 1", "Ligne 2", "Ligne 3"])
      end
    end

    context "when candidate has no analysis" do
      it "does not push and shows error" do
        post push_agent_project_candidate_path(project, project_candidate),
          params: { push: { summary: "Test", strengths: "", attention_points: "" } }

        expect(response).to redirect_to(agent_project_path(project))
        expect(flash[:alert]).to be_present
        expect(project_candidate.reload.status).to eq("matched")
      end
    end
  end

  describe "POST /agent/projects/:project_id/candidates/:id/cancel" do
    context "when candidate is matched" do
      it "cancels the candidate" do
        post cancel_agent_project_candidate_path(project, project_candidate)

        expect(response).to redirect_to(agent_project_path(project))
        expect(project_candidate.reload.status).to eq("rejected")
      end
    end

    context "when candidate is pushed" do
      before { project_candidate.update!(status: :pushed) }

      it "cancels the candidate" do
        post cancel_agent_project_candidate_path(project, project_candidate)

        expect(project_candidate.reload.status).to eq("rejected")
      end
    end

    context "when candidate is already rejected" do
      before { project_candidate.update!(status: :rejected) }

      it "shows error" do
        post cancel_agent_project_candidate_path(project, project_candidate)

        expect(response).to redirect_to(agent_project_path(project))
        expect(flash[:alert]).to be_present
      end
    end

    context "when candidate is interested" do
      before { project_candidate.update!(status: :interested) }

      it "shows error" do
        post cancel_agent_project_candidate_path(project, project_candidate)

        expect(response).to redirect_to(agent_project_path(project))
        expect(flash[:alert]).to be_present
      end
    end
  end

  context "when not agent" do
    let(:customer_with_terms) { create(:user, :customer) }

    before { sign_in customer_with_terms }

    it "returns 404 (route not accessible)" do
      get agent_project_candidate_path(project, project_candidate)
      expect(response).to have_http_status(:not_found)
    end
  end
end
