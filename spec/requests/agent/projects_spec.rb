require 'rails_helper'

RSpec.describe "Agent::Projects", type: :request do
  let(:agent) { create(:user, :agent_manager) }
  let(:customer) { create(:user, :customer) }
  let(:candidate) { create(:candidate, agent: agent) }
  let!(:project) { create(:project, customer: customer, status: :active, title: "Chef de cuisine", position_name: "Chef de cuisine") }
  # Agent needs a candidate in the project to see it (per ProjectPolicy)
  let!(:project_candidate) { create(:project_candidate, project: project, candidate: candidate, status: :matched) }

  before { sign_in agent }

  describe "GET /agent/projects" do
    it "returns success" do
      get agent_projects_path
      expect(response).to have_http_status(:success)
    end

    it "shows projects where agent has candidates" do
      get agent_projects_path
      expect(response.body).to include(project.title)
    end

    context "with filter" do
      it "filters projects to validate" do
        get agent_projects_path(filter: "to_validate")
        expect(response.body).to include(project.title)
      end
    end

    context "when not agent" do
      let(:customer_with_terms) { create(:user, :customer) }

      before { sign_in customer_with_terms }

      it "returns 404 (route not accessible)" do
        get agent_projects_path
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /agent/projects/:id" do
    it "returns success" do
      get agent_project_path(project)
      expect(response).to have_http_status(:success)
    end

    it "shows project details" do
      get agent_project_path(project)
      expect(response.body).to include(project.position_name)
    end

    context "with status filter" do
      let!(:validated_candidate) do
        other_candidate = create(:candidate, agent: agent)
        create(:project_candidate, project: project, candidate: other_candidate, status: :validated)
      end

      it "filters by matched status" do
        get agent_project_path(project, status: "matched")
        expect(response).to have_http_status(:success)
      end

      it "filters by validated status" do
        get agent_project_path(project, status: "validated")
        expect(response).to have_http_status(:success)
      end
    end
  end
end
