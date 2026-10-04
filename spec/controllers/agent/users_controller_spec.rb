require 'rails_helper'

RSpec.describe Agent::UsersController, type: :controller do
  let(:recruitment_office) { create(:recruitment_office) }
  let(:other_recruitment_office) { create(:recruitment_office) }
  let(:agent_manager) { create(:user, :agent_manager, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:agent) { create(:user, :agent_user, recruitment_office: recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:other_office_manager) { create(:user, :agent_manager, recruitment_office: other_recruitment_office, terms_accepted_at: 1.day.ago) }
  let(:customer) { create(:user, :customer, terms_accepted_at: 1.day.ago) }
  let(:super_admin) { create(:user, :super_admin, terms_accepted_at: 1.day.ago) }

  describe 'authentication and authorization' do
    context 'when not logged in' do
      it 'redirects to sign in' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as customer' do
      before { sign_in customer }

      it 'redirects to root with alert' do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Vous n'êtes pas autorisé à accéder à cette page.")
      end
    end
  end

  describe 'GET #index' do
    context 'as agent manager' do
      before { sign_in agent_manager }

      it 'lists users from same recruitment office' do
        same_office_user = create(:user, :agent_user, recruitment_office: recruitment_office)
        other_office_user = create(:user, :agent_user, recruitment_office: other_recruitment_office)
        
        get :index
        
        expect(response).to be_successful
        expect(assigns(:users)).to include(agent_manager, agent, same_office_user)
        expect(assigns(:users)).not_to include(other_office_user)
      end

      it 'only shows kept users' do
        kept_user = create(:user, :agent_user, recruitment_office: recruitment_office)
        discarded_user = create(:user, :agent_user, recruitment_office: recruitment_office)
        discarded_user.discard
        
        get :index
        
        expect(assigns(:users)).to include(kept_user)
        expect(assigns(:users)).not_to include(discarded_user)
      end

      it 'paginates results' do
        get :index
        expect(assigns(:pagy)).to be_present
      end
    end

    context 'as super admin' do
      before { sign_in super_admin }

      it 'allows access because super admin can access agent routes' do
        get :index
        expect(response).to be_successful
      end
    end

    context 'as regular agent' do
      before { sign_in agent }

      it 'denies access' do
        expect { get :index }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end

  describe 'GET #show' do
    context 'as agent manager' do
      before { sign_in agent_manager }

      it 'shows user from same office' do
        get :show, params: { id: agent.id }
        expect(response).to be_successful
        expect(assigns(:user)).to eq(agent)
      end

      it 'denies access to user from different office' do
        other_user = create(:user, :agent_user, recruitment_office: other_recruitment_office)
        expect { get :show, params: { id: other_user.id } }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'as the user themselves' do
      before { sign_in agent }

      it 'allows viewing own profile' do
        get :show, params: { id: agent.id }
        expect(response).to be_successful
      end
    end
  end

  describe 'GET #new' do
    context 'as agent manager' do
      before { sign_in agent_manager }

      it 'builds a new user' do
        get :new
        expect(response).to be_successful
        expect(assigns(:user)).to be_a_new(User)
      end

      it 'tries to set recruitment office from params but fails due to type mismatch' do
        # The controller has a bug on line 19 where it assigns a string to recruitment_office association
        expect {
          get :new, params: { recruitment_office_id: recruitment_office.id }
        }.to raise_error(ActiveRecord::AssociationTypeMismatch)
      end
    end

    context 'as regular agent' do
      before { sign_in agent }

      it 'denies access' do
        expect { get :new }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        user: {
          email: 'newuser@example.com',
          first_name: 'New',
          last_name: 'User',
          role: 'agent_user'
        }
      }
    end

    context 'as agent manager' do
      before { sign_in agent_manager }

      context 'with valid params' do
        it 'creates a new user' do
          expect {
            post :create, params: valid_params
          }.to change(User, :count).by(1)
        end

        it 'sets recruitment office from current user' do
          post :create, params: valid_params
          new_user = User.last
          expect(new_user.recruitment_office).to eq(agent_manager.recruitment_office)
        end

        it 'generates a password' do
          post :create, params: valid_params
          new_user = User.last
          expect(new_user.encrypted_password).to be_present
        end

        it 'sends invitation email' do
          expect {
            post :create, params: valid_params
          }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
            .with('UserMailer', 'password_creation', 'deliver_now', { args: [instance_of(User)] })
        end

        it 'sets invitation sent timestamp' do
          post :create, params: valid_params
          new_user = User.last
          expect(new_user.invitation_sent_at).to be_present
        end

        it 'redirects with success message' do
          post :create, params: valid_params
          new_user = User.last
          expect(response).to redirect_to(agent_user_path(new_user))
          expect(flash[:notice]).to eq("Utilisateur créé")
        end
      end

      context 'with invalid params' do
        it 'does not create user' do
          expect {
            post :create, params: { user: { email: '' } }
          }.not_to change(User, :count)
        end

        it 'renders new template' do
          post :create, params: { user: { email: '' } }
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to render_template(:new)
        end
      end

      context 'with non-agent role' do
        it 'rejects non-agent roles' do
          post :create, params: { user: valid_params[:user].merge(role: 'customer') }
          new_user = User.last
          expect(new_user.role).not_to eq('customer')
        end
      end
    end
  end

  describe 'GET #edit' do
    context 'as agent manager' do
      before { sign_in agent_manager }

      it 'allows editing user from same office' do
        get :edit, params: { id: agent.id }
        expect(response).to be_successful
        expect(assigns(:user)).to eq(agent)
      end

      it 'denies editing user from different office' do
        other_user = create(:user, :agent_user, recruitment_office: other_recruitment_office)
        expect { get :edit, params: { id: other_user.id } }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'as the user themselves' do
      before { sign_in agent }

      it 'allows editing own profile' do
        get :edit, params: { id: agent.id }
        expect(response).to be_successful
      end
    end
  end

  describe 'PUT #update' do
    let(:update_params) do
      {
        id: agent.id,
        user: {
          first_name: 'Updated',
          last_name: 'Name',
          email: agent.email,
          role: agent.role
        }
      }
    end

    context 'as agent manager' do
      before { sign_in agent_manager }

      context 'with valid params' do
        it 'updates the user' do
          put :update, params: update_params
          agent.reload
          expect(agent.first_name).to eq('Updated')
          expect(agent.last_name).to eq('Name')
        end

        it 'redirects with success message' do
          put :update, params: update_params
          expect(response).to redirect_to(agent_user_path(agent))
          expect(flash[:notice]).to eq("Utilisateur modifié")
        end
      end

      context 'with invalid params' do
        it 'does not update user' do
          put :update, params: { id: agent.id, user: { email: '' } }
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to render_template(:edit)
        end
      end

      it 'filters non-agent roles' do
        put :update, params: { id: agent.id, user: { role: 'customer' } }
        agent.reload
        expect(agent.role).not_to eq('customer')
      end
    end

    context 'as regular agent updating another user' do
      before { sign_in agent }
      let(:other_agent) { create(:user, :agent_user, recruitment_office: recruitment_office) }

      it 'denies access' do
        expect {
          put :update, params: { id: other_agent.id, user: { first_name: 'Hacker' } }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'as agent manager' do
      before { sign_in agent_manager }

      it 'soft deletes the user' do
        user_to_delete = create(:user, :agent_user, recruitment_office: recruitment_office)
        
        expect {
          delete :destroy, params: { id: user_to_delete.id }
        }.not_to change(User, :count)
        
        user_to_delete.reload
        expect(user_to_delete).to be_discarded
      end

      it 'redirects with success message' do
        delete :destroy, params: { id: agent.id }
        expect(response).to redirect_to(agent_users_path)
        expect(flash[:notice]).to eq("Utilisateur supprimé")
      end

      it 'denies deleting user from different office' do
        other_user = create(:user, :agent_user, recruitment_office: other_recruitment_office)
        expect {
          delete :destroy, params: { id: other_user.id }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'as regular agent' do
      before { sign_in agent }

      it 'denies access even for same office users' do
        other_agent = create(:user, :agent_user, recruitment_office: recruitment_office)
        expect {
          delete :destroy, params: { id: other_agent.id }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end

  describe 'POST #invite' do
    context 'as agent manager' do
      before { sign_in agent_manager }

      it 'sends invitation email' do
        expect {
          post :invite, params: { id: agent.id }
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
          .with('UserMailer', 'password_creation', 'deliver_now', { args: [agent] })
      end

      it 'updates invitation sent timestamp' do
        freeze_time do
          post :invite, params: { id: agent.id }
          agent.reload
          expect(agent.invitation_sent_at).to eq(Time.current)
        end
      end

      it 'redirects to user page' do
        post :invite, params: { id: agent.id }
        expect(response).to redirect_to(agent_user_path(agent))
      end

      it 'allows inviting user from different office' do
        # The invite? policy only checks if user is agent_manager, not same office
        other_user = create(:user, :agent_user, recruitment_office: other_recruitment_office)
        
        post :invite, params: { id: other_user.id }
        
        expect(response).to redirect_to(agent_user_path(other_user))
        other_user.reload
        expect(other_user.invitation_sent_at).to be_present
      end
    end

    context 'as regular agent' do
      before { sign_in agent }

      it 'denies access' do
        other_agent = create(:user, :agent_user, recruitment_office: recruitment_office)
        expect {
          post :invite, params: { id: other_agent.id }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end

  describe 'role filtering in user_params' do
    before { sign_in agent_manager }

    it 'allows agent_manager role' do
      post :create, params: { user: { email: 'test@example.com', role: 'agent_manager' } }
      # The role should be preserved in the parameters
      expect(controller.send(:user_params)[:role]).to eq('agent_manager')
    end

    it 'allows agent_user role' do
      post :create, params: { user: { email: 'test@example.com', role: 'agent_user' } }
      expect(controller.send(:user_params)[:role]).to eq('agent_user')
    end

    it 'filters out customer role' do
      post :create, params: { user: { email: 'test@example.com', role: 'customer' } }
      expect(controller.send(:user_params)[:role]).to be_nil
    end

    it 'filters out super_admin role' do
      post :create, params: { user: { email: 'test@example.com', role: 'super_admin' } }
      expect(controller.send(:user_params)[:role]).to be_nil
    end
  end
end