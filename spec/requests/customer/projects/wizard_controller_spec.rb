require "rails_helper"

RSpec.describe Customer::Projects::WizardController, type: :request do
  let(:customer) { create(:user, :customer) }

  before { sign_in customer }

  describe "GET /customer/projects/new/wizard/step1" do
    it "does not create a project in database" do
      expect {
        get customer_project_wizard_path("new", :step1)
      }.not_to change(Project, :count)

      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /customer/projects/new/wizard (create)" do
    let(:valid_params) do
      {
        wizard_form: {
          position_name: "Chef de cuisine",
          location_city: "Paris",
          start_date: 1.month.from_now.to_date,
          contract_type: "cdi",
          description: "Description du poste"
        }
      }
    end

    context "with valid params" do
      it "creates the project" do
        expect {
          post customer_project_wizard_index_path("new"), params: valid_params
        }.to change(Project, :count).by(1)
      end

      it "redirects to step2" do
        post customer_project_wizard_index_path("new"), params: valid_params

        project = Project.last
        expect(response).to redirect_to(customer_project_wizard_path(project, :step2))
      end

      it "sets the project attributes" do
        post customer_project_wizard_index_path("new"), params: valid_params

        project = Project.last
        expect(project.position_name).to eq("Chef de cuisine")
        expect(project.contract_type).to eq("cdi")
        expect(project.status).to eq("draft")
        expect(project.customer).to eq(customer)
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          wizard_form: {
            position_name: "",
            location_city: "",
            start_date: nil,
            contract_type: "",
            description: ""
          }
        }
      end

      it "does not create a project" do
        expect {
          post customer_project_wizard_index_path("new"), params: invalid_params
        }.not_to change(Project, :count)
      end

      it "renders step1 with errors" do
        post customer_project_wizard_index_path("new"), params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PUT /customer/projects/:id/wizard/step1 (update existing)" do
    let!(:project) { create(:project, customer: customer, status: :draft) }

    let(:update_params) do
      {
        wizard_form: {
          position_name: "Nouveau titre",
          location_city: "Lyon",
          start_date: 2.months.from_now.to_date,
          contract_type: "cdd",
          description: "Nouvelle description"
        }
      }
    end

    it "updates the existing project" do
      expect {
        put customer_project_wizard_path(project, :step1), params: update_params
      }.not_to change(Project, :count)

      project.reload
      expect(project.position_name).to eq("Nouveau titre")
    end

    it "redirects to step2" do
      put customer_project_wizard_path(project, :step1), params: update_params

      expect(response).to redirect_to(customer_project_wizard_path(project, :step2))
    end
  end
end
