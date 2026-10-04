require 'rails_helper'

RSpec.describe Basket, type: :model do
  describe "associations" do
    it { should belong_to(:customer).class_name("User").with_foreign_key("customer_id") }
    it { should have_many(:basket_items).dependent(:destroy) }
    it { should have_many(:candidates).through(:basket_items) }
  end

  describe ".for_customer" do
    let(:customer) { create(:user, :customer) }

    it "creates a basket for customer if none exists" do
      expect {
        Basket.for_customer(customer)
      }.to change(Basket, :count).by(1)
    end

    it "returns existing basket if one exists" do
      existing_basket = create(:basket, customer: customer)

      expect {
        basket = Basket.for_customer(customer)
        expect(basket.id).to eq(existing_basket.id)
      }.not_to change(Basket, :count)
    end
  end

  describe "#add_candidate" do
    let(:customer) { create(:user, :customer) }
    let(:agent) { create(:user, :agent_user) }
    let(:candidate) { create(:candidate, :published, agent: agent) }
    let(:basket) { Basket.for_customer(customer) }

    it "creates a basket_item for the agent if none exists" do
      expect {
        basket.add_candidate(candidate)
      }.to change(basket.basket_items, :count).by(1)
    end

    it "returns the basket_item" do
      basket_item = basket.add_candidate(candidate)
      expect(basket_item).to be_a(BasketItem)
      expect(basket_item.agent).to eq(agent)
    end

    it "adds the candidate to the basket_item" do
      basket_item = basket.add_candidate(candidate)
      expect(basket_item.candidates).to include(candidate)
    end

    context "when basket_item already exists for this agent" do
      let(:existing_candidate) { create(:candidate, :published, agent: agent) }

      before do
        basket.add_candidate(existing_candidate)
      end

      it "does not create a new basket_item" do
        expect {
          basket.add_candidate(candidate)
        }.not_to change(basket.basket_items, :count)
      end

      it "adds the candidate to the existing basket_item" do
        basket_item = basket.add_candidate(candidate)
        expect(basket_item.candidates).to include(candidate)
        expect(basket_item.candidates).to include(existing_candidate)
      end
    end

    it "does not add duplicate candidates" do
      basket.add_candidate(candidate)

      expect {
        basket.add_candidate(candidate)
      }.not_to change(basket.reload.candidates, :count)
    end
  end

  describe "#total_candidates_count" do
    let(:customer) { create(:user, :customer) }
    let(:basket) { Basket.for_customer(customer) }
    let(:agent1) { create(:user, :agent_user) }
    let(:agent2) { create(:user, :agent_user) }

    it "returns 0 when basket is empty" do
      expect(basket.total_candidates_count).to eq(0)
    end

    it "returns the total number of candidates across all basket items" do
      candidate1 = create(:candidate, :published, agent: agent1)
      candidate2 = create(:candidate, :published, agent: agent1)
      candidate3 = create(:candidate, :published, agent: agent2)

      basket.add_candidate(candidate1)
      basket.add_candidate(candidate2)
      basket.add_candidate(candidate3)

      expect(basket.total_candidates_count).to eq(3)
    end
  end

  describe "#pending_items" do
    let(:customer) { create(:user, :customer) }
    let(:basket) { Basket.for_customer(customer) }
    let(:agent1) { create(:user, :agent_user) }
    let(:agent2) { create(:user, :agent_user) }

    it "returns only pending basket_items" do
      candidate1 = create(:candidate, :published, agent: agent1)
      candidate2 = create(:candidate, :published, agent: agent2)

      basket_item1 = basket.add_candidate(candidate1)
      basket_item2 = basket.add_candidate(candidate2)

      basket_item2.update!(status: :meeting_requested)

      pending_items = basket.pending_items
      expect(pending_items).to include(basket_item1)
      expect(pending_items).not_to include(basket_item2)
    end

    it "eager loads agent and candidates" do
      candidate = create(:candidate, :published, agent: agent1)
      basket.add_candidate(candidate)

      # Test that associations are eager loaded by accessing them
      pending_items = basket.pending_items
      expect(pending_items.first.agent).to eq(agent1)
      expect(pending_items.first.candidates).to include(candidate)
    end
  end
end
