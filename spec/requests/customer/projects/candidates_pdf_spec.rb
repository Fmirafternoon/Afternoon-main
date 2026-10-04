require "rails_helper"
require "pdf-reader"

RSpec.describe "Customer::Projects::Candidates PDF", type: :request do
  let(:customer) { create(:user, :customer) }
  let(:company) { customer.company }
  let(:recruitment_office) { create(:recruitment_office) }
  let(:agent) { create(:user, :agent_user, recruitment_office: recruitment_office) }
  let(:location) { create(:location, city: "Paris") }

  let(:candidate) do
    create(:candidate,
      agent: agent,
      first_name: "Jean",
      last_name: "Dupont",
      position: "Chef de cuisine",
      total_experience_in_years: 12,
      location: location,
      salary_expectation: 55000,
      contract_type: :cdi,
      availability_notice: :immediate,
      publication_status: :published
    )
  end

  let(:project) do
    create(:project,
      customer: customer,
      title: "Recherche Chef"
    )
  end

  let(:project_candidate) do
    create(:project_candidate,
      project: project,
      candidate: candidate,
      status: :pushed,
      pushed_at: Time.current,
      llm_analysis: {
        "summary" => "Excellent candidat avec une solide experience en cuisine gastronomique.",
        "strengths" => ["12 ans d'experience", "Maitrise cuisine francaise", "Management equipe"],
        "attention_points" => ["Pretentions salariales elevees"]
      }
    )
  end

  before do
    sign_in customer
  end

  describe "GET /customer/projects/:project_id/candidates/:id/pdf" do
    it "generates a valid PDF" do
      get pdf_customer_project_candidate_path(project, project_candidate)

      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq("application/pdf")
      expect(response.headers["Content-Disposition"]).to include("candidat-")
      expect(response.headers["Content-Disposition"]).to include(".pdf")
    end

    it "contains candidate information in the PDF" do
      get pdf_customer_project_candidate_path(project, project_candidate)

      # Parse the PDF content
      pdf_io = StringIO.new(response.body)
      reader = PDF::Reader.new(pdf_io)
      pdf_text = reader.pages.map(&:text).join(" ")

      # Verify header
      expect(pdf_text).to include("Afternoon")

      # Verify candidate info
      expect(pdf_text).to include("Chef de cuisine")
      expect(pdf_text).to include("12")  # years of experience
      expect(pdf_text).to include("Paris")

      # Verify analysis
      expect(pdf_text).to include("Excellent candidat")
      expect(pdf_text).to include("experience")
      expect(pdf_text).to include("Points forts")
      expect(pdf_text).to include("Points d'attention")
    end

    it "includes employment history when present" do
      create(:employment,
        candidate: candidate,
        title: "Chef de cuisine",
        company: "Restaurant Etoile",
        from_year: 2018,
        to_year: 2024
      )

      get pdf_customer_project_candidate_path(project, project_candidate)

      pdf_io = StringIO.new(response.body)
      reader = PDF::Reader.new(pdf_io)
      pdf_text = reader.pages.map(&:text).join(" ")

      expect(pdf_text).to include("Restaurant Etoile")
      expect(pdf_text).to include("2018")
    end

    it "includes education when present" do
      create(:education,
        candidate: candidate,
        title: "CAP Cuisine",
        issuing_organization: "Ecole Hoteliere",
        from_year: 2010
      )

      get pdf_customer_project_candidate_path(project, project_candidate)

      pdf_io = StringIO.new(response.body)
      reader = PDF::Reader.new(pdf_io)
      pdf_text = reader.pages.map(&:text).join(" ")

      expect(pdf_text).to include("CAP Cuisine")
      expect(pdf_text).to include("Ecole Hoteliere")
    end

    it "includes skills when present" do
      skill = create(:skill, name: "Cuisine francaise")
      candidate.skills << skill

      get pdf_customer_project_candidate_path(project, project_candidate)

      pdf_io = StringIO.new(response.body)
      reader = PDF::Reader.new(pdf_io)
      pdf_text = reader.pages.map(&:text).join(" ")

      expect(pdf_text).to include("Cuisine francaise")
    end
  end
end
