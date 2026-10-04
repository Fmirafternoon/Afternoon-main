class EmbeddingCache < ApplicationRecord
  # Constantes
  MAX_CACHE_SIZE = 10_000
  
  # Validations
  validates :text_hash, presence: true, uniqueness: true
  validates :text, presence: true
  validates :embedding, presence: true
  
  # Scopes
  scope :recent, -> { order(last_used_at: :desc) }
  scope :popular, -> { order(usage_count: :desc) }
  scope :stale, -> { where(last_used_at: ..30.days.ago) }
  
  # Méthode principale pour obtenir un embedding avec cache
  def self.get_embedding(text)
    return nil if text.blank?
    
    # Normaliser le texte pour le hash
    # Normalize spaces inside the text as well
    normalized_text = text.downcase.strip.gsub(/\s+/, ' ')
    text_hash = Digest::SHA256.hexdigest(normalized_text)
    
    # Chercher dans le cache
    cached = find_by(text_hash: text_hash)
    
    if cached
      # Mise à jour des statistiques d'usage
      cached.touch(:last_used_at)
      cached.increment!(:usage_count)
      return cached.embedding
    end
    
    # Générer un nouvel embedding si pas en cache
    result = Embedding::Create.call(text: [text])
    embedding = result.embedding

    # Si l'embedding est vide (API indisponible), retourner nil sans cacher
    return nil if embedding.blank?

    # Stocker dans le cache
    begin
      create!(
        text_hash: text_hash,
        text: text,
        embedding: embedding,
        last_used_at: Time.current,
        usage_count: 1
      )
    rescue ActiveRecord::RecordNotUnique
      # Gestion de la race condition : quelqu'un d'autre a créé l'entrée
      # Réessayer de récupérer depuis le cache
      cached = find_by(text_hash: text_hash)
      if cached
        cached.touch(:last_used_at)
        cached.increment!(:usage_count)
        return cached.embedding
      end
    end
    
    # Nettoyer le cache si nécessaire
    cleanup_if_needed
    
    embedding
  end
  
  # Nettoyage du cache avec stratégie LRU
  def self.cleanup_if_needed
    current_count = count
    
    if current_count > MAX_CACHE_SIZE
      # Garder 80% des entrées les plus récentes
      keep_count = (MAX_CACHE_SIZE * 0.8).to_i
      
      # Récupérer les IDs à garder
      ids_to_keep = order(last_used_at: :desc)
                     .limit(keep_count)
                     .pluck(:id)
      
      # Supprimer les autres
      where.not(id: ids_to_keep).destroy_all
    end
  end
  
  # Statistiques du cache
  def self.stats
    total_entries = count
    total_usage = sum(:usage_count) || 0
    
    {
      total_entries: total_entries,
      total_usage: total_usage,
      avg_usage: total_entries > 0 ? (total_usage.to_f / total_entries).round(2) : 0.0,
      cache_hit_rate: calculate_hit_rate(total_entries, total_usage),
      size_mb: (total_entries * 4.0 / 1024).round(2), # ~4KB par embedding
      most_popular: popular.limit(10).pluck(:text, :usage_count)
    }
  end
  
  private
  
  def self.calculate_hit_rate(entries, usage)
    return 0.0 if usage == 0
    
    # Nombre de hits = total des usages - nombre d'entrées (car chaque entrée a au moins 1 usage)
    hits = usage - entries
    (hits.to_f / usage * 100).round(2)
  end
end