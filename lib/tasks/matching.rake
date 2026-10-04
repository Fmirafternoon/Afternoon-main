namespace :matching do
  desc "Régénère les embeddings manquants (skills + intitulés de poste des candidats publiés)"
  task backfill_embeddings: :environment do
    skills = Skill.where(embedding: nil)
    puts "Skills sans embedding : #{skills.count}"
    ok = 0
    failures = 0
    skills.find_each do |skill|
      Skill::EmbedJob.new.perform(skill.id)
      ok += 1
      print "."
    rescue StandardError => e
      failures += 1
      puts "\n  ✗ Skill##{skill.id} (#{skill.name}) : #{e.message}"
      abort "Arrêt : les 3 premiers appels ont tous échoué — vérifier EMBEDDING_KEY/EMBEDDING_URL" if ok.zero? && failures >= 3
    end
    puts "\nSkills : #{ok} régénérés, #{failures} échecs"

    candidates = Candidate.published.kept.where(job_title_embedding: nil)
    puts "Candidats publiés sans job_title_embedding : #{candidates.count}"
    ok = 0
    failures = 0
    candidates.find_each do |candidate|
      Resume::EmbedJob.new.perform(candidate.id)
      ok += 1
      print "."
    rescue StandardError => e
      failures += 1
      puts "\n  ✗ Candidate##{candidate.id} : #{e.message}"
    end
    puts "\nCandidats : #{ok} régénérés, #{failures} échecs"
  end

  desc "Relance l'analyse LLM des matchs restés bloqués en pending"
  task retry_pending_analyses: :environment do
    stuck = ProjectCandidate.pending
    puts "Matchs bloqués en pending : #{stuck.count}"
    stuck.find_each do |project_candidate|
      ProjectCandidate::AnalyseJob.perform_async(project_candidate.id)
    end
    puts "Analyses réenfilées (nécessite Sidekiq démarré)"
  end

  desc "Relance le matching de tous les projets actifs"
  task rematch: :environment do
    projects = Project.active
    puts "Projets actifs à re-matcher : #{projects.count}"
    projects.find_each do |project|
      Project::MatchCandidatesJob.perform_async(project.id)
    end
    puts "Jobs de matching réenfilés (nécessite Sidekiq démarré)"
  end

  desc "Réparation complète : embeddings manquants, analyses bloquées, puis re-matching"
  task repair: :environment do
    Rake::Task["matching:backfill_embeddings"].invoke
    Rake::Task["matching:retry_pending_analyses"].invoke
    Rake::Task["matching:rematch"].invoke
  end
end
