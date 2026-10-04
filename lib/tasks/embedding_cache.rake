namespace :embedding_cache do
  desc "Show cache statistics"
  task stats: :environment do
    stats = EmbeddingCache.stats
    
    puts "\n=== Embedding Cache Statistics ==="
    puts "Total entries: #{stats[:total_entries]}"
    puts "Cache size: ~#{stats[:size_mb]} MB"
    puts "Total API calls saved: #{stats[:total_usage] - stats[:total_entries]}"
    puts "Cache hit rate: #{stats[:cache_hit_rate]}%"
    puts "Average usage per entry: #{stats[:avg_usage]}"
    
    if stats[:most_popular].any?
      puts "\nTop 10 most searched terms:"
      stats[:most_popular].each_with_index do |(text, count), i|
        puts "  #{i+1}. '#{text}' - #{count} times"
      end
    end
    
    # Estimation des économies
    if stats[:total_usage] > stats[:total_entries]
      saved_calls = stats[:total_usage] - stats[:total_entries]
      # Coût approximatif : $0.20 pour 1000 embeddings avec Cohere
      saved_cost = (saved_calls / 1000.0 * 0.20).round(2)
      puts "\nEstimated cost savings: $#{saved_cost}"
    end
  end
  
  desc "Clean old cache entries (older than 90 days)"
  task clean_old: :environment do
    before = EmbeddingCache.count
    old_entries = EmbeddingCache.where(last_used_at: ..90.days.ago)
    
    if old_entries.any?
      puts "Found #{old_entries.count} entries older than 90 days"
      old_entries.destroy_all
      puts "Cleaned #{before - EmbeddingCache.count} entries"
    else
      puts "No old entries found"
    end
  end
  
  desc "Warm cache with popular saved searches"
  task warm_saved_searches: :environment do
    puts "Warming cache with saved search queries..."
    count = 0
    
    SavedSearch.find_each do |saved_search|
      query = saved_search.criteria["query"]
      if query.present?
        EmbeddingCache.get_embedding(query)
        count += 1
        print "." if count % 10 == 0
      end
    end
    
    puts "\nWarmed cache with #{count} saved search queries"
  end
  
  desc "Clean cache if above size limit"
  task cleanup: :environment do
    before = EmbeddingCache.count
    EmbeddingCache.cleanup_if_needed
    after = EmbeddingCache.count
    
    if before > after
      puts "Cleaned #{before - after} entries (LRU strategy)"
      puts "Cache now has #{after} entries"
    else
      puts "Cache size OK (#{after} entries, limit: #{EmbeddingCache::MAX_CACHE_SIZE})"
    end
  end
  
  desc "Export cache data for analysis"
  task export_csv: :environment do
    require 'csv'
    
    filename = "embedding_cache_#{Date.current}.csv"
    
    CSV.open(filename, "w") do |csv|
      csv << ["Text", "Usage Count", "Last Used", "Created At", "Days Since Last Use"]
      
      EmbeddingCache.order(usage_count: :desc).find_each do |cache|
        days_since = (Date.current - cache.last_used_at.to_date).to_i
        csv << [cache.text, cache.usage_count, cache.last_used_at, cache.created_at, days_since]
      end
    end
    
    puts "Exported cache data to #{filename}"
  end
end