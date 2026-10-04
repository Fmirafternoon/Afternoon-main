require "rails_helper"

RSpec.describe Customer::ProjectsController, type: :request do
  let(:customer) { create(:user, :customer) }

  before { sign_in customer }

  describe "POST /customer/projects/:id/duplicate" do
    let!(:project) do
      create(:project, customer: customer, title: "Mon projet", status: :active)
    end

    it "creates a copy of the project" do
      expect {
        post duplicate_customer_project_path(project)
      }.to change(Project, :count).by(1)
    end

    it "sets the title with (copie) suffix" do
      post duplicate_customer_project_path(project)

      new_project = Project.last
      expect(new_project.title).to eq("Mon projet (copie)")
    end

    it "sets the status to draft" do
      post duplicate_customer_project_path(project)

      new_project = Project.last
      expect(new_project.status).to eq("draft")
    end

    it "copies the project attributes" do
      post duplicate_customer_project_path(project)

      new_project = Project.last
      expect(new_project.position_name).to eq(project.position_name)
      expect(new_project.contract_type).to eq(project.contract_type)
      expect(new_project.customer).to eq(customer)
    end

    it "redirects to projects index" do
      post duplicate_customer_project_path(project)

      expect(response).to redirect_to(customer_projects_path)
    end

    context "when project belongs to another customer" do
      let(:other_customer) { create(:user, :customer) }
      let(:other_project) { create(:project, customer: other_customer) }

      it "returns not found" do
        post duplicate_customer_project_path(other_project)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /customer/projects/:id" do
    let!(:project) { create(:project, customer: customer) }

    it "destroys the project" do
      expect {
        delete customer_project_path(project)
      }.to change(Project, :count).by(-1)
    end

    it "redirects to projects index" do
      delete customer_project_path(project)

      expect(response).to redirect_to(customer_projects_path)
    end

    context "when project belongs to another customer" do
      let(:other_customer) { create(:user, :customer) }
      let(:other_project) { create(:project, customer: other_customer) }

      it "returns not found" do
        delete customer_project_path(other_project)

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
