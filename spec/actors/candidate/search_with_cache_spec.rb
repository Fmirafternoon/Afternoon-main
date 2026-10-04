require 'rails_helper'

RSpec.describe Candidate::Search, type: :actor do
  describe 'with EmbeddingCache integration' do
    let(:form) { Customer::SearchForm.new(query: "Conducteur de travaux") }
    let(:scope) { Candidate.all }
    let(:embedding) { Array.new(1024) { rand } }
    
    before do
      allow(Embedding::Create).to receive(:call).and_return(
        double(embedding: embedding)
      )
    end
    
    context 'when searching by job title' do
      it 'uses EmbeddingCache for query embedding' do
        expect(EmbeddingCache).to receive(:get_embedding).with("Conducteur de travaux").and_call_original
        
        Candidate::Search.call(form: form, scope: scope)
      end
      
      it 'caches the embedding on first search' do
        expect {
          Candidate::Search.call(form: form, scope: scope)
        }.to change(EmbeddingCache, :count).by(1)
      end
      
      it 'reuses cached embedding on subsequent searches' do
        # Premier appel - création du cache
        Candidate::Search.call(form: form, scope: scope)
        
        # Deuxième appel - utilisation du cache
        expect(Embedding::Create).not_to receive(:call)
        Candidate::Search.call(form: form, scope: scope)
      end
      
      it 'increments usage count on cache hit' do
        # Premier appel
        Candidate::Search.call(form: form, scope: scope)
        initial_count = EmbeddingCache.first.usage_count
        
        # Deuxième appel
        Candidate::Search.call(form: form, scope: scope)
        expect(EmbeddingCache.first.usage_count).to eq(initial_count + 1)
      end
    end
    
    context 'when searching by skills' do
      let(:form) { Customer::SearchForm.new(skills: ["BTP", "géomètre"]) }
      
      it 'caches embeddings for each skill' do
        expect {
          Candidate::Search.call(form: form, scope: scope)
        }.to change(EmbeddingCache, :count).by(2)
      end
      
      it 'reuses cached skill embeddings' do
        # Premier appel
        Candidate::Search.call(form: form, scope: scope)
        
        # Deuxième appel - pas d'appel API
        expect(Embedding::Create).not_to receive(:call)
        Candidate::Search.call(form: form, scope: scope)
      end
    end
  end
end