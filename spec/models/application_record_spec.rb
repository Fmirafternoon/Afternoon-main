require 'rails_helper'

RSpec.describe ApplicationRecord, type: :model do
  describe '.human_enum_name' do
    # Use User model which already exists and has enums
    it 'returns the translated enum value' do
      allow(I18n).to receive(:t).with(
        "activerecord.attributes.user.roles.super_admin"
      ).and_return("Super Administrateur")

      result = User.human_enum_name(:role, 'super_admin')
      expect(result).to eq("Super Administrateur")
    end

    it 'handles different enum values' do
      allow(I18n).to receive(:t).with(
        "activerecord.attributes.user.roles.customer"
      ).and_return("Client")

      result = User.human_enum_name(:role, 'customer')
      expect(result).to eq("Client")
    end

    it 'pluralizes the enum name' do
      expect(I18n).to receive(:t).with(
        "activerecord.attributes.user.roles.super_admin"
      ).and_return("Super Administrateur")

      User.human_enum_name(:role, 'super_admin')
    end

    it 'uses the correct i18n key format' do
      expected_key = "activerecord.attributes.user.roles.super_admin"

      expect(I18n).to receive(:t).with(expected_key).and_return("Super Administrateur")

      User.human_enum_name(:role, 'super_admin')
    end
  end

  describe 'inheritance' do
    it 'inherits from ActiveRecord::Base' do
      expect(ApplicationRecord.superclass).to eq(ActiveRecord::Base)
    end

    it 'is a primary abstract class' do
      expect(ApplicationRecord.abstract_class?).to be_truthy
    end
  end
end
