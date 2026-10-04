require 'rails_helper'

RSpec.describe CandidateLanguage, type: :model do
  describe 'associations' do
    it { should belong_to(:candidate) }
  end

  describe 'validations' do
    it { should validate_presence_of(:code) }

    it do
      should validate_inclusion_of(:level)
        .in_array(%w[A1 A2 B1 B2 C1 C2])
        .allow_blank
    end

    it 'validates code is in valid language codes' do
      # This test assumes I18nData.languages(:fr) returns a hash with language codes
      # We'll mock this for testing
      allow(I18nData).to receive(:languages).with(:fr).and_return({
        'FR' => 'Français',
        'EN' => 'Anglais',
        'ES' => 'Espagnol'
      })

      valid_language = build(:candidate_language, code: 'fr')
      expect(valid_language).to be_valid

      invalid_language = build(:candidate_language, code: 'zz')
      expect(invalid_language).not_to be_valid
    end

    describe 'uniqueness of code scoped to candidate' do
      let(:candidate) { create(:candidate) }
      let!(:existing_language) { create(:candidate_language, candidate: candidate, code: 'fr') }

      it 'validates uniqueness of code per candidate' do
        duplicate_language = build(:candidate_language, candidate: candidate, code: 'fr')
        expect(duplicate_language).not_to be_valid
        expect(duplicate_language.errors[:code]).to include('est déjà utilisé(e)')
      end

      it 'allows same code for different candidates' do
        other_candidate = create(:candidate)
        other_language = build(:candidate_language, candidate: other_candidate, code: 'fr')
        expect(other_language).to be_valid
      end
    end
  end

  describe '#name' do
    before do
      allow(I18nData).to receive(:languages).with(:fr).and_return({
        'FR' => 'Français',
        'EN' => 'Anglais',
        'ES' => 'Espagnol'
      })
    end

    it 'returns the language name in French' do
      language = build(:candidate_language, code: 'fr')
      expect(language.name).to eq('Français')
    end

    it 'handles uppercase conversion of code' do
      language = build(:candidate_language, code: 'en')
      expect(language.name).to eq('Anglais')
    end

    it 'works with already uppercase codes' do
      language = build(:candidate_language, code: 'ES')
      expect(language.name).to eq('Espagnol')
    end

    context 'with unknown language code' do
      it 'returns nil for unknown codes' do
        language = build(:candidate_language, code: 'unknown')
        expect(language.name).to be_nil
      end
    end
  end

  describe 'level validation edge cases' do
    it 'allows nil level' do
      language = build(:candidate_language, level: nil)
      expect(language).to be_valid
    end

    it 'allows empty string level' do
      language = build(:candidate_language, level: '')
      expect(language).to be_valid
    end

    it 'rejects invalid levels' do
      language = build(:candidate_language, level: 'D1')
      expect(language).not_to be_valid
    end

    it 'rejects lowercase levels' do
      language = build(:candidate_language, level: 'a1')
      expect(language).not_to be_valid
    end
  end

  describe 'code validation edge cases' do
    before do
      allow(I18nData).to receive(:languages).with(:fr).and_return({
        'FR' => 'Français',
        'EN' => 'Anglais'
      })
    end

    it 'validates code case insensitively' do
      language = build(:candidate_language, code: 'FR')
      expect(language).to be_valid
    end

    it 'handles mixed case codes' do
      language = build(:candidate_language, code: 'Fr')
      expect(language).to be_valid
    end
  end

  describe 'data integrity' do
    let(:candidate) { create(:candidate) }

    it 'can save multiple languages for same candidate' do
      allow(I18nData).to receive(:languages).with(:fr).and_return({
        'FR' => 'Français',
        'EN' => 'Anglais',
        'ES' => 'Espagnol'
      })

      french = create(:candidate_language, candidate: candidate, code: 'fr', level: 'C2')
      english = create(:candidate_language, candidate: candidate, code: 'en', level: 'B2')
      spanish = create(:candidate_language, candidate: candidate, code: 'es', level: 'A1')

      expect(candidate.candidate_languages.count).to eq(3)
      expect(candidate.candidate_languages).to include(french, english, spanish)
    end
  end
end
