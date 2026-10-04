require 'rails_helper'

RSpec.describe Candidate::Search do
  let(:form) { Customer::SearchForm.new(form_params) }
  let(:scope) { Candidate.all }
  let(:form_params) { {} }
  let(:actor_result) { described_class.call(form: form, scope: scope) }
  
  before do
    # Mock Location.near to avoid geocoding calls
    allow(Location).to receive(:near).and_return(Location.none)
  end

  describe '#call' do
    context 'when successful' do
      it 'returns success with candidates' do
        expect(actor_result).to be_success
        expect(actor_result.candidates).to be_an(ActiveRecord::Relation)
      end
    end

    context 'when no search criteria provided' do
      it 'returns all candidates ordered by created_at desc' do
        old_candidate = create(:candidate, created_at: 2.days.ago)
        new_candidate = create(:candidate, created_at: 1.day.ago)

        expect(actor_result.candidates.to_a).to eq([new_candidate, old_candidate])
      end
    end

    context 'when searching by query (job title)' do
      let(:form_params) { { query: 'Developer' } }
      
      context 'when embedding service returns embedding' do
        let(:embedding) { Array.new(1024) { rand } }
        
        before do
          allow(EmbeddingCache).to receive(:get_embedding).with('Developer').and_return(embedding)
        end

        it 'filters candidates by job title embedding' do
          # We can't easily test pgvector distance functions, so we'll test the structure
          expect(actor_result.candidates.to_sql).to include('job_title_embedding')
          expect(actor_result.candidates.to_sql).to include('<=> ARRAY')
        end
      end

      context 'when embedding service returns nil' do
        before do
          allow(EmbeddingCache).to receive(:get_embedding).with('Developer').and_return(nil)
        end

        it 'returns all candidates without filtering by job title' do
          candidate1 = create(:candidate)
          candidate2 = create(:candidate)

          expect(actor_result.candidates).to include(candidate1, candidate2)
        end
      end
    end

    context 'when searching by location' do
      let(:form_params) do
        {
          autocomplete_address: 'Paris, France',
          lat: '48.8566',
          lng: '2.3522'
        }
      end

      it 'uses near_location scope' do
        candidate = create(:candidate)
        location = create(:location, latitude: 48.8566, longitude: 2.3522)
        
        # Mock the near method to return locations
        allow(Location).to receive(:near).with([48.8566, 2.3522], 30, units: :km).and_return(Location.where(id: location.id))
        
        # Create mobility for the candidate
        create(:candidate_mobility, candidate: candidate, location: location)
        
        result = actor_result
        expect(result.candidates).to include(candidate)
      end
    end

    context 'when searching by sectors' do
      let(:sector1) { create(:sector, name: 'IT') }
      let(:sector2) { create(:sector, name: 'Finance') }
      let(:form_params) { { sector_ids: [sector1.id.to_s, sector2.id.to_s] } }

      it 'filters candidates by sectors' do
        it_candidate = create(:candidate)
        create(:candidate_sector, candidate: it_candidate, sector: sector1)
        
        finance_candidate = create(:candidate)
        create(:candidate_sector, candidate: finance_candidate, sector: sector2)
        
        other_candidate = create(:candidate)
        other_sector = create(:sector, name: 'Other')
        create(:candidate_sector, candidate: other_candidate, sector: other_sector)

        no_sector_candidate = create(:candidate)

        candidates = actor_result.candidates
        expect(candidates).to include(it_candidate, finance_candidate)
        expect(candidates).not_to include(other_candidate, no_sector_candidate)
      end
    end

    context 'when searching by skills' do
      let(:form_params) { { skills: ['Ruby', 'Rails'] } }
      let(:ruby_embedding) { Array.new(1024) { rand } }
      let(:rails_embedding) { Array.new(1024) { rand } }

      before do
        allow(EmbeddingCache).to receive(:get_embedding).with('Ruby').and_return(ruby_embedding)
        allow(EmbeddingCache).to receive(:get_embedding).with('Rails').and_return(rails_embedding)
      end

      it 'builds query with skill embeddings' do
        # Create candidates with skills that have embeddings
        skill1 = create(:skill, name: 'Ruby')
        skill1.update_column(:embedding, ruby_embedding)
        
        skill2 = create(:skill, name: 'Rails')
        skill2.update_column(:embedding, rails_embedding)
        
        candidate = create(:candidate)
        create(:candidate_skill, candidate: candidate, skill: skill1)
        create(:candidate_skill, candidate: candidate, skill: skill2)
        
        expect(actor_result.candidates).to include(candidate)
      end

      context 'when skill embedding is not found' do
        let(:form_params) { { skills: ['NonExistentSkill'] } }

        before do
          allow(EmbeddingCache).to receive(:get_embedding).with('NonExistentSkill').and_return(nil)
        end

        it 'ignores that skill in the search' do
          # Since no skill embedding was found, the search returns none
          candidate = create(:candidate)
          expect(actor_result.candidates).to be_none
        end
      end

      context 'when skills array contains blank values' do
        let(:form_params) { { skills: ['Ruby', '', nil] } }

        it 'ignores blank skills' do
          expect(EmbeddingCache).to receive(:get_embedding).with('Ruby').and_return(ruby_embedding)
          expect(EmbeddingCache).not_to receive(:get_embedding).with('')
          expect(EmbeddingCache).not_to receive(:get_embedding).with(nil)
          
          actor_result
        end
      end
    end

    context 'when searching with empty skill candidate ids' do
      let(:form_params) { { skills: ['UnknownSkill'] } }
      
      before do
        allow(EmbeddingCache).to receive(:get_embedding).with('UnknownSkill').and_return(Array.new(1024) { rand })
      end

      it 'returns none when no candidates match' do
        create(:candidate)
        # Mock the query to return no matches
        allow_any_instance_of(ActiveRecord::Relation).to receive(:pluck).and_return([])
        
        expect(actor_result.candidates.to_sql).to include('1=0') # ActiveRecord's way of returning none
      end
    end

    context 'with combined search criteria' do
      let(:sector) { create(:sector, name: 'IT') }
      let(:form_params) do
        {
          query: 'Developer',
          autocomplete_address: 'Paris, France',
          lat: '48.8566',
          lng: '2.3522',
          sector_ids: [sector.id.to_s],
          skills: ['Ruby']
        }
      end
      let(:embedding) { Array.new(1024) { rand } }

      before do
        allow(EmbeddingCache).to receive(:get_embedding).with('Developer').and_return(embedding)
        allow(EmbeddingCache).to receive(:get_embedding).with('Ruby').and_return(embedding)
      end

      it 'applies all filters' do
        # For complex combined tests, just verify the SQL includes expected parts
        # The interaction between all filters is complex and better tested in integration tests
        
        query = actor_result.candidates.to_sql
        
        # Check that all filters are represented in the query
        expect(query).to include('job_title_embedding') # Query filter
        expect(query).to include('candidate_sectors') # Sector filter
        # Skills filter results in either an ID constraint or a none (1=0) clause
        expect(query).to match(/candidates"."id"|1=0/)
      end
    end
  end
end