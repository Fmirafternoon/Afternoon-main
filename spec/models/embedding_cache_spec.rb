require 'rails_helper'

RSpec.describe EmbeddingCache, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:text_hash) }
    it { should validate_presence_of(:text) }
    it { should validate_presence_of(:embedding) }
    
    it 'validates uniqueness of text_hash' do
      create(:embedding_cache)
      duplicate = build(:embedding_cache, text_hash: EmbeddingCache.first.text_hash)
      expect(duplicate).not_to be_valid
    end
  end
  
  describe '.get_embedding' do
    let(:text) { "Conducteur de travaux" }
    let(:embedding) { Array.new(1024) { rand } }
    
    context 'when text is blank' do
      it 'returns nil for nil text' do
        expect(EmbeddingCache.get_embedding(nil)).to be_nil
      end
      
      it 'returns nil for empty text' do
        expect(EmbeddingCache.get_embedding('')).to be_nil
      end
    end
    
    context 'when embedding is not cached' do
      before do
        allow(Embedding::Create).to receive(:call).and_return(
          double(embedding: embedding)
        )
      end
      
      it 'calls Embedding::Create service' do
        expect(Embedding::Create).to receive(:call).with(text: [text])
        EmbeddingCache.get_embedding(text)
      end
      
      it 'creates a new cache entry' do
        expect {
          EmbeddingCache.get_embedding(text)
        }.to change(EmbeddingCache, :count).by(1)
      end
      
      it 'stores the correct data' do
        result = EmbeddingCache.get_embedding(text)
        
        cached = EmbeddingCache.last
        expect(cached.text).to eq(text)
        expect(cached.text_hash).to eq(Digest::SHA256.hexdigest(text.downcase.strip))
        # Check embedding elements are close enough (float precision)
        cached.embedding.each_with_index do |val, i|
          expect(val).to be_within(0.0001).of(embedding[i])
        end
        expect(cached.usage_count).to eq(1)
        expect(cached.last_used_at).to be_present
      end
      
      it 'returns the embedding' do
        result = EmbeddingCache.get_embedding(text)
        expect(result).to eq(embedding)
      end
    end
    
    context 'when embedding is cached' do
      let!(:cached_entry) do
        create(:embedding_cache, 
          text: text,
          text_hash: Digest::SHA256.hexdigest(text.downcase.strip),
          embedding: embedding,
          usage_count: 5,
          last_used_at: 1.hour.ago
        )
      end
      
      it 'does not call Embedding::Create service' do
        expect(Embedding::Create).not_to receive(:call)
        EmbeddingCache.get_embedding(text)
      end
      
      it 'does not create a new entry' do
        expect {
          EmbeddingCache.get_embedding(text)
        }.not_to change(EmbeddingCache, :count)
      end
      
      it 'increments usage count' do
        expect {
          EmbeddingCache.get_embedding(text)
        }.to change { cached_entry.reload.usage_count }.from(5).to(6)
      end
      
      it 'updates last_used_at' do
        old_time = cached_entry.last_used_at
        EmbeddingCache.get_embedding(text)
        expect(cached_entry.reload.last_used_at).to be > old_time
      end
      
      it 'returns the cached embedding' do
        result = EmbeddingCache.get_embedding(text)
        # Check embedding elements are close enough (float precision)
        result.each_with_index do |val, i|
          expect(val).to be_within(0.0001).of(cached_entry.embedding[i])
        end
      end
    end
    
    context 'with text normalization' do
      before(:each) do
        # Ensure we start with a clean cache for each test
        EmbeddingCache.destroy_all
      end
      
      it 'treats uppercase and lowercase as same' do
        # Allow only one call to the embedding service
        expect(Embedding::Create).to receive(:call).once.and_return(
          double(embedding: embedding)
        )
        
        # First call with uppercase
        EmbeddingCache.get_embedding("CONDUCTEUR de travaux")
        
        # Second call with lowercase should use cache
        result = EmbeddingCache.get_embedding("conducteur de travaux")
        
        expect(EmbeddingCache.count).to eq(1)
        expect(result).to be_present
      end
      
      it 'treats text with extra spaces as same' do
        # Mock the embedding service to track calls
        allow(Embedding::Create).to receive(:call).and_return(
          double(embedding: embedding)
        )
        
        # First call with extra spaces
        result1 = EmbeddingCache.get_embedding("  conducteur   de   travaux  ")
        
        # Verify the service was called once
        expect(Embedding::Create).to have_received(:call).once
        
        # Second call without spaces should use cache
        result2 = EmbeddingCache.get_embedding("conducteur de travaux")
        
        # Verify the service was not called again
        expect(Embedding::Create).to have_received(:call).once
        
        # Verify behavior
        expect(EmbeddingCache.count).to eq(1)
        # Compare embeddings element by element with tolerance for floating point precision
        result1.each_with_index do |val, i|
          expect(val).to be_within(0.0001).of(result2[i])
        end
      end
    end
    
    context 'race condition handling' do
      before do
        allow(Embedding::Create).to receive(:call).and_return(
          double(embedding: embedding)
        )
      end
      
      it 'handles concurrent creation gracefully' do
        # Test simplifié : on vérifie juste que le code gère l'exception
        # En pratique, si deux processus créent en même temps, l'un aura RecordNotUnique
        # et devrait récupérer l'entrée créée par l'autre
        
        text = "concurrent text"
        
        # La recherche après l'échec trouve l'entrée créée par "l'autre processus"
        existing_entry = create(:embedding_cache, 
          text: text,
          text_hash: Digest::SHA256.hexdigest(text.downcase.strip),
          embedding: embedding
        )
        
        # Première tentative échoue avec RecordNotUnique
        allow(EmbeddingCache).to receive(:create!).once.and_raise(ActiveRecord::RecordNotUnique)
        
        result = EmbeddingCache.get_embedding(text)
        # Check embedding elements are close enough (float precision)
        result.each_with_index do |val, i|
          expect(val).to be_within(0.0001).of(existing_entry.embedding[i])
        end
      end
    end
  end
  
  describe '.cleanup_if_needed' do
    context 'when below MAX_CACHE_SIZE' do
      before do
        create_list(:embedding_cache, 5)
      end
      
      it 'does not delete any entries' do
        expect {
          EmbeddingCache.cleanup_if_needed
        }.not_to change(EmbeddingCache, :count)
      end
    end
    
    context 'when above MAX_CACHE_SIZE' do
      before do
        stub_const('EmbeddingCache::MAX_CACHE_SIZE', 10)
        
        # Créer 15 entrées avec différentes dates d'utilisation
        15.times do |i|
          create(:embedding_cache, 
            last_used_at: i.hours.ago,
            usage_count: 15 - i
          )
        end
      end
      
      it 'reduces count to 80% of MAX_CACHE_SIZE' do
        EmbeddingCache.cleanup_if_needed
        expect(EmbeddingCache.count).to eq(8) # 80% de 10
      end
      
      it 'keeps the most recently used entries' do
        oldest_before = EmbeddingCache.order(last_used_at: :asc).first
        newest_before = EmbeddingCache.order(last_used_at: :desc).first
        
        EmbeddingCache.cleanup_if_needed
        
        expect(EmbeddingCache.exists?(oldest_before.id)).to be_falsey
        expect(EmbeddingCache.exists?(newest_before.id)).to be_truthy
      end
    end
  end
  
  describe '.stats' do
    before do
      create(:embedding_cache, usage_count: 10)
      create(:embedding_cache, usage_count: 5)
      create(:embedding_cache, usage_count: 3)
    end
    
    it 'returns correct statistics' do
      stats = EmbeddingCache.stats
      
      expect(stats[:total_entries]).to eq(3)
      expect(stats[:total_usage]).to eq(18)
      expect(stats[:avg_usage]).to eq(6.0)
      expect(stats[:cache_hit_rate]).to eq(83.33) # (18-3)/18 * 100
      expect(stats[:size_mb]).to be_within(0.01).of(0.01) # 3 * 4KB / 1024
    end
    
    it 'includes most popular entries' do
      stats = EmbeddingCache.stats
      
      expect(stats[:most_popular].first[1]).to eq(10) # usage_count du plus populaire
    end
  end
  
  describe 'scopes' do
    let!(:recent) { create(:embedding_cache, last_used_at: 1.minute.ago) }
    let!(:old) { create(:embedding_cache, last_used_at: 1.day.ago) }
    let!(:popular) { create(:embedding_cache, usage_count: 100, last_used_at: 1.hour.ago) }
    let!(:unpopular) { create(:embedding_cache, usage_count: 1, last_used_at: 2.hours.ago) }
    
    describe '.recent' do
      it 'orders by last_used_at desc' do
        results = EmbeddingCache.recent
        # The most recent should come first
        expect(results.first.id).to eq(recent.id)
        # The oldest should come last
        expect(results.last.id).to eq(old.id)
      end
    end
    
    describe '.popular' do
      it 'orders by usage_count desc' do
        expect(EmbeddingCache.popular.first).to eq(popular)
      end
    end
    
    describe '.stale' do
      let!(:very_old) { create(:embedding_cache, last_used_at: 35.days.ago) }
      
      it 'returns entries older than 30 days' do
        expect(EmbeddingCache.stale).to include(very_old)
        expect(EmbeddingCache.stale).not_to include(recent)
      end
    end
  end
end