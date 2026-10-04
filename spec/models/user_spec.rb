require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should belong_to(:recruitment_office).optional }
    it { should belong_to(:company).optional }
    it { should have_many(:candidates).with_foreign_key('agent_id') }
    it { should have_many(:saved_searches).with_foreign_key('customer_id').dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:role) }

    context 'when user is an agent' do
      subject { build(:user, role: :agent_user) }

      it { should validate_presence_of(:recruitment_office_id) }
    end

    context 'when user is not an agent' do
      subject { build(:user, role: :customer) }

      it { should_not validate_presence_of(:recruitment_office_id) }
    end
  end

  describe 'enums' do
    it 'defines role enum' do
      expect(User.roles.keys).to include('super_admin', 'agent_manager', 'agent_user', 'customer')
    end
  end

  describe 'scopes' do
    describe '.agent' do
      let!(:super_admin) { create(:user, :super_admin) }
      let!(:agent_manager) { create(:user, :agent_manager) }
      let!(:agent_user) { create(:user, :agent_user) }
      let!(:customer) { create(:user, :customer) }

      it 'returns only agent roles' do
        agents = User.agent
        expect(agents).to include(agent_manager, agent_user)
        expect(agents).not_to include(super_admin, customer)
      end
    end
  end

  describe 'devise modules' do
    it 'includes database_authenticatable' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it 'includes registerable' do
      expect(User.devise_modules).to include(:registerable)
    end

    it 'includes recoverable' do
      expect(User.devise_modules).to include(:recoverable)
    end

    it 'includes rememberable' do
      expect(User.devise_modules).to include(:rememberable)
    end

    it 'includes validatable' do
      expect(User.devise_modules).to include(:validatable)
    end
  end

  describe 'callbacks' do
    describe 'before_create :generate_password_token' do
      it 'generates password_token before creation' do
        user = build(:user, password_token: nil)
        user.save!
        expect(user.password_token).to be_present
      end

      it 'generates unique password_token' do
        user1 = create(:user)
        user2 = create(:user)
        expect(user1.password_token).not_to eq(user2.password_token)
      end
    end
  end

  describe '#agent?' do
    context 'when user is agent_manager' do
      let(:user) { build(:user, role: :agent_manager) }

      it 'returns true' do
        expect(user.agent?).to be_truthy
      end
    end

    context 'when user is agent_user' do
      let(:user) { build(:user, role: :agent_user) }

      it 'returns true' do
        expect(user.agent?).to be_truthy
      end
    end

    context 'when user is super_admin' do
      let(:user) { build(:user, role: :super_admin) }

      it 'returns false' do
        expect(user.agent?).to be_falsey
      end
    end

    context 'when user is customer' do
      let(:user) { build(:user, role: :customer) }

      it 'returns false' do
        expect(user.agent?).to be_falsey
      end
    end
  end

  describe '#customer_onboarded?' do
    context 'with all required fields' do
      let(:user) do
        build(:user,
          first_name: 'John',
          last_name: 'Doe',
          email: 'john@example.com',
          phone_number: '0123456789'
        )
      end

      it 'returns true' do
        expect(user.customer_onboarded?).to be_truthy
      end
    end

    context 'missing first_name' do
      let(:user) do
        build(:user,
          first_name: nil,
          last_name: 'Doe',
          email: 'john@example.com',
          phone_number: '0123456789'
        )
      end

      it 'returns false' do
        expect(user.customer_onboarded?).to be_falsey
      end
    end

    context 'missing last_name' do
      let(:user) do
        build(:user,
          first_name: 'John',
          last_name: nil,
          email: 'john@example.com',
          phone_number: '0123456789'
        )
      end

      it 'returns false' do
        expect(user.customer_onboarded?).to be_falsey
      end
    end

    context 'missing email' do
      let(:user) do
        build(:user,
          first_name: 'John',
          last_name: 'Doe',
          email: nil,
          phone_number: '0123456789'
        )
      end

      it 'returns false' do
        expect(user.customer_onboarded?).to be_falsey
      end
    end

    context 'missing phone_number' do
      let(:user) do
        build(:user,
          first_name: 'John',
          last_name: 'Doe',
          email: 'john@example.com',
          phone_number: nil
        )
      end

      it 'returns false' do
        expect(user.customer_onboarded?).to be_falsey
      end
    end
  end

  describe '#agent_onboarded?' do
    context 'with first_name and last_name' do
      let(:user) { build(:user, first_name: 'John', last_name: 'Doe') }

      it 'returns true' do
        expect(user.agent_onboarded?).to be_truthy
      end
    end

    context 'missing first_name' do
      let(:user) { build(:user, first_name: nil, last_name: 'Doe') }

      it 'returns false' do
        expect(user.agent_onboarded?).to be_falsey
      end
    end

    context 'missing last_name' do
      let(:user) { build(:user, first_name: 'John', last_name: nil) }

      it 'returns false' do
        expect(user.agent_onboarded?).to be_falsey
      end
    end

    context 'with blank names' do
      let(:user) { build(:user, first_name: '', last_name: '') }

      it 'returns false' do
        expect(user.agent_onboarded?).to be_falsey
      end
    end
  end

  describe '#full_name' do
    context 'with both first_name and last_name' do
      let(:user) { build(:user, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }

      it 'returns combined name' do
        expect(user.full_name).to eq('John Doe')
      end
    end

    context 'with blank first_name and last_name' do
      let(:user) { build(:user, first_name: '', last_name: '', email: 'john@example.com') }

      it 'returns email' do
        expect(user.full_name).to eq('john@example.com')
      end
    end

    context 'with nil first_name and last_name' do
      let(:user) { build(:user, first_name: nil, last_name: nil, email: 'john@example.com') }

      it 'returns email' do
        expect(user.full_name).to eq('john@example.com')
      end
    end

    context 'with only first_name' do
      let(:user) { build(:user, first_name: 'John', last_name: '', email: 'john@example.com') }

      it 'returns first name with space' do
        expect(user.full_name).to eq('John ')
      end
    end

    context 'with only last_name' do
      let(:user) { build(:user, first_name: '', last_name: 'Doe', email: 'john@example.com') }

      it 'returns space with last name' do
        expect(user.full_name).to eq(' Doe')
      end
    end
  end

  describe 'constants' do
    it 'defines AGENT_ROLES' do
      expect(User::AGENT_ROLES).to eq(%w[agent_manager agent_user])
    end
  end

  describe 'discard functionality' do
    it 'includes Discard::Model' do
      expect(User.included_modules).to include(Discard::Model)
    end

    it 'can be discarded' do
      user = create(:user)
      expect(user.discarded?).to be_falsey

      user.discard
      expect(user.discarded?).to be_truthy
    end
  end

  describe 'password token generation' do
    it 'generates unique tokens' do
      user1 = create(:user, email: 'user1@example.com')
      user2 = create(:user, email: 'user2@example.com')

      expect(user1.password_token).to be_present
      expect(user2.password_token).to be_present
      expect(user1.password_token).not_to eq(user2.password_token)
    end
  end

  describe 'average completion' do
    describe '#calculate_average_completion_percentage' do
      it 'returns nil for non-agent users' do
        expect(create(:user, :customer).calculate_average_completion_percentage).to be_nil
      end

      it 'returns nil for an agent without published candidates' do
        agent = create(:user, :agent_user)
        create(:candidate, agent: agent, publication_status: :draft)

        expect(agent.calculate_average_completion_percentage).to be_nil
      end

      it 'averages the completion of published, kept candidates only' do
        agent = create(:user, :agent_user)
        published = create(:candidate, agent: agent, publication_status: :published)
        create(:candidate, agent: agent, publication_status: :draft)
        archived = create(:candidate, agent: agent, publication_status: :published)
        archived.discard

        published.update_column(:completion_percentage, 30)
        archived.update_column(:completion_percentage, 100)

        expect(agent.calculate_average_completion_percentage).to eq(30)
      end
    end

    describe '#recalculate_average_completion_percentage!' do
      it 'stores the average on the user' do
        agent = create(:user, :agent_user)
        candidate = create(:candidate, agent: agent, publication_status: :published)
        candidate.update_column(:completion_percentage, 55)

        agent.recalculate_average_completion_percentage!
        expect(agent.reload.average_completion_percentage).to eq(55)
      end
    end

    describe '#low_completion_alert?' do
      it 'is true at 40% or below, false above or when nil' do
        user = build(:user, :agent_user, average_completion_percentage: 40)
        expect(user.low_completion_alert?).to be true

        user.average_completion_percentage = 41
        expect(user.low_completion_alert?).to be false

        user.average_completion_percentage = nil
        expect(user.low_completion_alert?).to be false
      end
    end
  end
end
