require 'rails_helper'

RSpec.describe UserPolicy, type: :policy do
  subject { described_class }

  let(:recruitment_office) { build(:recruitment_office) }
  let(:other_office) { build(:recruitment_office) }

  let(:super_admin) { build(:user, :super_admin) }
  let(:agent_manager) { build(:user, :agent_manager, recruitment_office: recruitment_office) }
  let(:agent_user) { build(:user, :agent_user, recruitment_office: recruitment_office) }
  let(:customer) { build(:user, :customer) }
  let(:other_agent_manager) { build(:user, :agent_manager, recruitment_office: other_office) }
  let(:target_user) { build(:user, :agent_user, recruitment_office: recruitment_office) }
  let(:other_office_user) { build(:user, :agent_user, recruitment_office: other_office) }

  describe UserPolicy::Scope do
    let(:scope) { double("Scope") }

    context "when user is super admin" do
      it "returns all users" do
        expect(scope).to receive(:all).and_return("all_users")
        result = UserPolicy::Scope.new(super_admin, scope).resolve
        expect(result).to eq("all_users")
      end
    end

    context "when user is agent manager" do
      it "returns only users from same recruitment office" do
        expect(scope).to receive(:where).with(recruitment_office: recruitment_office).and_return("office_users")
        result = UserPolicy::Scope.new(agent_manager, scope).resolve
        expect(result).to eq("office_users")
      end
    end

    context "when user is regular agent or customer" do
      it "returns no users for agent user" do
        expect(scope).to receive(:none).and_return("no_users")
        result = UserPolicy::Scope.new(agent_user, scope).resolve
        expect(result).to eq("no_users")
      end

      it "returns no users for customer" do
        expect(scope).to receive(:none).and_return("no_users")
        result = UserPolicy::Scope.new(customer, scope).resolve
        expect(result).to eq("no_users")
      end
    end
  end

  describe "#index?" do
    context "when user is super admin" do
      it "permits index" do
        expect(described_class.new(super_admin, User).index?).to be_truthy
      end
    end

    context "when user is agent manager" do
      it "permits index" do
        expect(described_class.new(agent_manager, User).index?).to be_truthy
      end
    end

    context "when user is regular agent or customer" do
      it "denies index for agent user" do
        expect(described_class.new(agent_user, User).index?).to be_falsey
      end

      it "denies index for customer" do
        expect(described_class.new(customer, User).index?).to be_falsey
      end
    end
  end

  describe "#show?" do
    context "when user is super admin" do
      it "permits show for target user" do
        expect(described_class.new(super_admin, target_user).show?).to be_truthy
      end

      it "permits show for other office user" do
        expect(described_class.new(super_admin, other_office_user).show?).to be_truthy
      end
    end

    context "when user is agent manager" do
      it "permits show for same office user" do
        expect(described_class.new(agent_manager, target_user).show?).to be_truthy
      end

      it "denies show for other office user" do
        expect(described_class.new(agent_manager, other_office_user).show?).to be_falsey
      end
    end

    context "when user views themselves" do
      it "permits agent user to view themselves" do
        expect(described_class.new(agent_user, agent_user).show?).to be_truthy
      end

      it "permits customer to view themselves" do
        expect(described_class.new(customer, customer).show?).to be_truthy
      end
    end

    context "when user views others (not admin/manager)" do
      it "denies agent user from viewing others" do
        expect(described_class.new(agent_user, target_user).show?).to be_falsey
      end

      it "denies customer from viewing others" do
        expect(described_class.new(customer, target_user).show?).to be_falsey
      end
    end
  end

  describe "#new?" do
    context "when user is super admin" do
      it "permits new" do
        expect(described_class.new(super_admin, User).new?).to be_truthy
      end
    end

    context "when user is agent manager" do
      it "permits new" do
        expect(described_class.new(agent_manager, User).new?).to be_truthy
      end
    end

    context "when user is regular agent or customer" do
      it "denies new for agent user" do
        expect(described_class.new(agent_user, User).new?).to be_falsey
      end

      it "denies new for customer" do
        expect(described_class.new(customer, User).new?).to be_falsey
      end
    end
  end

  describe "#create?" do
    it "aliases to new?" do
      policy = described_class.new(super_admin, User)
      expect(policy.create?).to eq(policy.new?)
    end
  end

  describe "#edit?" do
    context "when user is super admin" do
      it "permits edit for target user" do
        expect(described_class.new(super_admin, target_user).edit?).to be_truthy
      end

      it "permits edit for other office user" do
        expect(described_class.new(super_admin, other_office_user).edit?).to be_truthy
      end
    end

    context "when user is agent manager" do
      it "permits edit for same office user" do
        expect(described_class.new(agent_manager, target_user).edit?).to be_truthy
      end

      it "denies edit for other office user" do
        expect(described_class.new(agent_manager, other_office_user).edit?).to be_falsey
      end
    end

    context "when user edits themselves" do
      it "permits agent user to edit themselves" do
        expect(described_class.new(agent_user, agent_user).edit?).to be_truthy
      end

      it "permits customer to edit themselves" do
        expect(described_class.new(customer, customer).edit?).to be_truthy
      end
    end

    context "when user edits others (not admin/manager)" do
      it "denies agent user from editing others" do
        expect(described_class.new(agent_user, target_user).edit?).to be_falsey
      end

      it "denies customer from editing others" do
        expect(described_class.new(customer, target_user).edit?).to be_falsey
      end
    end
  end

  describe "#update?" do
    it "aliases to edit?" do
      policy = described_class.new(agent_manager, target_user)
      expect(policy.update?).to eq(policy.edit?)
    end
  end

  describe "#destroy?" do
    context "when user is super admin" do
      it "permits destroy for target user" do
        expect(described_class.new(super_admin, target_user).destroy?).to be_truthy
      end

      it "permits destroy for other office user" do
        expect(described_class.new(super_admin, other_office_user).destroy?).to be_truthy
      end
    end

    context "when user is agent manager" do
      it "permits destroy for same office user" do
        expect(described_class.new(agent_manager, target_user).destroy?).to be_truthy
      end

      it "denies destroy for other office user" do
        expect(described_class.new(agent_manager, other_office_user).destroy?).to be_falsey
      end
    end

    context "when user is regular agent or customer" do
      it "denies agent user from destroying others" do
        expect(described_class.new(agent_user, target_user).destroy?).to be_falsey
      end

      it "denies customer from destroying others" do
        expect(described_class.new(customer, target_user).destroy?).to be_falsey
      end

      it "denies agent user from destroying themselves" do
        expect(described_class.new(agent_user, agent_user).destroy?).to be_falsey
      end
    end
  end

  describe "#password?" do
    context "for any user" do
      it "permits password for super admin" do
        expect(described_class.new(super_admin, target_user).password?).to be_truthy
      end

      it "permits password for agent manager" do
        expect(described_class.new(agent_manager, target_user).password?).to be_truthy
      end

      it "permits password for agent user" do
        expect(described_class.new(agent_user, target_user).password?).to be_truthy
      end

      it "permits password for customer" do
        expect(described_class.new(customer, target_user).password?).to be_truthy
      end
    end

    it "always returns true" do
      policy = described_class.new(customer, target_user)
      expect(policy.password?).to be true
    end
  end

  describe "#invite?" do
    context "when user is super admin" do
      it "permits invite" do
        expect(described_class.new(super_admin, User).invite?).to be_truthy
      end
    end

    context "when user is agent manager" do
      it "permits invite" do
        expect(described_class.new(agent_manager, User).invite?).to be_truthy
      end
    end

    context "when user is regular agent or customer" do
      it "denies invite for agent user" do
        expect(described_class.new(agent_user, User).invite?).to be_falsey
      end

      it "denies invite for customer" do
        expect(described_class.new(customer, User).invite?).to be_falsey
      end
    end
  end

  describe "#onboarding?" do
    context "when user is agent and target is themselves" do
      it "permits onboarding for agent user viewing themselves" do
        expect(described_class.new(agent_user, agent_user).onboarding?).to be_truthy
      end

      it "permits onboarding for agent manager viewing themselves" do
        expect(described_class.new(agent_manager, agent_manager).onboarding?).to be_truthy
      end
    end

    context "when user is agent but target is different" do
      it "denies onboarding for agent user viewing others" do
        expect(described_class.new(agent_user, target_user).onboarding?).to be_falsey
      end

      it "denies onboarding for agent manager viewing others" do
        expect(described_class.new(agent_manager, target_user).onboarding?).to be_falsey
      end
    end

    context "when user is not agent" do
      it "denies onboarding for customer" do
        expect(described_class.new(customer, customer).onboarding?).to be_falsey
      end

      it "denies onboarding for super admin" do
        expect(described_class.new(super_admin, super_admin).onboarding?).to be_falsey
      end
    end
  end

  describe "inheritance" do
    it "inherits from ApplicationPolicy" do
      expect(described_class.superclass).to eq(ApplicationPolicy)
    end

    it "has its own Scope class" do
      expect(described_class::Scope.superclass).to eq(ApplicationPolicy::Scope)
    end
  end

  describe "edge cases" do
    context "with nil user" do
      it "handles nil user gracefully" do
        policy = described_class.new(nil, target_user)
        expect { policy.show? }.to raise_error(NoMethodError) # Because nil.super_admin? raises error
        expect { policy.edit? }.to raise_error(NoMethodError) # Because nil.super_admin? raises error
        expect { policy.destroy? }.to raise_error(NoMethodError) # Because nil.super_admin? raises error
      end
    end

    context "with nil record" do
      it "handles nil record gracefully" do
        policy = described_class.new(agent_manager, nil)
        expect { policy.show? }.not_to raise_error
        expect { policy.edit? }.not_to raise_error
      end
    end

    context "with users from different offices" do
      it "agent manager cannot manage users from other offices" do
        expect(described_class.new(agent_manager, other_office_user).edit?).to be_falsey
        expect(described_class.new(agent_manager, other_office_user).destroy?).to be_falsey
        expect(described_class.new(agent_manager, other_office_user).show?).to be_falsey
      end
    end

    context "with self-reference edge cases" do
      it "allows users to manage themselves appropriately" do
        expect(described_class.new(agent_user, agent_user).show?).to be_truthy
        expect(described_class.new(agent_user, agent_user).edit?).to be_truthy
        expect(described_class.new(agent_user, agent_user).destroy?).to be_falsey
      end
    end
  end

  describe "role-based permissions summary" do
    context "super admin" do
      it "can do everything" do
        policy = described_class.new(super_admin, target_user)
        expect(policy.index?).to be_truthy
        expect(policy.show?).to be_truthy
        expect(policy.new?).to be_truthy
        expect(policy.edit?).to be_truthy
        expect(policy.destroy?).to be_truthy
        expect(policy.invite?).to be_truthy
        expect(policy.password?).to be_truthy
      end
    end

    context "agent manager" do
      it "can manage users in same office" do
        policy = described_class.new(agent_manager, target_user)
        expect(policy.index?).to be_truthy
        expect(policy.show?).to be_truthy
        expect(policy.new?).to be_truthy
        expect(policy.edit?).to be_truthy
        expect(policy.destroy?).to be_truthy
        expect(policy.invite?).to be_truthy
      end
    end

    context "regular agent" do
      it "can only manage themselves" do
        policy = described_class.new(agent_user, target_user)
        expect(policy.index?).to be_falsey
        expect(policy.show?).to be_falsey
        expect(policy.new?).to be_falsey
        expect(policy.edit?).to be_falsey
        expect(policy.destroy?).to be_falsey
        expect(policy.invite?).to be_falsey

        # But can manage themselves
        self_policy = described_class.new(agent_user, agent_user)
        expect(self_policy.show?).to be_truthy
        expect(self_policy.edit?).to be_truthy
      end
    end
  end
end
