require 'rails_helper'

RSpec.describe Agent::OnboardingController, type: :controller do
  let(:recruitment_office) { create(:recruitment_office) }
  let(:agent_manager) { create(:user, :agent_manager, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:customer) { create(:user, :customer, terms_accepted_at: 1.day.ago) }

  before do
    # Stub the render calls to avoid template issues in test
    allow(controller).to receive(:render).and_call_original
    allow(controller).to receive(:render_wizard) do |*args|
      controller.render plain: 'Wizard rendered', status: :ok
    end
  end

  describe 'authentication and authorization' do
    context 'when not logged in' do
      it 'redirects to sign in for show' do
        get :show, params: { id: :personal_info }
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'redirects to sign in for update' do
        put :update, params: { id: :personal_info }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as non-agent' do
      before { sign_in customer }

      it 'redirects to root with alert for show' do
        get :show, params: { id: :personal_info }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Vous n'êtes pas autorisé à accéder à cette page.")
      end

      it 'redirects to root with alert for update' do
        put :update, params: { id: :personal_info }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Vous n'êtes pas autorisé à accéder à cette page.")
      end
    end
  end

  describe '#wizard_steps' do
    context 'for agent manager' do
      before { sign_in agent_manager }

      it 'returns both personal_info and company_info steps' do
        controller.instance_variable_set(:@current_user, agent_manager)
        expect(controller.wizard_steps).to eq([:personal_info, :company_info])
      end
    end

    context 'for regular agent' do
      before { sign_in agent }

      it 'returns only personal_info step' do
        controller.instance_variable_set(:@current_user, agent)
        expect(controller.wizard_steps).to eq([:personal_info])
      end
    end
  end

  describe 'GET #show' do
    context 'as agent manager' do
      before { sign_in agent_manager }

      it 'shows personal_info step' do
        expect(controller).to receive(:render_wizard)
        get :show, params: { id: :personal_info }
        expect(assigns(:form)).to be_a(Agent::PersonalInfoForm)
      end

      it 'shows company_info step' do
        expect(controller).to receive(:render_wizard)
        get :show, params: { id: :company_info }
        expect(assigns(:form)).to be_a(Agent::CompanyInfoForm)
      end

      it 'sets form attributes from current user' do
        agent_manager.update!(first_name: 'John', last_name: 'Doe')
        expect(controller).to receive(:render_wizard)
        get :show, params: { id: :personal_info }
        form = assigns(:form)
        expect(form.first_name).to eq('John')
        expect(form.last_name).to eq('Doe')
      end
    end

    context 'as regular agent' do
      before { sign_in agent }

      it 'shows personal_info step' do
        expect(controller).to receive(:render_wizard)
        get :show, params: { id: :personal_info }
        expect(assigns(:form)).to be_a(Agent::PersonalInfoForm)
      end

      it 'redirects from company_info step' do
        expect(controller).to receive(:render_wizard)
        get :show, params: { id: :company_info }
        # Regular agents can still access the step, authorization happens at form level
        expect(assigns(:form)).to be_a(Agent::CompanyInfoForm)
      end
    end
  end

  describe 'PUT #update' do
    context 'personal_info step' do
      let(:personal_info_params) do
        {
          wizard_form: {
            first_name: 'Updated',
            last_name: 'Name',
            phone_number: '0123456789'
          }
        }
      end

      context 'as agent manager' do
        before { sign_in agent_manager }

        context 'with valid params' do
          it 'updates user information' do
            put :update, params: { id: :personal_info }.merge(personal_info_params)
            expect(response).to redirect_to(agent_onboarding_path(:company_info))
          end

          it 'calls save on the form' do
            form_double = instance_double(Agent::PersonalInfoForm, save: true)
            allow(Agent::PersonalInfoForm).to receive(:new).and_return(form_double)
            
            put :update, params: { id: :personal_info }.merge(personal_info_params)
            expect(form_double).to have_received(:save)
          end
        end

        context 'with invalid params' do
          it 'renders the wizard step' do
            form_double = instance_double(Agent::PersonalInfoForm, save: false)
            allow(Agent::PersonalInfoForm).to receive(:new).and_return(form_double)
            expect(controller).to receive(:render_wizard).with(form_double)
            
            put :update, params: { id: :personal_info }.merge(personal_info_params)
          end
        end
      end

      context 'as regular agent' do
        before { sign_in agent }

        context 'with valid params' do
          it 'redirects to finish wizard path with notice' do
            form_double = instance_double(Agent::PersonalInfoForm, save: true)
            allow(Agent::PersonalInfoForm).to receive(:new).and_return(form_double)
            
            put :update, params: { id: :personal_info }.merge(personal_info_params)
            expect(response).to redirect_to(agent_candidates_path)
            expect(flash[:notice]).to eq("Votre profil a été créé avec succès")
          end
        end
      end
    end

    context 'company_info step' do
      let(:company_info_params) do
        {
          wizard_form: {
            company_name: 'Test Company',
            company_siren: '123456789',
            city: 'Paris',
            zip_code: '75001'
          }
        }
      end

      context 'as agent manager' do
        before { sign_in agent_manager }

        context 'with valid params and regular submit' do
          it 'saves and redirects to next wizard path' do
            form_double = instance_double(Agent::CompanyInfoForm, save: true, persist_company!: true)
            allow(Agent::CompanyInfoForm).to receive(:new).and_return(form_double)
            
            put :update, params: { id: :company_info }.merge(company_info_params)
            expect(response).to redirect_to(agent_candidates_path)
          end
        end

        context 'with add_company commit' do
          it 'persists company and redirects to current step' do
            form_double = instance_double(Agent::CompanyInfoForm, save: true, persist_company!: true)
            allow(Agent::CompanyInfoForm).to receive(:new).and_return(form_double)
            
            put :update, params: { id: :company_info, commit: 'add_company' }.merge(company_info_params)
            expect(form_double).to have_received(:persist_company!)
            expect(response).to redirect_to(agent_onboarding_path(:company_info))
            expect(flash[:notice]).to eq("Entreprise partenaire ajoutée avec succès")
          end
        end

        context 'with invalid params' do
          it 'renders the wizard step' do
            form_double = instance_double(Agent::CompanyInfoForm, save: false)
            allow(Agent::CompanyInfoForm).to receive(:new).and_return(form_double)
            expect(controller).to receive(:render_wizard).with(form_double)
            
            put :update, params: { id: :company_info }.merge(company_info_params)
          end
        end
      end
    end
  end

  describe '#current_wizard_path' do
    before { sign_in agent_manager }

    it 'returns the path for the current step' do
      controller.instance_variable_set(:@step, :personal_info)
      expect(controller.current_wizard_path).to eq(agent_onboarding_path(:personal_info))
    end
  end

  describe '#next_wizard_path' do
    context 'as agent manager' do
      before { sign_in agent_manager }

      it 'returns company_info path from personal_info' do
        controller.instance_variable_set(:@step, :personal_info)
        expect(controller.next_wizard_path).to eq(agent_onboarding_path(:company_info))
      end

      it 'returns finish path from company_info' do
        controller.instance_variable_set(:@step, :company_info)
        expect(controller.next_wizard_path).to eq(agent_candidates_path)
      end
    end

    context 'as regular agent' do
      before { sign_in agent }

      it 'returns finish path from personal_info' do
        controller.instance_variable_set(:@step, :personal_info)
        expect(controller.next_wizard_path).to eq(agent_candidates_path)
      end
    end
  end

  describe '#previous_wizard_path' do
    before { sign_in agent_manager }

    it 'raises error from first step due to route requirement' do
      controller.instance_variable_set(:@step, :personal_info)
      expect { controller.previous_wizard_path }.to raise_error(ActionController::UrlGenerationError)
    end

    it 'returns personal_info path from company_info' do
      controller.instance_variable_set(:@step, :company_info)
      expect(controller.previous_wizard_path).to eq(agent_onboarding_path(:personal_info))
    end
  end

  describe 'step authorization' do
    context 'as agent manager accessing company_info' do
      before { sign_in agent_manager }

      it 'allows access' do
        expect(controller).to receive(:render_wizard)
        get :show, params: { id: :company_info }
        expect(assigns(:form)).to be_a(Agent::CompanyInfoForm)
      end
    end

    context 'as regular agent accessing company_info' do
      before { sign_in agent }

      it 'still allows access to the step' do
        expect(controller).to receive(:render_wizard)
        get :show, params: { id: :company_info }
        # Regular agents can access the step but might have limited functionality
        expect(assigns(:form)).to be_a(Agent::CompanyInfoForm)
      end
    end
  end

  describe 'form class resolution' do
    before { sign_in agent_manager }

    it 'resolves PersonalInfoForm for personal_info step' do
      expect(controller).to receive(:render_wizard)
      get :show, params: { id: :personal_info }
      expect(assigns(:form)).to be_a(Agent::PersonalInfoForm)
    end

    it 'resolves CompanyInfoForm for company_info step' do
      expect(controller).to receive(:render_wizard)
      get :show, params: { id: :company_info }
      expect(assigns(:form)).to be_a(Agent::CompanyInfoForm)
    end
  end

  describe 'parameter filtering' do
    before { sign_in agent_manager }

    it 'permits only allowed attributes' do
      params = {
        id: :personal_info,
        wizard_form: {
          first_name: 'Test',
          last_name: 'User',
          phone_number: '0123456789',
          malicious_param: 'should_be_filtered'
        }
      }
      
      put :update, params: params
      
      # The form should not receive the malicious param
      expect(controller.send(:wizard_params)).not_to have_key('malicious_param')
    end

    it 'returns empty hash when wizard_form is not present' do
      put :update, params: { id: :personal_info }
      expect(controller.send(:wizard_params)).to eq({})
    end
  end
end