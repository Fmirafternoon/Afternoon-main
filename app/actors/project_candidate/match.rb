class ProjectCandidate::Match < Actor
  POSITION_WEIGHT = 0.40
  SKILLS_WEIGHT = 0.30
  EXPERIENCE_WEIGHT = 0.15
  LANGUAGES_WEIGHT = 0.15

  POSITION_MIN_SIMILARITY = 0.75
  SKILL_MIN_SIMILARITY = 0.70
  SENIORITY_PENALTY_PER_LEVEL = 0.25
  LOCATION_RADIUS_KM = 50
  DEFAULT_LIMIT = 5
  MIN_TOTAL_SCORE = 0.50

  input :project, type: Project
  input :limit, type: Integer, default: DEFAULT_LIMIT

  output :matches, type: Array, default: -> { [] }

  def call
    return if project.position_name.blank?

    candidates = base_candidates
    candidates = filter_by_contract_type(candidates)
    candidates = filter_by_location(candidates)
    candidates = filter_by_position_similarity(candidates)

    scored_candidates = score_candidates(candidates)

    self.matches = scored_candidates
      .select { |match| match[:score] >= MIN_TOTAL_SCORE }
      .sort_by { |match| -match[:score] }
      .first(limit)
  end

  private

  def base_candidates
    Candidate.published.kept
  end

  def filter_by_contract_type(scope)
    return scope if project.contract_type.blank?

    scope.where(contract_type: project.contract_type)
  end

  def filter_by_location(scope)
    return scope unless project.location&.latitude.present?

    scope.near_location(
      project.location.latitude,
      project.location.longitude,
      LOCATION_RADIUS_KM
    )
  end

  def filter_by_position_similarity(scope)
    embedding = position_embedding
    return scope.none if embedding.blank?

    max_distance = 1 - POSITION_MIN_SIMILARITY
    distance_sql = "job_title_embedding <=> ARRAY[#{embedding.join(',')}]::vector"

    scope
      .where.not(job_title_embedding: nil)
      .where("#{distance_sql} < ?", max_distance)
      .select("candidates.*, #{distance_sql} AS position_distance")
  end

  def score_candidates(candidates)
    candidates.map do |candidate|
      position_score = calculate_position_score(candidate)
      skills_score = calculate_skills_score(candidate)
      experience_score = calculate_experience_score(candidate)
      languages_score = calculate_languages_score(candidate)

      total_score = (position_score * POSITION_WEIGHT) +
                    (skills_score * SKILLS_WEIGHT) +
                    (experience_score * EXPERIENCE_WEIGHT) +
                    (languages_score * LANGUAGES_WEIGHT)

      {
        candidate: candidate,
        score: total_score.round(4),
        details: {
          position: position_score.round(4),
          skills: skills_score.round(4),
          experience: experience_score.round(4),
          languages: languages_score.round(4)
        }
      }
    end
  end

  def calculate_position_score(candidate)
    return 0.0 unless candidate.respond_to?(:position_distance)

    distance = candidate.position_distance.to_f
    1.0 - distance
  end

  def calculate_skills_score(candidate)
    return 1.0 if project_skills_with_embedding.empty?

    candidate_skills = candidate.candidate_skills.includes(:skill).select { |cs| cs.skill.embedding.present? }
    return 0.0 if candidate_skills.empty?

    project_skills_with_embedding.sum do |project_skill|
      best_match = candidate_skills.max_by do |candidate_skill|
        1.0 - cosine_distance(project_skill.skill.embedding, candidate_skill.skill.embedding)
      end

      similarity = 1.0 - cosine_distance(project_skill.skill.embedding, best_match.skill.embedding)
      next 0.0 if similarity < SKILL_MIN_SIMILARITY

      similarity * seniority_factor(project_skill, best_match)
    end / project_skills_with_embedding.size
  end

  def seniority_factor(project_skill, candidate_skill)
    return 1.0 if project_skill.seniority.blank?      # C : projet n'exige rien → pas de pénalité
    return 1.0 if candidate_skill.seniority.blank?    # B : séniorité candidat inconnue → pas de pénalité

    gap = ProjectSkill.seniorities[project_skill.seniority] - CandidateSkill.seniorities[candidate_skill.seniority]
    return 1.0 if gap <= 0                             # candidat ≥ demandé → pas de pénalité

    [1.0 - SENIORITY_PENALTY_PER_LEVEL * gap, 0.25].max   # A : pénalité proportionnelle, plancher 0,25
  end




  def calculate_experience_score(candidate)
    return 1.0 if project.min_experience_years.blank? || project.min_experience_years.zero?

    candidate_years = candidate_experience_years(candidate)
    return 0.0 if candidate_years.zero?

    if candidate_years >= project.min_experience_years
      1.0
    else
      candidate_years.to_f / project.min_experience_years
    end
  end

  def calculate_languages_score(candidate)
    project_languages = project.languages || []
    return 1.0 if project_languages.empty?

    candidate_languages = candidate.candidate_languages.pluck(:code)
    return 1.0 if candidate_languages.empty? # Pas renseigné = pas pénalisé

    matching_count = (project_languages & candidate_languages).size
    matching_count.to_f / project_languages.size
  end

  def candidate_experience_years(candidate)
    total_months = candidate.employments.sum do |emp|
      emp.duration_in_months.to_i
    end
    (total_months / 12.0).round
  end

  def position_embedding
    @position_embedding ||= EmbeddingCache.get_embedding(project.position_name)
  end

  def project_skills_with_embedding
    @project_skills_with_embedding ||= project.project_skills.includes(:skill).select { |ps| ps.skill.embedding.present? }
  end

  def cosine_distance(a, b)
    dot = a.zip(b).sum { |x, y| x * y }
    mag_a = Math.sqrt(a.sum { |x| x**2 })
    mag_b = Math.sqrt(b.sum { |x| x**2 })
    return 1.0 if mag_a.zero? || mag_b.zero?

    1.0 - (dot / (mag_a * mag_b))
  end
end
