require 'rails_helper'

RSpec.describe Users::RegistrationsController, type: :controller do
  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe 'POST #create' do
    let(:valid_attributes) do
      {
        email: 'newuser@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      }
    end

    let(:invalid_attributes) do
      {
        email: '',
        password: 'short',
        password_confirmation: 'different'
      }
    end

    context 'with valid params' do
      it 'creates a new User with customer role' do
        expect {
          post :create, params: { user: valid_attributes }
        }.to change(User, :count).by(1)
        
        expect(User.last.role).to eq('customer')
      end

      it 'assigns customer role to the user' do
        post :create, params: { user: valid_attributes }
        user = User.find_by(email: 'newuser@example.com')
        expect(user.role).to eq('customer')
      end
    end

    context 'with invalid params' do
      it 'does not create a new User' do
        expect {
          post :create, params: { user: invalid_attributes }
        }.not_to change(User, :count)
      end
    end

    context 'when honeypot field is filled (bot detected)' do
      it 'does not create a user' do
        expect {
          post :create, params: { user: valid_attributes, website: 'http://spam.com' }
        }.not_to change(User, :count)
      end

      it 'redirects with success message (silent rejection)' do
        post :create, params: { user: valid_attributes, website: 'http://spam.com' }
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq(I18n.t('devise.registrations.signed_up'))
      end
    end

    context 'when honeypot field is empty (human)' do
      it 'creates the user normally' do
        expect {
          post :create, params: { user: valid_attributes, website: '' }
        }.to change(User, :count).by(1)
      end
    end

    context 'when user requires confirmation' do
      before do
        allow_any_instance_of(User).to receive(:active_for_authentication?).and_return(false)
        allow_any_instance_of(User).to receive(:inactive_message).and_return(:unconfirmed)
        allow_any_instance_of(User).to receive(:persisted?).and_return(true)
      end

      it 'creates the user but does not sign them in' do
        expect {
          post :create, params: { user: valid_attributes }
        }.to change(User, :count).by(1)
      end
    end
  end
end