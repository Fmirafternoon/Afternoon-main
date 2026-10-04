require 'rails_helper'

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { create(:user) }
  let(:warden) { double('warden') }

  describe '#connect' do
    context 'with a verified user' do
      it 'successfully connects' do
        allow(warden).to receive(:user).and_return(user)
        connect env: { 'warden' => warden }
        expect(connection).to be_present
      end

      it 'sets the current_user' do
        allow(warden).to receive(:user).and_return(user)
        connect env: { 'warden' => warden }
        expect(connection.current_user).to eq(user)
      end
    end

    context 'without a verified user' do
      it 'rejects the connection' do
        allow(warden).to receive(:user).and_return(nil)
        expect { connect env: { 'warden' => warden } }.to have_rejected_connection
      end
    end
  end

  describe '#find_verified_user' do
    it 'returns the user from warden when present' do
      allow(warden).to receive(:user).and_return(user)
      connect env: { 'warden' => warden }
      expect(connection.send(:find_verified_user)).to eq(user)
    end

    it 'returns nil when warden has no user' do
      allow(warden).to receive(:user).and_return(nil)
      # We can't test find_verified_user directly without a connection
      # but we can verify it through the connect behavior
      expect { connect env: { 'warden' => warden } }.to have_rejected_connection
    end
  end

  describe 'identified_by' do
    it 'identifies by current_user' do
      expect(described_class.identifiers).to include(:current_user)
    end

    it 'identifies by true_user' do
      expect(described_class.identifiers).to include(:true_user)
    end
  end

  describe 'impersonation support' do
    let(:admin_user) { create(:user, :super_admin) }
    let(:impersonated_user) { create(:user) }

    context 'when impersonating' do
      it 'sets current_user to the impersonated user' do
        allow(warden).to receive(:user).and_return(impersonated_user)
        allow(warden).to receive(:session).and_return({ 'impersonated_user_id' => impersonated_user.id })
        
        connect env: { 'warden' => warden }
        expect(connection.current_user).to eq(impersonated_user)
      end
    end
  end

  describe 'edge cases' do
    context 'when warden is not present in env' do
      it 'raises an error' do
        # This will cause a NoMethodError when trying to call user on nil
        expect { connect env: {} }.to raise_error(NoMethodError)
      end
    end

    context 'when env is nil' do
      it 'raises an error' do
        expect { connect env: nil }.to raise_error(TypeError)
      end
    end
  end
end