require 'rails_helper'

RSpec.describe Project, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:customer).class_name('User') }
    it { is_expected.to belong_to(:location).optional }
    it { is_expected.to belong_to(:saved_search).optional }
    it { is_expected.to have_many(:project_skills).dependent(:destroy) }
    it { is_expected.to have_many(:skills).through(:project_skills) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(draft: 0, active: 1, archived: 2) }
    it { is_expected.to define_enum_for(:desired_availability).backed_by_column_of_type(:string).with_values(
      immediate: "immediate",
      within_1_month: "within_1_month",
      within_3_months: "within_3_months",
      flexible: "flexible"
    ).with_prefix(true) }
  end

  describe 'scopes' do
    let(:customer) { create(:user, :customer) }
    let!(:draft_project) { create(:project, customer: customer, status: :draft) }
    let!(:active_project) { create(:project, customer: customer, status: :active) }
    let!(:archived_project) { create(:project, customer: customer, status: :archived) }

    describe '.not_archived' do
      it 'returns draft and active projects' do
        expect(Project.not_archived).to include(draft_project, active_project)
        expect(Project.not_archived).not_to include(archived_project)
      end
    end

    describe '.ordered' do
      it 'returns projects ordered by created_at desc' do
        expect(Project.ordered.first).to eq(archived_project)
      end
    end

    describe '.with_candidates_to_validate' do
      let!(:project_with_matched) { create(:project, customer: customer, status: :active) }
      let!(:project_without) { create(:project, customer: customer, status: :active) }

      before do
        create(:project_candidate, project: project_with_matched, status: :matched)
      end

      it 'returns projects with matched candidates' do
        expect(Project.with_candidates_to_validate).to include(project_with_matched)
        expect(Project.with_candidates_to_validate).not_to include(project_without)
      end
    end

    describe '.with_client_interests' do
      let!(:project_with_interest) { create(:project, customer: customer, status: :active) }
      let!(:project_without) { create(:project, customer: customer, status: :active) }

      before do
        create(:project_candidate, project: project_with_interest, status: :interested)
      end

      it 'returns projects with interested candidates' do
        expect(Project.with_client_interests).to include(project_with_interest)
        expect(Project.with_client_interests).not_to include(project_without)
      end
    end
  end

  describe '#candidates_to_validate_count' do
    let(:customer) { create(:user, :customer) }
    let(:project) { create(:project, customer: customer) }

    it 'returns count of matched candidates' do
      create(:project_candidate, project: project, status: :matched)
      create(:project_candidate, project: project, status: :pushed)
      expect(project.candidates_to_validate_count).to eq(1)
    end
  end

  describe '#client_initials' do
    let(:company) { create(:company, name: "Le Grand Restaurant") }
    let(:customer) { create(:user, :customer, company: company, first_name: "Jean", last_name: "Dupont") }
    let(:project) { create(:project, customer: customer) }

    it 'returns initials from company name' do
      expect(project.client_initials).to eq("LG")
    end

    context 'without company' do
      let(:customer_no_company) { create(:user, :customer, company: nil, first_name: "Jean", last_name: "Dupont") }
      let(:project_no_company) { create(:project, customer: customer_no_company) }

      it 'returns initials from user name' do
        expect(project_no_company.client_initials).to eq("JD")
      end
    end
  end

  describe '#client_name' do
    let(:company) { create(:company, name: "Le Grand Restaurant") }
    let(:customer) { create(:user, :customer, company: company) }
    let(:project) { create(:project, customer: customer) }

    it 'returns company name' do
      expect(project.client_name).to eq("Le Grand Restaurant")
    end
  end

  describe '#build_search_criteria' do
    let(:customer) { create(:user, :customer) }
    let(:location) { create(:location, city: "Paris") }
    let(:skill1) { create(:skill, name: "Ruby") }
    let(:skill2) { create(:skill, name: "Rails") }
    let(:project) { create(:project, customer: customer, position_name: "Développeur", location: location) }

    before do
      project.skills << [skill1, skill2]
    end

    it 'returns criteria hash with position, city and skills' do
      expect(project.build_search_criteria).to eq({
        "query" => "Développeur",
        "city" => "Paris",
        "skills" => ["Ruby", "Rails"]
      })
    end

    context 'without location' do
      let(:customer2) { create(:user, :customer) }
      let(:skill_only) { create(:skill, name: "JavaScript") }
      let(:project_no_loc) { create(:project, customer: customer2, position_name: "Manager", location: nil) }

      before { project_no_loc.skills << skill_only }

      it 'excludes city from criteria' do
        expect(project_no_loc.build_search_criteria).to eq({
          "query" => "Manager",
          "skills" => ["JavaScript"]
        })
      end
    end

    context 'without skills' do
      let(:customer3) { create(:user, :customer) }
      let(:location2) { create(:location, city: "Marseille") }
      let(:project_no_skills) { create(:project, customer: customer3, position_name: "Chef", location: location2) }

      it 'excludes empty skills array' do
        expect(project_no_skills.build_search_criteria).to eq({
          "query" => "Chef",
          "city" => "Marseille"
        })
      end
    end
  end

  describe 'saved_search callbacks' do
    let(:customer) { create(:user, :customer) }
    let(:location) { create(:location, city: "Lyon") }
    let(:skill) { create(:skill, name: "Python") }

    describe 'when project becomes active' do
      let(:project) { create(:project, customer: customer, status: :draft, position_name: "Data Scientist", location: location) }

      before { project.skills << skill }

      it 'creates a SavedSearch' do
        expect {
          project.active!
        }.to change(SavedSearch, :count).by(1)
      end

      it 'associates the SavedSearch to the project' do
        project.active!
        project.reload
        expect(project.saved_search).to be_present
      end

      it 'sets the SavedSearch name from position' do
        project.active!
        expect(project.saved_search.name).to eq("Projet - Data Scientist")
      end

      it 'sets the SavedSearch criteria from project' do
        project.active!
        expect(project.saved_search.criteria).to eq({
          "query" => "Data Scientist",
          "city" => "Lyon",
          "skills" => ["Python"]
        })
      end

      it 'associates SavedSearch to the same customer' do
        project.active!
        expect(project.saved_search.customer).to eq(customer)
      end
    end

    describe 'when active project is updated' do
      let(:project) { create(:project, customer: customer, status: :draft, position_name: "Dev", location: location) }

      before do
        project.skills << skill
        project.active!
      end

      it 'updates SavedSearch criteria when project changes and becomes active again' do
        new_location = create(:location, city: "Marseille")
        project.update!(location: new_location, status: :draft)

        expect {
          project.active!
        }.not_to change(SavedSearch, :count)

        expect(project.saved_search.reload.criteria["city"]).to eq("Marseille")
      end
    end

    describe 'when project becomes archived' do
      let(:project) { create(:project, customer: customer, status: :draft, position_name: "Architect") }

      before { project.active! }

      it 'archives the associated SavedSearch' do
        expect(project.saved_search.archived).to be false

        project.archived!

        expect(project.saved_search.reload.archived).to be true
      end
    end
  end

  describe '#broadcastable?' do
    it 'is false when broadcast is disabled' do
      project = build(:project, broadcast_enabled: false)
      expect(project.broadcastable?).to be false
    end

    it 'is true when broadcast is enabled and never sent' do
      project = build(:project, :broadcast_enabled, last_email_broadcasted_at: nil)
      expect(project.broadcastable?).to be true
    end

    it 'is false when broadcasted less than a week ago' do
      project = build(:project, :broadcast_enabled, last_email_broadcasted_at: 2.days.ago)
      expect(project.broadcastable?).to be false
    end

    it 'is true when broadcasted more than a week ago' do
      project = build(:project, :broadcast_enabled, last_email_broadcasted_at: 8.days.ago)
      expect(project.broadcastable?).to be true
    end
  end

  describe '#next_broadcast_available_at' do
    it 'is nil when never broadcasted' do
      project = build(:project, :broadcast_enabled)
      expect(project.next_broadcast_available_at).to be_nil
    end

    it 'is one week after the last broadcast' do
      sent_at = Time.current
      project = build(:project, :broadcast_enabled, last_email_broadcasted_at: sent_at)
      expect(project.next_broadcast_available_at).to be_within(1.second).of(sent_at + 1.week)
    end
  end

  describe 'email broadcast callback' do
    let(:customer) { create(:user, :customer) }

    it 'enqueues an EmailBroadcastJob when a broadcastable project is published' do
      project = create(:project, :broadcast_enabled, customer: customer, status: :draft)

      expect {
        project.active!
      }.to change(Project::EmailBroadcastJob.jobs, :size).by(1)
    end

    it 'does not enqueue when broadcast is disabled' do
      project = create(:project, customer: customer, status: :draft)

      expect {
        project.active!
      }.not_to change(Project::EmailBroadcastJob.jobs, :size)
    end

    it 'does not enqueue when broadcasted less than a week ago' do
      project = create(:project, :broadcast_enabled, customer: customer, status: :draft,
                       last_email_broadcasted_at: 2.days.ago)

      expect {
        project.active!
      }.not_to change(Project::EmailBroadcastJob.jobs, :size)
    end

    it 'does not enqueue when the project is updated without being published' do
      project = create(:project, :broadcast_enabled, customer: customer, status: :active)

      expect {
        project.update!(description: "Nouvelle description")
      }.not_to change(Project::EmailBroadcastJob.jobs, :size)
    end
  end
end
