require 'rails_helper'

RSpec.describe BasketPolicy, type: :policy do
  subject { described_class }

  let(:customer) { create(:user, :customer) }
  let(:other_customer) { create(:user, :customer) }
  let(:agent) { create(:user, :agent_user) }
  let(:basket) { create(:basket, customer: customer) }
  let(:other_basket) { create(:basket, customer: other_customer) }

  permissions :show? do
    it "grants access to customer's own basket" do
      expect(subject).to permit(customer, basket)
    end

    it "denies access to another customer's basket" do
      expect(subject).not_to permit(other_customer, basket)
    end

    it "denies access to agents" do
      expect(subject).not_to permit(agent, basket)
    end
  end

  permissions :add_candidate? do
    it "grants access to customers" do
      expect(subject).to permit(customer, basket)
    end

    it "denies access to agents" do
      expect(subject).not_to permit(agent, basket)
    end
  end

  permissions :remove_candidate? do
    it "grants access to customer's own basket" do
      expect(subject).to permit(customer, basket)
    end

    it "denies access to another customer's basket" do
      expect(subject).not_to permit(other_customer, basket)
    end

    it "denies access to agents" do
      expect(subject).not_to permit(agent, basket)
    end
  end

  permissions :request_meeting? do
    it "grants access to customer's own basket" do
      expect(subject).to permit(customer, basket)
    end

    it "denies access to another customer's basket" do
      expect(subject).not_to permit(other_customer, basket)
    end

    it "denies access to agents" do
      expect(subject).not_to permit(agent, basket)
    end
  end

  permissions :send_meeting_request? do
    it "grants access to customer's own basket" do
      expect(subject).to permit(customer, basket)
    end

    it "denies access to another customer's basket" do
      expect(subject).not_to permit(other_customer, basket)
    end

    it "denies access to agents" do
      expect(subject).not_to permit(agent, basket)
    end
  end
end
