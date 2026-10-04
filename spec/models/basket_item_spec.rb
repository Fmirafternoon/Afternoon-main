require 'rails_helper'

RSpec.describe BasketItem, type: :model do
  describe "associations" do
    it { should belong_to(:basket) }
    it { should belong_to(:agent).class_name("User").with_foreign_key("agent_id") }
    it { should have_many(:basket_item_candidates).dependent(:destroy) }
    it { should have_many(:candidates).through(:basket_item_candidates) }
  end

  describe "validations" do
    it { should validate_presence_of(:agent) }
  end

  describe "enums" do
    it { should define_enum_for(:status).with_values(pending: "pending", meeting_requested: "meeting_requested", meeting_scheduled: "meeting_scheduled", cancelled: "cancelled").backed_by_column_of_type(:string).with_prefix(:status) }
  end

  describe "#add_candidate" do
    let(:customer) { create(:user, :customer) }
    let(:basket) { create(:basket, customer: customer) }
    let(:agent) { create(:user, :agent_user) }
    let(:basket_item) { create(:basket_item, basket: basket, agent: agent) }
    let(:candidate) { create(:candidate, :published, agent: agent) }

    it "creates a basket_item_candidate" do
      expect {
        basket_item.add_candidate(candidate)
      }.to change(basket_item.basket_item_candidates, :count).by(1)
    end

    it "sets the added_at timestamp" do
      freeze_time do
        basket_item_candidate = basket_item.add_candidate(candidate)
        expect(basket_item_candidate.added_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe "#remove_candidate" do
    let(:customer) { create(:user, :customer) }
    let(:basket) { create(:basket, customer: customer) }
    let(:agent) { create(:user, :agent_user) }
    let(:basket_item) { create(:basket_item, basket: basket, agent: agent) }
    let(:candidate) { create(:candidate, :published, agent: agent) }

    before do
      basket_item.add_candidate(candidate)
    end

    it "removes the candidate from the basket_item" do
      expect {
        basket_item.remove_candidate(candidate)
      }.to change(basket_item.basket_item_candidates, :count).by(-1)
    end

    it "does nothing if candidate is not in the basket_item" do
      other_candidate = create(:candidate, :published, agent: agent)

      expect {
        basket_item.remove_candidate(other_candidate)
      }.not_to change(basket_item.basket_item_candidates, :count)
    end
  end

  describe "#has_candidate?" do
    let(:customer) { create(:user, :customer) }
    let(:basket) { create(:basket, customer: customer) }
    let(:agent) { create(:user, :agent_user) }
    let(:basket_item) { create(:basket_item, basket: basket, agent: agent) }
    let(:candidate) { create(:candidate, :published, agent: agent) }

    it "returns true if candidate is in basket_item" do
      basket_item.add_candidate(candidate)
      expect(basket_item.has_candidate?(candidate)).to be true
    end

    it "returns false if candidate is not in basket_item" do
      expect(basket_item.has_candidate?(candidate)).to be false
    end
  end

  describe "#request_meeting!" do
    let(:customer) { create(:user, :customer) }
    let(:basket) { create(:basket, customer: customer) }
    let(:agent) { create(:user, :agent_user) }
    let(:basket_item) { create(:basket_item, basket: basket, agent: agent) }
    let(:meeting_date) { 2.days.from_now }
    let(:message) { "Je souhaite discuter de ces profils" }

    it "updates status to meeting_requested" do
      basket_item.request_meeting!(date: meeting_date, message: message)
      expect(basket_item.status).to eq("meeting_requested")
    end

    it "sets the meeting_date" do
      basket_item.request_meeting!(date: meeting_date, message: message)
      expect(basket_item.meeting_date).to be_within(1.second).of(meeting_date)
    end

    it "sets the customer_message" do
      basket_item.request_meeting!(date: meeting_date, message: message)
      expect(basket_item.customer_message).to eq(message)
    end

    it "persists the changes" do
      basket_item.request_meeting!(date: meeting_date, message: message)
      basket_item.reload
      expect(basket_item.status).to eq("meeting_requested")
      expect(basket_item.meeting_date).to be_within(1.second).of(meeting_date)
      expect(basket_item.customer_message).to eq(message)
    end
  end
end
