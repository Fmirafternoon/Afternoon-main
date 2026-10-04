class Candidate::Search < Actor
  MAX_RADIUS = 30
  input :form, type: Customer::SearchForm
  input :scope, type: ActiveRecord::Relation

  output :candidates, type: ActiveRecord::Relation, default: -> { [] }

  def call
    result_scope = scope

    if form.query.present?
      # Check if query looks like a public token (4-6 alphanumeric)
      if form.query.match?(/\A[A-Za-z0-9]{4,6}\z/)
        token_match = result_scope.find_by(public_token: form.query.upcase)
        if token_match
          self.candidates = result_scope.where(id: token_match.id)
          return
        end
      end

      max_distance = 0.18
      job_title_embedding = EmbeddingCache.get_embedding(form.query)

      if job_title_embedding.present?
        distance_sql = "job_title_embedding <=> ARRAY[#{job_title_embedding.join(',')}]::vector"
        result_scope = result_scope
          .where.not(job_title_embedding: nil)  # Only exclude when actually doing job_title search
          .where("#{distance_sql} < ?", max_distance)
          .select("candidates.*, #{distance_sql} AS similarity_distance")
          .order("similarity_distance")
      end
    end

    if form.autocomplete_address.present? && (form.lat.present? && form.lng.present?)
      result_scope = result_scope.near_location(form.lat.to_f, form.lng.to_f, MAX_RADIUS)
    end

    if form.sector_ids.present? && form.sector_ids.any?
      result_scope = result_scope.joins(:candidate_sectors)
                                .where(candidate_sectors: { sector_id: form.sector_ids })
                                .distinct
    end

    if form.skills.present? && form.skills.any?
      max_distance = 0.25  # More strict threshold to avoid questionable matches
      skill_candidate_ids = nil

      form.skills.each do |skill_term|
        next if skill_term.blank?

        skill_embedding = EmbeddingCache.get_embedding(skill_term)
        next unless skill_embedding.present?

        distance_sql = "skills.embedding <=> ARRAY[#{skill_embedding.join(',')}]::vector"

        # Debug: get detailed results with skill names and distances
        matching_results = Candidate.joins(candidate_skills: :skill)
                                  .where.not("skills.embedding": nil)
                                  .where("#{distance_sql} < ?", max_distance)
                                  .select("candidates.id, skills.name as skill_name, #{distance_sql} as distance")

        matching_candidates = matching_results.pluck(:id)


        if skill_candidate_ids.nil?
          skill_candidate_ids = matching_candidates
        else
          skill_candidate_ids = skill_candidate_ids & matching_candidates
        end
      end

      if skill_candidate_ids && skill_candidate_ids.any?
        result_scope = result_scope.where(id: skill_candidate_ids)
      else
        result_scope = result_scope.none
      end
    end

    if result_scope == scope
      result_scope = result_scope.order(created_at: :desc)
    end

    self.candidates = result_scope
  end
end
