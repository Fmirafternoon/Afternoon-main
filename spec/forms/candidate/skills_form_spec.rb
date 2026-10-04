require 'rails_helper'

RSpec.describe Candidate::SkillsForm do
  let(:candidate) { create(:candidate) }
  let(:form) { described_class.new(attributes) }
  let(:attributes) { { id: candidate.id } }

  describe '#initialize' do
    it 'finds the candidate by id' do
      expect(form.instance_variable_get(:@candidate)).to eq(candidate)
    end

    it 'handles indifferent access for id' do
      form = described_class.new('id' => candidate.id)
      expect(form.instance_variable_get(:@candidate)).to eq(candidate)
    end
  end

  describe '#languages_list' do
    it 'returns priority languages first' do
      languages = form.languages_list
      expect(languages.first).to eq(["Français", "fr"])
      expect(languages[1]).to eq(["Anglais", "en"])
      expect(languages[2]).to eq(["Castillan (Espagnol)", "es"])
    end

    it 'includes all I18n languages after priority ones' do
      languages = form.languages_list
      priority_count = 12 # Number of priority languages
      expect(languages.size).to be > priority_count
    end

    it 'sorts non-priority languages alphabetically' do
      languages = form.languages_list
      non_priority = languages.drop(12) # Skip priority languages
      sorted = non_priority.sort_by { |name, _| name }
      expect(non_priority).to eq(sorted)
    end

    it 'downcases language codes' do
      languages = form.languages_list
      languages.each do |_, code|
        expect(code).to eq(code.downcase)
      end
    end
  end

  describe '#language_levels_list' do
    it 'returns CEFR language levels' do
      expect(form.language_levels_list).to eq(%w[A1 A2 B1 B2 C1 C2])
    end
  end

  describe '#persist!' do
    it 'calls valid? and returns its result' do
      expect(form).to receive(:valid?).and_return(true)
      expect(form.persist!).to be true
    end
  end

  describe '#persist_language!' do
    context 'with valid language data' do
      let(:attributes) { { id: candidate.id, language_code: 'en', language_level: 'B2' } }

      it 'creates a candidate language' do
        expect {
          form.persist_language!
        }.to change { candidate.candidate_languages.count }.by(1)
      end

      it 'creates language with correct attributes' do
        form.persist_language!
        language = candidate.candidate_languages.last
        expect(language.code).to eq('en')
        expect(language.level).to eq('B2')
      end

      it 'sets the form id to candidate id' do
        form.persist_language!
        expect(form.id).to eq(candidate.id)
      end

      it 'returns candidate id' do
        result = form.persist_language!
        expect(result).to eq(candidate.id)
      end
    end

    context 'with invalid language data' do
      let(:attributes) { { id: candidate.id, language_code: '', language_level: 'B2' } }

      it 'does not create a language' do
        expect {
          form.persist_language!
        }.not_to change { candidate.candidate_languages.count }
      end

      it 'returns false' do
        expect(form.persist_language!).to be false
      end
    end
  end

  describe '#persist_skill!' do
    context 'with valid skill data' do
      let(:attributes) { { id: candidate.id, skill: 'Ruby on Rails' } }

      it 'creates or finds a skill' do
        expect {
          form.persist_skill!
        }.to change { Skill.count }.by(1)
      end

      it 'creates skill with correct attributes' do
        form.persist_skill!
        skill = Skill.last
        expect(skill.name).to eq('Ruby on Rails')
        expect(skill.slug).to eq('ruby-on-rails')
      end

      it 'adds skill to candidate' do
        expect {
          form.persist_skill!
        }.to change { candidate.skills.count }.by(1)
      end

      it 'does not duplicate skills for candidate' do
        form.persist_skill!
        expect {
          form.persist_skill!
        }.not_to change { candidate.skills.count }
      end

      it 'sets the form id to candidate id' do
        form.persist_skill!
        expect(form.id).to eq(candidate.id)
      end

      it 'returns candidate id' do
        result = form.persist_skill!
        expect(result).to eq(candidate.id)
      end
    end

    context 'with existing skill' do
      let!(:existing_skill) { create(:skill, name: 'Ruby', slug: 'ruby') }
      let(:attributes) { { id: candidate.id, skill: 'Ruby' } }

      it 'does not create a new skill' do
        expect {
          form.persist_skill!
        }.not_to change { Skill.count }
      end

      it 'adds existing skill to candidate' do
        form.persist_skill!
        expect(candidate.skills).to include(existing_skill)
      end
    end

    context 'with invalid skill data' do
      let(:attributes) { { id: candidate.id, skill: '' } }

      it 'does not create a skill' do
        expect {
          form.persist_skill!
        }.not_to change { Skill.count }
      end

      it 'returns false' do
        expect(form.persist_skill!).to be false
      end
    end
  end

  describe '#persist_sector!' do
    let(:sector) { create(:sector) }
    
    context 'with valid sector data' do
      let(:attributes) { { id: candidate.id, sector_id: sector.id } }

      it 'adds sector to candidate' do
        expect {
          form.persist_sector!
        }.to change { candidate.sectors.count }.by(1)
      end

      it 'adds the correct sector' do
        form.persist_sector!
        expect(candidate.sectors).to include(sector)
      end

      it 'sets the form id to candidate id' do
        form.persist_sector!
        expect(form.id).to eq(candidate.id)
      end

      it 'returns candidate id' do
        result = form.persist_sector!
        expect(result).to eq(candidate.id)
      end
    end

    context 'with invalid sector data' do
      let(:attributes) { { id: candidate.id, sector_id: nil } }

      it 'does not add sector' do
        expect {
          form.persist_sector!
        }.not_to change { candidate.sectors.count }
      end

      it 'returns false' do
        expect(form.persist_sector!).to be false
      end
    end
  end

  describe 'validations' do
    describe 'skill validation' do
      context 'on :add_skill context' do
        it 'requires skill presence' do
          form = described_class.new(id: candidate.id, skill: '')
          expect(form).not_to be_valid(:add_skill)
          expect(form.errors[:skill]).to include("doit être rempli(e)")
        end
      end

      context 'without context' do
        it 'validates at_least_one when all fields are blank' do
          form = described_class.new(id: candidate.id, skill: '')
          # The form has at_least_one validations that will trigger
          expect(form).not_to be_valid
          expect(form.errors[:skill]).to be_present
          expect(form.errors[:sector_id]).to be_present
        end
        
        it 'is valid when candidate already has skills' do
          candidate.skills << create(:skill)
          form = described_class.new(id: candidate.id, skill: '')
          form.valid?
          expect(form.errors[:skill]).to be_empty
        end
      end
    end

    describe 'language validation' do
      context 'when language_level is present' do
        it 'requires language_code' do
          form = described_class.new(id: candidate.id, language_level: 'B2')
          expect(form).not_to be_valid(:add_language)
          expect(form.errors[:language_code]).to include("doit être rempli(e)")
        end
      end

      context 'when language_code is present' do
        it 'requires language_code to be present (self-validation)' do
          form = described_class.new(id: candidate.id, language_code: 'en')
          expect(form).to be_valid(:add_language)
        end
      end
    end

    describe 'sector validation' do
      context 'on :add_sector context' do
        it 'requires sector_id presence' do
          form = described_class.new(id: candidate.id, sector_id: nil)
          expect(form).not_to be_valid(:add_sector)
          expect(form.errors[:sector_id]).to include("doit être rempli(e)")
        end
      end
    end

    describe 'at_least_one validations' do
      context 'when all fields are blank and candidate has no skills' do
        it 'validates at_least_one_skill' do
          form = described_class.new(id: candidate.id)
          expect(form).not_to be_valid
          expect(form.errors[:skill]).to be_present
        end
      end

      context 'when all fields are blank and candidate has no sectors' do
        it 'validates at_least_one_sector' do
          form = described_class.new(id: candidate.id)
          expect(form).not_to be_valid
          expect(form.errors[:sector_id]).to be_present
        end
      end

      context 'when candidate already has skills' do
        before { candidate.skills << create(:skill) }

        it 'does not require additional skills' do
          form = described_class.new(id: candidate.id)
          form.valid?
          expect(form.errors[:skill]).to be_empty
        end
      end

      context 'when candidate already has sectors' do
        before { candidate.sectors << create(:sector) }

        it 'does not require additional sectors' do
          form = described_class.new(id: candidate.id)
          form.valid?
          expect(form.errors[:sector_id]).to be_empty
        end
      end

      context 'when any field is present' do
        it 'skips at_least_one validations with skill present' do
          form = described_class.new(id: candidate.id, skill: 'Ruby')
          expect(form).to be_valid
        end

        it 'skips at_least_one validations with language_code present' do
          form = described_class.new(id: candidate.id, language_code: 'en')
          expect(form).to be_valid
        end

        it 'skips at_least_one validations with sector_id present' do
          form = described_class.new(id: candidate.id, sector_id: 1)
          expect(form).to be_valid
        end
      end
    end
  end
end