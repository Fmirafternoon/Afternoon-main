require 'rails_helper'

RSpec.describe Customer::ProjectsController, type: :controller do
  let(:customer) { create(:user, :customer, terms_accepted_at: 1.day.ago) }
  let(:other_customer) { create(:user, :customer, terms_accepted_at: 1.day.ago) }
  let(:non_customer) { create(:user, :agent_user, terms_accepted_at: 1.day.ago) }

  describe 'authentication and authorization' do
    context 'when not logged in' do
      it 'redirects to sign in' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as non-customer' do
      before { sign_in non_customer }

      it 'redirects to root with alert' do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Vous n'êtes pas autorisé à accéder à cette page.")
      end
    end
  end

  describe 'GET #index' do
    before { sign_in customer }

    let!(:active_project) { create(:project, customer: customer, status: :active) }
    let!(:draft_project) { create(:project, customer: customer, status: :draft) }
    let!(:archived_project) { create(:project, customer: customer, status: :archived) }
    let!(:other_customer_project) { create(:project, customer: other_customer, status: :active) }

    context 'without status filter (default: not archived)' do
      it 'returns only customer own non-archived projects' do
        get :index
        expect(assigns(:projects)).to include(active_project, draft_project)
        expect(assigns(:projects)).not_to include(archived_project)
        expect(assigns(:projects)).not_to include(other_customer_project)
      end

      it 'orders by created_at desc' do
        get :index
        expect(assigns(:projects).to_a).to eq([draft_project, active_project])
      end
    end

    context 'with status filter archived' do
      it 'returns only archived projects' do
        get :index, params: { status: 'archived' }
        expect(assigns(:projects)).to include(archived_project)
        expect(assigns(:projects)).not_to include(active_project, draft_project)
      end
    end

    it 'paginates results' do
      get :index
      expect(assigns(:pagy)).to be_a(Pagy)
    end
  end

  describe 'POST #rebroadcast' do
    before { sign_in customer }

    context 'when the project is broadcastable' do
      # let! : la création d'un projet actif broadcastable enqueue déjà un job via le callback,
      # il ne doit pas être compté dans les expectations ci-dessous
      let!(:project) { create(:project, :broadcast_enabled, customer: customer, status: :active) }

      it 'enqueues an EmailBroadcastJob' do
        expect {
          post :rebroadcast, params: { id: project.id }
        }.to change(Project::EmailBroadcastJob.jobs, :size).by(1)
      end

      it 'redirects to the project with a notice' do
        post :rebroadcast, params: { id: project.id }
        expect(response).to redirect_to(customer_project_path(project))
        expect(flash[:notice]).to be_present
      end
    end

    context 'when the project was broadcasted less than a week ago' do
      let!(:project) do
        create(:project, :broadcast_enabled, customer: customer, status: :active,
               last_email_broadcasted_at: 2.days.ago)
      end

      it 'does not enqueue a job and shows an alert' do
        expect {
          post :rebroadcast, params: { id: project.id }
        }.not_to change(Project::EmailBroadcastJob.jobs, :size)

        expect(flash[:alert]).to be_present
      end
    end

    context 'when the project belongs to another customer' do
      let(:project) { create(:project, :broadcast_enabled, customer: other_customer, status: :active) }

      it 'raises not found' do
        expect {
          post :rebroadcast, params: { id: project.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
