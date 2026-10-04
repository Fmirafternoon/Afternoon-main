require 'rails_helper'

RSpec.describe Agent::Candidates::WizardController, type: :controller do
  let(:recruitment_office) { create(:recruitment_office) }
  let(:agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:other_agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:customer) { create(:user, :customer, terms_accepted_at: 1.day.ago) }
  let(:candidate) { create(:candidate, agent: agent) }
  let(:other_candidate) { create(:candidate, agent: other_agent) }

  before do
    # Stub embedding calls
    allow(Embedding::Create).to receive(:call).and_return(
      OpenStruct.new(embedding: Array.new(1024, 0.1))
    )
    allow(EmbeddingCache).to receive(:get_embedding).and_return(Array.new(1024, 0.1))
  end

  describe 'authentication and authorization' do
    context 'when not logged in' do
      it 'redirects to sign in' do
        get :show, params: { candidate_id: candidate.id, id: 'personal_info' }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as non-agent' do
      before { sign_in customer }

      it 'redirects to root with alert' do
        get :show, params: { candidate_id: candidate.id, id: 'personal_info' }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Vous n'êtes pas autorisé à accéder à cette page.")
      end
    end

    context 'when accessing another agent\'s candidate' do
      before { sign_in agent }

      it 'creates a new candidate for the current agent' do
        # When the candidate_id doesn't belong to current agent, a new candidate is created
        get :show, params: { candidate_id: other_candidate.id, id: 'personal_info' }
        expect(assigns(:candidate)).not_to eq(other_candidate)
        expect(assigns(:candidate).agent).to eq(agent)
      end
    end
  end

  describe 'GET #show' do
    before { sign_in agent }

    Candidate::WIZARD_STEPS.each do |step|
      context "for step #{step}" do
        it 'renders the wizard' do
          get :show, params: { candidate_id: candidate.id, id: step }
          expect(response).to have_http_status(:ok)
          expect(response).to render_template("agent/candidates/wizard/#{step}")
        end

        it 'sets the appropriate form object' do
          get :show, params: { candidate_id: candidate.id, id: step }
          expect(assigns(:form)).to be_present
          expect(assigns(:form)).to be_a(Candidate::BaseForm) if defined?(Candidate::BaseForm)
        end
      end
    end

    context 'with validation param' do
      it 'validates the form' do
        allow_any_instance_of(Candidate::PersonalInfoForm).to receive(:valid?).and_return(true)
        get :show, params: { candidate_id: candidate.id, id: 'personal_info', validate: true }
        expect(assigns(:form)).to be_present
      end
    end
  end

  describe 'PUT #update' do
    before { sign_in agent }

    context 'personal_info step' do
      let(:params) do
        {
          candidate_id: candidate.id,
          id: 'personal_info',
          wizard_form: {
            first_name: 'John',
            last_name: 'Doe',
            email: 'john@example.com',
            phone_number: '+33612345678'
          }
        }
      end

      it 'updates candidate and redirects to next step' do
        allow_any_instance_of(Candidate::PersonalInfoForm).to receive(:save).and_return(true)
        put :update, params: params
        expect(response).to redirect_to(agent_candidate_wizard_path(candidate, 'motivations'))
      end

      it 'renders wizard on validation failure' do
        allow_any_instance_of(Candidate::PersonalInfoForm).to receive(:save).and_return(false)
        put :update, params: params
        expect(response).to render_template("agent/candidates/wizard/personal_info")
      end
    end

    context 'skills step with add_skill action' do
      let(:params) do
        {
          candidate_id: candidate.id,
          id: 'skills',
          commit: 'add_skill',
          wizard_form: {
            skill_name: 'Ruby'
          }
        }
      end

      it 'adds skill and redirects to current step' do
        allow_any_instance_of(Candidate::SkillsForm).to receive(:persist_skill!).and_return(true)
        put :update, params: params
        expect(response).to redirect_to(agent_candidate_wizard_path(candidate, 'skills'))
      end

      it 'renders wizard on failure' do
        allow_any_instance_of(Candidate::SkillsForm).to receive(:persist_skill!).and_return(false)
        put :update, params: params
        expect(response).to render_template("agent/candidates/wizard/skills")
      end
    end

    context 'skills step with add_language action' do
      let(:params) do
        {
          candidate_id: candidate.id,
          id: 'skills',
          commit: 'add_language',
          wizard_form: {
            language_name: 'French',
            language_level: 'fluent'
          }
        }
      end

      it 'adds language and redirects to current step' do
        allow_any_instance_of(Candidate::SkillsForm).to receive(:persist_language!).and_return(true)
        put :update, params: params
        expect(response).to redirect_to(agent_candidate_wizard_path(candidate, 'skills'))
      end
    end

    context 'skills step with add_sector action' do
      let(:params) do
        {
          candidate_id: candidate.id,
          id: 'skills',
          commit: 'add_sector',
          wizard_form: {
            sector_id: '1'
          }
        }
      end

      it 'adds sector and redirects to current step' do
        allow_any_instance_of(Candidate::SkillsForm).to receive(:persist_sector!).and_return(true)
        put :update, params: params
        expect(response).to redirect_to(agent_candidate_wizard_path(candidate, 'skills'))
      end
    end

    context 'employments step' do
      let(:params) do
        {
          candidate_id: candidate.id,
          id: 'employments',
          commit: 'add_employment',
          wizard_form: {
            company_name: 'Test Company',
            job_title: 'Developer'
          }
        }
      end

      it 'adds employment and redirects to current step' do
        allow_any_instance_of(Candidate::EmploymentsForm).to receive(:save).and_return(true)
        put :update, params: params
        expect(response).to redirect_to(agent_candidate_wizard_path(candidate, 'employments'))
      end

      context 'when continuing to next step' do
        let(:params) do
          {
            candidate_id: candidate.id,
            id: 'employments',
            wizard_form: {}
          }
        end

        it 'validates employments and continues' do
          allow_any_instance_of(Candidate::EmploymentsForm).to receive(:valid_employment?).and_return(true)
          put :update, params: params
          expect(response).to redirect_to(agent_candidate_wizard_path(candidate, 'educations'))
        end

        it 'renders wizard on invalid employments' do
          allow_any_instance_of(Candidate::EmploymentsForm).to receive(:valid_employment?).and_return(false)
          put :update, params: params
          expect(response).to render_template("agent/candidates/wizard/employments")
        end
      end
    end

    context 'educations step' do
      context 'when adding education' do
        let(:params) do
          {
            candidate_id: candidate.id,
            id: 'educations',
            commit: 'add_education',
            wizard_form: {
              school_name: 'University',
              degree: 'Master'
            }
          }
        end

        it 'adds education and redirects to current step' do
          allow_any_instance_of(Candidate::EducationsForm).to receive(:save).and_return(true)
          put :update, params: params
          expect(response).to redirect_to(agent_candidate_wizard_path(candidate, 'educations'))
        end
      end

      context 'when continuing' do
        let(:params) do
          {
            candidate_id: candidate.id,
            id: 'educations',
            wizard_form: {}
          }
        end

        it 'redirects to next step' do
          put :update, params: params
          expect(response).to redirect_to(agent_candidate_wizard_path(candidate, 'trainings'))
        end
      end
    end

    context 'availability step with add_mobility' do
      let(:params) do
        {
          candidate_id: candidate.id,
          id: 'availability',
          commit: 'add_mobility',
          wizard_form: {
            location_name: 'Paris'
          }
        }
      end

      it 'adds mobility and redirects to current step' do
        allow_any_instance_of(Candidate::AvailabilityForm).to receive(:save).and_return(true)
        allow_any_instance_of(Candidate::AvailabilityForm).to receive(:persist_location!).and_return(true)
        allow_any_instance_of(Candidate::AvailabilityForm).to receive(:id).and_return(candidate.id)
        
        put :update, params: params
        expect(response).to redirect_to(agent_candidate_wizard_path(candidate, 'availability'))
      end
    end

    context 'comission step (final step)' do
      let(:params) do
        {
          candidate_id: candidate.id,
          id: 'comission',
          wizard_form: {
            comission_rate: '10'
          }
        }
      end

      it 'saves and redirects to finish path' do
        allow_any_instance_of(Candidate::ComissionForm).to receive(:save).and_return(true)
        put :update, params: params
        expect(response).to redirect_to(agent_candidate_path(candidate))
      end

      it 'renders wizard on failure' do
        allow_any_instance_of(Candidate::ComissionForm).to receive(:save).and_return(false)
        put :update, params: params
        expect(response).to render_template("agent/candidates/wizard/comission")
      end
    end

    context 'motivations step' do
      let(:params) do
        {
          candidate_id: candidate.id,
          id: 'motivations',
          wizard_form: {
            looking_for: 'New challenges',
            description: 'I am looking for new opportunities'
          }
        }
      end

      it 'saves and redirects to next step' do
        allow_any_instance_of(Candidate::MotivationsForm).to receive(:save).and_return(true)
        put :update, params: params
        expect(response).to redirect_to(agent_candidate_wizard_path(candidate, 'skills'))
      end

      it 'renders wizard on failure' do
        allow_any_instance_of(Candidate::MotivationsForm).to receive(:save).and_return(false)
        put :update, params: params
        expect(response).to render_template("agent/candidates/wizard/motivations")
      end
    end

    context 'skills step without special commit' do
      let(:params) do
        {
          candidate_id: candidate.id,
          id: 'skills',
          wizard_form: {}
        }
      end

      it 'saves and redirects to next step' do
        allow_any_instance_of(Candidate::SkillsForm).to receive(:save).and_return(true)
        put :update, params: params
        expect(response).to redirect_to(agent_candidate_wizard_path(candidate, 'employments'))
      end

      it 'renders wizard on failure' do
        allow_any_instance_of(Candidate::SkillsForm).to receive(:save).and_return(false)
        put :update, params: params
        expect(response).to render_template("agent/candidates/wizard/skills")
      end
    end

    context 'skills step with failed add_sector' do
      let(:params) do
        {
          candidate_id: candidate.id,
          id: 'skills',
          commit: 'add_sector',
          wizard_form: {
            sector_id: '1'
          }
        }
      end

      it 'renders wizard on failure' do
        allow_any_instance_of(Candidate::SkillsForm).to receive(:persist_sector!).and_return(false)
        # Stub render_wizard to actually render the template
        allow(controller).to receive(:render_wizard) do |form|
          controller.render :skills
        end
        
        put :update, params: params
        expect(response).to have_http_status(:ok)
        expect(controller).to have_received(:render_wizard)
      end
    end

    context 'skills step with failed add_language' do
      let(:params) do
        {
          candidate_id: candidate.id,
          id: 'skills',
          commit: 'add_language',
          wizard_form: {
            language_name: 'French',
            language_level: 'fluent'
          }
        }
      end

      it 'renders wizard on failure' do
        allow_any_instance_of(Candidate::SkillsForm).to receive(:persist_language!).and_return(false)
        put :update, params: params
        expect(response).to render_template("agent/candidates/wizard/skills")
      end
    end

    context 'employments step with failed add_employment' do
      let(:params) do
        {
          candidate_id: candidate.id,
          id: 'employments',
          commit: 'add_employment',
          wizard_form: {
            company_name: 'Test Company',
            job_title: 'Developer'
          }
        }
      end

      it 'renders wizard on failure' do
        allow_any_instance_of(Candidate::EmploymentsForm).to receive(:save).and_return(false)
        put :update, params: params
        expect(response).to render_template("agent/candidates/wizard/employments")
      end
    end

    context 'educations step with failed add_education' do
      let(:params) do
        {
          candidate_id: candidate.id,
          id: 'educations',
          commit: 'add_education',
          wizard_form: {
              school_name: 'University',
              degree: 'Master'
          }
        }
      end

      it 'renders wizard on failure' do
        allow_any_instance_of(Candidate::EducationsForm).to receive(:save).and_return(false)
        put :update, params: params
        expect(response).to render_template("agent/candidates/wizard/educations")
      end
    end

    context 'trainings step' do
      context 'when adding training' do
        let(:params) do
          {
            candidate_id: candidate.id,
            id: 'trainings',
            commit: 'add_training',
            wizard_form: {
              name: 'Rails Training',
              organization: 'Training Co'
            }
          }
        end

        it 'adds training and redirects to current step' do
          allow_any_instance_of(Candidate::TrainingsForm).to receive(:save).and_return(true)
          put :update, params: params
          expect(response).to redirect_to(agent_candidate_wizard_path(candidate, 'trainings'))
        end

        it 'renders wizard on failure' do
          allow_any_instance_of(Candidate::TrainingsForm).to receive(:save).and_return(false)
          put :update, params: params
          expect(response).to render_template("agent/candidates/wizard/trainings")
        end
      end

      context 'when continuing' do
        let(:params) do
          {
            candidate_id: candidate.id,
            id: 'trainings',
            wizard_form: {}
          }
        end

        it 'redirects to next step' do
          put :update, params: params
          expect(response).to redirect_to(agent_candidate_wizard_path(candidate, 'referrals'))
        end
      end
    end

    context 'referrals step' do
      context 'when adding referral' do
        let(:params) do
          {
            candidate_id: candidate.id,
            id: 'referrals',
            commit: 'add_referral',
            wizard_form: {
              name: 'John Referral',
              email: 'referral@example.com'
            }
          }
        end

        it 'adds referral and redirects to current step' do
          allow_any_instance_of(Candidate::ReferralsForm).to receive(:save).and_return(true)
          put :update, params: params
          expect(response).to redirect_to(agent_candidate_wizard_path(candidate, 'referrals'))
        end

        it 'renders wizard on failure' do
          allow_any_instance_of(Candidate::ReferralsForm).to receive(:save).and_return(false)
          put :update, params: params
          expect(response).to render_template("agent/candidates/wizard/referrals")
        end
      end

      context 'when continuing' do
        let(:params) do
          {
            candidate_id: candidate.id,
            id: 'referrals',
            wizard_form: {}
          }
        end

        it 'redirects to next step' do
          put :update, params: params
          expect(response).to redirect_to(agent_candidate_wizard_path(candidate, 'availability'))
        end
      end
    end

    context 'availability step without add_mobility' do
      let(:params) do
        {
          candidate_id: candidate.id,
          id: 'availability',
          wizard_form: {
            availability_notice: 'immediate'
          }
        }
      end

      it 'saves and redirects to next step' do
        allow_any_instance_of(Candidate::AvailabilityForm).to receive(:save).and_return(true)
        put :update, params: params
        expect(response).to redirect_to(agent_candidate_wizard_path(candidate, 'comission'))
      end

      it 'renders wizard on failure' do
        allow_any_instance_of(Candidate::AvailabilityForm).to receive(:save).and_return(false)
        put :update, params: params
        expect(response).to render_template("agent/candidates/wizard/availability")
      end
    end

    context 'availability step with failed add_mobility' do
      let(:params) do
        {
          candidate_id: candidate.id,
          id: 'availability',
          commit: 'add_mobility',
          wizard_form: {
            location_name: 'Paris'
          }
        }
      end

      it 'renders wizard on save failure' do
        allow_any_instance_of(Candidate::AvailabilityForm).to receive(:save).and_return(false)
        put :update, params: params
        expect(response).to render_template("agent/candidates/wizard/availability")
      end
    end
  end

  describe 'helper methods' do
    before { sign_in agent }

    describe '#current_wizard_path' do
      it 'returns the path for current step' do
        get :show, params: { candidate_id: candidate.id, id: 'skills' }
        expect(controller.current_wizard_path).to eq(agent_candidate_wizard_path(candidate, 'skills'))
      end
    end

    describe '#next_wizard_path' do
      it 'returns the path for next step' do
        get :show, params: { candidate_id: candidate.id, id: 'personal_info' }
        expect(controller.next_wizard_path).to eq(agent_candidate_wizard_path(candidate, 'motivations'))
      end

      it 'returns finish path for last step' do
        get :show, params: { candidate_id: candidate.id, id: 'comission' }
        expect(controller.next_wizard_path).to eq(agent_candidate_path(candidate))
      end
    end

    describe '#previous_wizard_path' do
      it 'returns the path for previous step' do
        get :show, params: { candidate_id: candidate.id, id: 'motivations' }
        expect(controller.previous_wizard_path).to eq(agent_candidate_wizard_path(candidate, 'personal_info'))
      end

      it 'returns candidates path for first step' do
        get :show, params: { candidate_id: candidate.id, id: 'personal_info' }
        expect(controller.previous_wizard_path).to eq(agent_candidates_path)
      end
    end

    describe '#step_accessible?' do
      it 'returns true for persisted candidate' do
        controller.instance_variable_set(:@candidate, candidate)
        expect(controller.send(:step_accessible?, 'skills')).to be true
      end

      it 'returns false for non-persisted candidate' do
        new_candidate = Candidate.new
        controller.instance_variable_set(:@candidate, new_candidate)
        expect(controller.send(:step_accessible?, 'skills')).to be false
      end
    end

    describe '#step_path' do
      it 'returns path for persisted candidate' do
        controller.instance_variable_set(:@candidate, candidate)
        expect(controller.send(:step_path, 'skills')).to eq(agent_candidate_wizard_path(candidate, 'skills'))
      end

      it 'returns nil for non-persisted candidate' do
        new_candidate = Candidate.new
        controller.instance_variable_set(:@candidate, new_candidate)
        expect(controller.send(:step_path, 'skills')).to be_nil
      end
    end

    describe '#finish_wizard_path' do
      it 'returns candidate path' do
        controller.instance_variable_set(:@candidate, candidate)
        expect(controller.send(:finish_wizard_path)).to eq(agent_candidate_path(candidate))
      end
    end

    describe '.wizard_steps' do
      it 'returns the wizard steps' do
        # The class method wizard_steps delegates to the wicked gem's steps method
        # which returns the steps in a special format
        expect(described_class).to respond_to(:wizard_steps)
        # We can verify the steps are set correctly through an instance
        get :show, params: { candidate_id: candidate.id, id: 'personal_info' }
        expect(controller.wizard_steps).to eq(Candidate::WIZARD_STEPS)
      end
    end
  end

  describe 'edge cases' do
    before { sign_in agent }

    context 'when wizard_form params are missing' do
      it 'handles missing params gracefully' do
        # When params are missing, the form will likely fail validation
        allow_any_instance_of(Candidate::PersonalInfoForm).to receive(:save).and_return(false)
        put :update, params: { candidate_id: candidate.id, id: 'personal_info' }
        expect(response).to render_template("agent/candidates/wizard/personal_info")
      end
    end

    context 'when candidate does not exist' do
      it 'creates a new candidate' do
        get :show, params: { candidate_id: 'non-existent', id: 'personal_info' }
        expect(assigns(:candidate)).to be_a_new(Candidate)
        expect(assigns(:candidate).agent).to eq(agent)
      end
    end

    context 'form class generation' do
      it 'correctly generates form class for each step' do
        get :show, params: { candidate_id: candidate.id, id: 'personal_info' }
        expect(controller.send(:form_class)).to eq(Candidate::PersonalInfoForm)

        get :show, params: { candidate_id: candidate.id, id: 'skills' }
        expect(controller.send(:form_class)).to eq(Candidate::SkillsForm)
      end
    end

    context 'set_form_from_database for all relevant steps' do
      %i[personal_info motivations availability comission].each do |step|
        it "correctly sets form from database for #{step}" do
          get :show, params: { candidate_id: candidate.id, id: step }
          expect(assigns(:form)).to be_present
          expect(assigns(:form).class).to eq("Candidate::#{step.to_s.camelize}Form".constantize)
        end
      end
    end

    context 'set_form_from_wizard_params' do
      it 'merges candidate id with wizard params' do
        params = {
          candidate_id: candidate.id,
          id: 'personal_info',
          wizard_form: {
            first_name: 'Test'
          }
        }
        put :update, params: params
        expect(assigns(:form).id).to eq(candidate.id)
      end
    end
  end
end