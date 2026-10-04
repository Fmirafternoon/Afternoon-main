require 'rails_helper'

RSpec.describe Customer::Projects::WizardController, type: :controller do
  let(:customer) { create(:user, :customer) }
  let(:other_customer) { create(:user, :customer) }
  let(:project) { create(:project, customer: customer, status: :draft) }

  describe 'authentication and authorization' do
    context 'when not logged in' do
      it 'redirects to sign in' do
        get :show, params: { project_id: project.id, id: :step1 }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as different customer' do
      before { sign_in other_customer }

      it 'raises not found error' do
        expect {
          get :show, params: { project_id: project.id, id: :step1 }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'GET #show' do
    before { sign_in customer }

    context 'with project_id "new"' do
      it 'builds a new project without persisting and renders step1' do
        expect {
          get :show, params: { project_id: 'new', id: :step1 }
        }.not_to change(Project, :count)

        expect(assigns(:project)).to be_a_new(Project)
        expect(assigns(:project).draft?).to be true
        expect(response).to be_successful
      end
    end

    context 'step1' do
      it 'returns success' do
        get :show, params: { project_id: project.id, id: :step1 }
        expect(response).to be_successful
      end

      it 'assigns the form' do
        get :show, params: { project_id: project.id, id: :step1 }
        expect(assigns(:form)).to be_a(Customer::ProjectStep1Form)
      end
    end

    context 'step2' do
      it 'returns success' do
        get :show, params: { project_id: project.id, id: :step2 }
        expect(response).to be_successful
      end

      it 'assigns the form' do
        get :show, params: { project_id: project.id, id: :step2 }
        expect(assigns(:form)).to be_a(Customer::ProjectStep2Form)
      end
    end

    context 'step3' do
      it 'returns success' do
        get :show, params: { project_id: project.id, id: :step3 }
        expect(response).to be_successful
      end

      it 'assigns the form' do
        get :show, params: { project_id: project.id, id: :step3 }
        expect(assigns(:form)).to be_a(Customer::ProjectStep3Form)
      end
    end

  end

  describe 'PUT #update' do
    before { sign_in customer }

    context 'step1 with valid params' do
      let(:valid_params) do
        {
          project_id: project.id,
          id: :step1,
          wizard_form: {
            position_name: 'Chef de cuisine',
            location_city: 'Paris',
            contract_type: 'CDI',
            start_date: 1.month.from_now.to_date,
            description: 'Description du poste'
          }
        }
      end

      it 'updates the project' do
        put :update, params: valid_params
        project.reload

        expect(project.position_name).to eq('Chef de cuisine')
        expect(project.contract_type).to eq('CDI')
        expect(project.location.city).to eq('Paris')
      end

      it 'redirects to step2' do
        put :update, params: valid_params
        expect(response).to redirect_to(customer_project_wizard_path(project, :step2))
      end
    end

    context 'step1 with invalid params' do
      let(:invalid_params) do
        {
          project_id: project.id,
          id: :step1,
          wizard_form: {
            position_name: '',
            location_city: '',
            contract_type: ''
          }
        }
      end

      it 'does not update the project' do
        put :update, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(assigns(:form).errors).to be_present
      end
    end

    context 'step2 with valid params' do
      let(:valid_params) do
        {
          project_id: project.id,
          id: :step2,
          wizard_form: {
            skills: [
              { name: 'Cuisine', required: '1' },
              { name: 'Management', required: '0' }
            ],
            min_experience_years: 5,
            education_level: 'bac_pro',
            desired_availability: 'immediate'
          }
        }
      end

      it 'updates the project with criteria' do
        put :update, params: valid_params
        project.reload

        expect(project.min_experience_years).to eq(5)
        expect(project.skills.pluck(:name)).to contain_exactly('Cuisine', 'Management')
      end

      it 'persists the required flag on each skill' do
        put :update, params: valid_params
        project.reload

        required_by_name = project.project_skills.includes(:skill).to_h { |ps| [ps.skill.name, ps.required] }
        expect(required_by_name).to eq('Cuisine' => true, 'Management' => false)
      end

      it 'redirects to step3' do
        put :update, params: valid_params
        expect(response).to redirect_to(customer_project_wizard_path(project, :step3))
      end
    end

    context 'step3 (récapitulatif et publication)' do
      let(:valid_params) do
        {
          project_id: project.id,
          id: :step3,
          wizard_form: { broadcast_enabled: '1' }
        }
      end

      it 'enables the broadcast on the project' do
        put :update, params: valid_params
        project.reload

        expect(project.broadcast_enabled?).to be true
      end

      it 'disables the broadcast when unchecked' do
        project.update!(broadcast_enabled: true)

        put :update, params: valid_params.deep_merge(wizard_form: { broadcast_enabled: '0' })
        project.reload

        expect(project.broadcast_enabled?).to be false
      end

      it 'activates the project' do
        put :update, params: valid_params
        project.reload

        expect(project.active?).to be true
      end

      it 'redirects to project show with success notice' do
        put :update, params: valid_params
        expect(response).to redirect_to(customer_project_path(project))
        expect(flash[:notice]).to be_present
      end
    end
  end
end
