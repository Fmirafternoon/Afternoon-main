require 'rails_helper'

RSpec.describe Current, type: :model do
  describe 'inheritance' do
    it 'inherits from ActiveSupport::CurrentAttributes' do
      expect(Current.superclass).to eq(ActiveSupport::CurrentAttributes)
    end
  end

  describe 'attributes' do
    it 'defines user attribute' do
      expect(Current.instance).to respond_to(:user)
      expect(Current.instance).to respond_to(:user=)
    end
  end

  describe '#user=' do
    let(:user) { create(:user) }

    it 'sets the user attribute' do
      Current.user = user
      expect(Current.user).to eq(user)
    end



    it 'can be set to nil' do
      Current.user = user
      Current.user = nil
      expect(Current.user).to be_nil
    end
  end

  describe 'thread safety' do
    it 'maintains separate values per thread' do
      user1 = create(:user, email: 'user1@example.com')
      user2 = create(:user, email: 'user2@example.com')

      results = []

      threads = [
        Thread.new do
          Current.user = user1
          sleep 0.1 # Give other thread time to set different value
          results << Current.user
        end,
        Thread.new do
          Current.user = user2
          sleep 0.1 # Give other thread time to set different value
          results << Current.user
        end
      ]

      threads.each(&:join)

      expect(results).to contain_exactly(user1, user2)
    end
  end

  describe 'reset behavior' do
    let(:user) { create(:user) }

    it 'clears attributes after reset' do
      Current.user = user
      expect(Current.user).to eq(user)

      Current.reset
      expect(Current.user).to be_nil
    end
  end
end
