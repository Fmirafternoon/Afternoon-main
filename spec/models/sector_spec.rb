require 'rails_helper'

RSpec.describe Sector, type: :model do
    describe 'validations' do
    it 'validates presence of name' do
      sector = build(:sector, name: nil)
      expect(sector).not_to be_valid
      expect(sector.errors[:name]).to include("doit être rempli(e)")
    end

    it 'validates presence of slug' do
      sector = build(:sector, name: nil)
      sector.valid?
      expect(sector).not_to be_valid
      expect(sector.errors[:slug]).to include("doit être rempli(e)")
    end

    it 'validates uniqueness of slug' do
      create(:sector, name: 'Technology')
      sector = build(:sector, name: 'Technology')
      expect(sector).not_to be_valid
      expect(sector.errors[:slug]).to include("est déjà utilisé(e)")
    end
  end

  describe 'callbacks' do
    describe 'before_validation :set_slug' do
      it 'sets slug from name before validation' do
        sector = build(:sector, name: 'Bâtiment et Travaux Publics', slug: nil)
        sector.valid?
        expect(sector.slug).to eq('batiment-et-travaux-publics')
      end

      it 'handles special characters' do
        sector = build(:sector, name: 'Santé & Médical', slug: nil)
        sector.valid?
        expect(sector.slug).to eq('sante-medical')
      end

      it 'handles accented characters' do
        sector = build(:sector, name: 'Aéronautique', slug: nil)
        sector.valid?
        expect(sector.slug).to eq('aeronautique')
      end

      it 'handles spaces and punctuation' do
        sector = build(:sector, name: 'Banque, Finance & Assurance', slug: nil)
        sector.valid?
        expect(sector.slug).to eq('banque-finance-assurance')
      end

      it 'handles uppercase names' do
        sector = build(:sector, name: 'INFORMATIQUE', slug: nil)
        sector.valid?
        expect(sector.slug).to eq('informatique')
      end

      it 'keeps existing slug if provided' do
        sector = build(:sector, name: 'Technology', slug: 'tech')
        sector.valid?
        expect(sector.slug).to eq('tech')
      end

      it 'does not update slug when name changes if slug already exists' do
        sector = create(:sector, name: 'Original Name')
        original_slug = sector.slug

        sector.name = 'New Name'
        sector.valid?
        expect(sector.slug).to eq(original_slug)
      end
    end
  end

  describe '#to_s' do
    it 'returns the name' do
      sector = build(:sector, name: 'Technology')
      expect(sector.to_s).to eq('Technology')
    end

    it 'handles nil name gracefully' do
      sector = build(:sector, name: nil)
      expect(sector.to_s).to be_nil
    end
  end

    describe 'slug uniqueness' do
    it 'ensures slug uniqueness in real scenarios' do
      create(:sector, name: 'Technology')
      # Create another sector with a name that would generate the same slug
      duplicate = build(:sector, name: 'Technology')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to include('est déjà utilisé(e)')
    end
  end

  describe 'edge cases' do
    context 'with empty name' do
      it 'sets slug to empty string for empty name' do
        sector = build(:sector, name: '', slug: nil)
        sector.valid?
        expect(sector.slug).to eq('')
      end
    end

    context 'with nil name' do
      it 'sets slug to empty string for nil name' do
        sector = build(:sector, name: nil, slug: nil)
        sector.valid?
        expect(sector.slug).to eq('')
      end
    end

    context 'with very long name' do
      it 'handles long names' do
        long_name = 'A' * 100
        sector = build(:sector, name: long_name, slug: nil)
        sector.valid?
        expect(sector.slug).to eq('a' * 100)
      end
    end

    context 'with numbers in name' do
      it 'preserves numbers in slug' do
        sector = build(:sector, name: 'Web 3.0 Technologies', slug: nil)
        sector.valid?
        expect(sector.slug).to eq('web-3-0-technologies')
      end
    end

    context 'with only special characters' do
      it 'handles names with only special characters' do
        sector = build(:sector, name: '& % @', slug: nil)
        sector.valid?
        # parameterize removes all special chars, leaving empty string
        expect(sector.slug).to eq('')
      end
    end
  end

  describe 'persistence' do
    it 'can be saved successfully' do
      sector = build(:sector, name: 'Technology')
      expect(sector.save).to be_truthy
      expect(sector.persisted?).to be_truthy
    end

    it 'maintains slug after save' do
      sector = create(:sector, name: 'Technology')
      expect(sector.slug).to eq('technology')

      reloaded_sector = Sector.find(sector.id)
      expect(reloaded_sector.slug).to eq('technology')
    end
  end
end
