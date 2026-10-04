# Procédure de test pour les alertes email de SavedSearch

## URL de prévisualisation
Pour voir le rendu de l'email :
```
http://localhost:3000/rails/mailers/digest_mailer/weekly_alert
```

## Procédure de test complète

### 1. Préparation de l'environnement

```bash
# S'assurer que Sidekiq est lancé
bundle exec sidekiq

# Dans une autre console, lancer le serveur Rails
rails server
```

### 2. Créer des données de test

```ruby
# Dans la console Rails (rails console)

# Créer un customer
customer = User.create!(
  email: "test.customer@example.com",
  password: "password123",
  role: "customer",
  first_name: "Test",
  last_name: "Customer"
)

# Créer une recherche sauvegardée avec alertes activées
saved_search = SavedSearch.create!(
  customer: customer,
  name: "Développeurs Ruby Paris",
  criteria: {
    query: "Ruby",
    city: "Paris",
    skills: ["Ruby on Rails"]
  },
  email_alerts_enabled: true
)

# Créer quelques candidats qui matchent
location = Location.find_or_create_by!(city: "Paris", department: "75")
skill = Skill.find_or_create_by!(name: "Ruby on Rails")

3.times do |i|
  candidate = Candidate.create!(
    first_name: "Test#{i}",
    last_name: "Candidat#{i}",
    email: "candidat#{i}@test.com",
    phone_number: "0123456789",
    position: "Développeur Ruby",
    total_experience_in_years: 3 + i,
    location: location,
    publication_status: "published"
  )
  
  CandidateSkill.create!(candidate: candidate, skill: skill)
end
```

### 3. Tester l'envoi manuel

```ruby
# Dans la console Rails
WeeklyDigestJob.new.perform

# Vérifier les logs pour voir si l'email a été envoyé
```

### 4. Tester le scheduler

```ruby
# Vérifier que le job est bien programmé
require 'sidekiq-scheduler'
Sidekiq.get_schedule

# Forcer l'exécution immédiate (pour test)
Sidekiq::Scheduler.schedule_job('weekly_digest')
```

### 5. Vérifier le tracking des candidats vus

```ruby
# Avant l'envoi
saved_search.viewed_candidates.count
# => 0

# Après l'envoi
WeeklyDigestJob.new.perform
saved_search.reload.viewed_candidates.count
# => 3 (ou moins selon la limite)

# Vérifier que last_alert_sent_at est mis à jour
saved_search.reload.last_alert_sent_at
# => 2025-01-24 15:30:00 (environ)
```

### 6. Tester la désincription

```ruby
# Générer un token de désinscription
token = Rails.application.message_verifier(:unsubscribe).generate({
  saved_search_id: saved_search.id,
  expires_at: 30.days.from_now
})

# URL de désinscription
url = "http://localhost:3000/unsubscribe/saved_search?token=#{token}"

# Visiter cette URL désactivera les alertes pour cette recherche
```

### 7. Vérifier dans letter_opener (développement)

Si letter_opener est configuré, les emails seront ouverts automatiquement dans le navigateur en développement.

### 8. Tests automatisés

```bash
# Lancer les tests spécifiques
rspec spec/models/saved_search_spec.rb
rspec spec/jobs/weekly_digest_job_spec.rb
rspec spec/mailers/digest_mailer_spec.rb

# Ou tous les tests
rspec
```

### 9. Vérifier la fréquence d'envoi

```ruby
# Un email ne devrait pas être renvoyé avant 1 semaine
saved_search.should_send_alert?
# => false (si envoyé récemment)

# Simuler le passage du temps
saved_search.update!(last_alert_sent_at: 8.days.ago)
saved_search.should_send_alert?
# => true
```

### 10. Debugging

```ruby
# Voir tous les jobs programmés
Sidekiq::ScheduledSet.new.each { |job| puts job.inspect }

# Voir la file d'attente
Sidekiq::Queue.new("mailers").each { |job| puts job.inspect }

# Forcer l'envoi pour un customer spécifique
DigestMailer.weekly_alert(
  customer: customer,
  alerts_data: [{
    search: saved_search,
    candidates: saved_search.find_new_candidates.limit(5),
    total_count: saved_search.find_new_candidates.count
  }]
).deliver_now
```