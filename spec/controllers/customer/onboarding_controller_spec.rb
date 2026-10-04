require 'rails_helper'

RSpec.describe Customer::OnboardingController, type: :controller do
  let(:company) { create(:company) }
  let(:customer) { create(:user, :customer, company: company, terms_accepted_at: 1.day.ago) }
  let(:customer_without_company) { create(:user, :customer, company: nil, terms_accepted_at: 1.day.ago) }
  let(:agent_manager) { create(:user, :agent_manager, terms_accepted_at: 1.day.ago) }
  let(:agent) { create(:user, :agent_user, terms_accepted_at: 1.day.ago) }

  describe 'authentication' do
    context 'when not logged in' do
      it 'redirects to sign in' do
        get :show, params: { id: 'personal_info' }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as non-customer' do
      before { sign_in agent }

      it 'redirects to root with alert' do
        get :show, params: { id: 'personal_info' }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Vous n'êtes pas autorisé à accéder à cette page.")
      end
    end
  end

  describe 'GET #show' do
    before { sign_in customer }

    [:personal_info, :company_info, :positions].each do |step|
      context "for step #{step}" do
        it 'renders the wizard' do
          get :show, params: { id: step }
          expect(response).to have_http_status(:ok)
          expect(response).to render_template("customer/onboarding/#{step}")
        end

        it 'sets the form object' do
          get :show, params: { id: step }
          expect(assigns(:form)).to be_present
        end
      end
    end

    context 'with company data' do
      it 'loads company data into form' do
        get :show, params: { id: 'company_info' }
        form = assigns(:form)
        expect(form.company_name).to eq(company.name) if form.respond_to?(:company_name)
      end
    end

    context 'without company' do
      before { sign_in customer_without_company }

      it 'creates empty form' do
        get :show, params: { id: 'company_info' }
        expect(assigns(:form)).to be_present
      end
    end
  end

  describe 'PUT #update' do
    before { sign_in customer }

    context 'personal_info step' do
      let(:params) do
        {
          id: 'personal_info',
          wizard_form: {
            first_name: 'John',
            last_name: 'Doe',
            phone_number: '+33612345678'
          }
        }
      end

      context 'when form saves successfully' do
        before do
          allow_any_instance_of(Customer::PersonalInfoForm).to receive(:save).and_return(true)
        end

        it 'redirects to finish wizard path for regular customer' do
          put :update, params: params
          expect(response).to redirect_to(root_path)
          expect(flash[:notice]).to eq("Votre profil a été créé avec succès")
        end

      end

      context 'when form fails to save' do
        before do
          allow_any_instance_of(Customer::PersonalInfoForm).to receive(:save).and_return(false)
        end

        it 'renders the wizard' do
          put :update, params: params
          expect(response).to render_template('customer/onboarding/personal_info')
        end
      end
    end

    context 'company_info step' do
      let(:base_params) do
        {
          id: 'company_info',
          wizard_form: {
            company_name: 'Test Company',
            siren: '123456789'
          }
        }
      end

      context 'when adding location' do
        let(:params) { base_params.merge(commit: 'add_location') }

        it 'persists location and redirects to current step' do
          allow_any_instance_of(Customer::CompanyInfoForm).to receive(:save).and_return(true)
          allow_any_instance_of(Customer::CompanyInfoForm).to receive(:persist_location!).and_return(true)
          
          put :update, params: params
          expect(response).to redirect_to(customer_onboarding_path('company_info'))
        end
      end

      context 'when adding sector' do
        let(:params) { base_params.merge(commit: 'add_sector') }

        it 'persists sector and redirects to current step' do
          allow_any_instance_of(Customer::CompanyInfoForm).to receive(:save).and_return(true)
          allow_any_instance_of(Customer::CompanyInfoForm).to receive(:persist_sector!).and_return(true)
          
          put :update, params: params
          expect(response).to redirect_to(customer_onboarding_path('company_info'))
        end
      end

      context 'when continuing to next step' do
        let(:params) { base_params }

        it 'redirects to next step' do
          allow_any_instance_of(Customer::CompanyInfoForm).to receive(:save).and_return(true)
          
          put :update, params: params
          expect(response).to redirect_to(customer_onboarding_path('positions'))
        end
      end

      context 'when form fails to save' do
        let(:params) { base_params }

        before do
          allow_any_instance_of(Customer::CompanyInfoForm).to receive(:save).and_return(false)
        end

        it 'renders the wizard' do
          put :update, params: params
          expect(response).to render_template('customer/onboarding/company_info')
        end
      end
    end

    context 'positions step' do
      let(:base_params) do
        {
          id: 'positions',
          wizard_form: {
            position_title: 'Developer'
          }
        }
      end

      context 'when adding position' do
        let(:params) { base_params.merge(commit: 'add_position') }

        it 'saves and redirects to current step' do
          allow_any_instance_of(Customer::PositionsForm).to receive(:save).and_return(true)
          
          put :update, params: params
          expect(response).to redirect_to(customer_onboarding_path('positions'))
        end

        it 'renders wizard on failure' do
          allow_any_instance_of(Customer::PositionsForm).to receive(:save).and_return(false)
          
          put :update, params: params
          expect(response).to render_template('customer/onboarding/positions')
        end
      end

      context 'when continuing' do
        let(:params) { base_params }

        it 'redirects to next step' do
          put :update, params: params
          expect(response).to redirect_to(root_path) # finish_wizard_path
        end
      end
    end
  end

  describe 'helper methods' do
    before { sign_in customer }

    describe '#current_wizard_path' do
      it 'returns the path for current step' do
        get :show, params: { id: 'company_info' }
        expect(controller.current_wizard_path).to eq(customer_onboarding_path('company_info'))
      end
    end

    describe '#next_wizard_path' do
      it 'returns the path for next step' do
        get :show, params: { id: 'personal_info' }
        expect(controller.next_wizard_path).to eq(customer_onboarding_path('company_info'))
      end

      it 'returns finish path for last step' do
        get :show, params: { id: 'positions' }
        expect(controller.next_wizard_path).to eq(root_path)
      end
    end

    describe '#previous_wizard_path' do
      it 'returns the path for previous step' do
        get :show, params: { id: 'company_info' }
        expect(controller.previous_wizard_path).to eq(customer_onboarding_path('personal_info'))
      end

      it 'returns onboarding path for first step' do
        get :show, params: { id: 'personal_info' }
        expect(controller.previous_wizard_path).to eq(customer_onboarding_path)
      end
    end
  end
end