require 'rails_helper'

RSpec.describe BasketItemCandidate, type: :model do
  describe "associations" do
    it { should belong_to(:basket_item) }
    it { should belong_to(:candidate) }
  end

  describe "validations" do
    it { should validate_presence_of(:added_at) }

    it "validates uniqueness of candidate_id scoped to basket_item_id" do
      customer = create(:user, :customer)
      basket = create(:basket, customer: customer)
      agent = create(:user, :agent_user)
      basket_item = create(:basket_item, basket: basket, agent: agent)
      candidate = create(:candidate, :published, agent: agent)

      create(:basket_item_candidate, basket_item: basket_item, candidate: candidate)

      duplicate = build(:basket_item_candidate, basket_item: basket_item, candidate: candidate)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:candidate_id]).to include("est déjà utilisé(e)")
    end
  end
end
