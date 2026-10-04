# Feature : Expiration automatique des candidats

## 1. Documentation Fonctionnelle

### Qu'est-ce que ça fait ?

Quand un agent publie un candidat, celui-ci reste visible **14 jours maximum**. Passé ce délai, le candidat est automatiquement dépublié pour éviter de présenter des profils obsolètes aux clients.

### Le cycle de vie

```
J+0                    J+11-12              J+14
 │                        │                   │
 ▼                        ▼                   ▼
┌──────────┐         ┌─────────┐         ┌──────────┐
│ PUBLIÉ   │ ──────► │ EMAIL   │ ──────► │ DÉPUBLIÉ │
│          │         │ ENVOYÉ  │         │ (draft)  │
└──────────┘         └─────────┘         └──────────┘
     │                    │
     │               L'agent peut :
     │               • Prolonger (+14j)
     │               • Dépublier maintenant
     │
     └── Expire dans 14 jours
```

### Ce que voit l'agent

**À J+11/12** : L'agent reçoit un email :

> **Objet** : [Afternoon] Prolonger ou dépublier Jean Dupont ?
>
> La publication du candidat **Jean Dupont** (Développeur Ruby) arrive à expiration dans **2 jours**.
>
> [✓ Prolonger de 14 jours]  [✗ Dépublier maintenant]

### Actions possibles

| Action | Résultat |
|--------|----------|
| **Prolonger** | Le candidat reste publié 14 jours de plus, l'agent sera re-notifié à J+26 |
| **Dépublier** | Le candidat passe en brouillon immédiatement |
| **Ne rien faire** | Le candidat est automatiquement dépublié à J+14 |

### Prérequis pour que ça fonctionne

1. **Les jobs cron doivent tourner** (via sidekiq) :
   - `CandidateExpirationReminderJob` : tous les jours à 9h
   - `CandidateAutoExpirationJob` : tous les jours à 10h

2. **Les emails doivent être configurés** (SMTP, `EMAIL_SENDER`)

3. **Les routes doivent être accessibles** sans authentification :
   - `GET /candidate_expirations/extend?token=xxx`
   - `GET /candidate_expirations/unpublish?token=xxx`

---

## 2. Documentation Technique

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         SCHEDULING                               │
│  config/schedule.yml (solid_queue cron)                         │
│  • 09:00 → CandidateExpirationReminderJob                       │
│  • 10:00 → CandidateAutoExpirationJob                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                           JOBS                                   │
├─────────────────────────────────────────────────────────────────┤
│ CandidateExpirationReminderJob                                  │
│  • Scope: Candidate.expiring_soon                               │
│  • Action: Envoie email + marque expiration_notified_at         │
├─────────────────────────────────────────────────────────────────┤
│ CandidateAutoExpirationJob                                      │
│  • Scope: Candidate.expired                                     │
│  • Action: candidate.expire_workflow! → passe en draft          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                          MODEL                                   │
│  app/models/candidate.rb                                        │
├─────────────────────────────────────────────────────────────────┤
│ Colonnes:                                                       │
│  • expires_at (datetime) - date d'expiration                    │
│  • expiration_notified_at (datetime) - date notification        │
├─────────────────────────────────────────────────────────────────┤
│ Scopes:                                                         │
│  • expiring_soon: published + expires <= 3j + non notifié       │
│  • expired: published + (expiré ET notifié) OU expiré > 7j      │
├─────────────────────────────────────────────────────────────────┤
│ Méthodes:                                                       │
│  • extend_publication! → expires_at = 14.days.from_now          │
│  • expire_workflow! (AASM) → draft + clear dates                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         MAILER                                   │
│  app/mailers/agent_mailer.rb#candidate_expiration_reminder      │
├─────────────────────────────────────────────────────────────────┤
│ Génère 2 tokens signés (MessageVerifier) avec expiration 3j:    │
│  • extend_token: {candidate_id, action: 'extend', expires_at}   │
│  • unpublish_token: {candidate_id, action: 'unpublish', ...}    │
├─────────────────────────────────────────────────────────────────┤
│ Templates:                                                      │
│  • candidate_expiration_reminder.html.erb                       │
│  • candidate_expiration_reminder.text.erb                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       CONTROLLER                                 │
│  app/controllers/candidate_expirations_controller.rb            │
├─────────────────────────────────────────────────────────────────┤
│ Routes (sans auth):                                             │
│  • GET /candidate_expirations/extend?token=xxx                  │
│  • GET /candidate_expirations/unpublish?token=xxx               │
├─────────────────────────────────────────────────────────────────┤
│ before_action :verify_token                                     │
│  • Vérifie signature (MessageVerifier)                          │
│  • Vérifie expiration du token                                  │
│  • Charge @candidate                                            │
├─────────────────────────────────────────────────────────────────┤
│ Actions:                                                        │
│  • extend_publication → @candidate.extend_publication!          │
│  • unpublish → @candidate.unpublish_workflow!                   │
└─────────────────────────────────────────────────────────────────┘
```

### Flux de données

```ruby
# Publication (state machine)
candidate.publish_workflow!
# → published_at = Time.current
# → expires_at = 14.days.from_now

# Job reminder (J+11-12, 9h)
Candidate.expiring_soon.find_each do |c|
  AgentMailer.candidate_expiration_reminder(c.id).deliver_now
  c.update_column(:expiration_notified_at, Time.current)
end

# Job auto-expiration (J+14, 10h)
Candidate.expired.find_each do |c|
  c.expire_workflow!  # → draft, clear all dates
end

# Extension manuelle
candidate.extend_publication!
# → expires_at = 14.days.from_now
# → expiration_notified_at = nil (reset pour re-notifier)
```

### Scopes SQL

```ruby
# expiring_soon
published
  .where('expires_at <= ? AND expires_at > ? AND expiration_notified_at IS NULL',
         3.days.from_now, Time.current)

# expired (avec fallback safety)
published
  .where('(expires_at <= ? AND expiration_notified_at IS NOT NULL) OR expires_at <= ?',
         Time.current, 7.days.ago)
```

### Index DB pour performance

```ruby
add_index :candidates,
          [:publication_status, :expires_at, :expiration_notified_at],
          name: 'index_candidates_on_expiration_query'
```

### Sécurité des tokens

```ruby
# Génération
Rails.application.message_verifier(:candidate_expiration).generate({
  candidate_id: candidate.id,
  action: 'extend',
  expires_at: 3.days.from_now  # Token valide 3 jours
})

# Vérification
data = Rails.application.message_verifier(:candidate_expiration).verify(token)
# Lève InvalidSignature si falsifié
```

### Fichiers impliqués

| Fichier | Rôle |
|---------|------|
| `db/migrate/*_add_expiration_to_candidates.rb` | Colonnes `expires_at`, `expiration_notified_at` |
| `db/migrate/*_add_expiration_index_to_candidates.rb` | Index composite |
| `app/models/candidate.rb` | Scopes + `extend_publication!` |
| `app/models/concerns/candidate/publication_state_machine.rb` | `expire_workflow` event |
| `app/jobs/candidate_expiration_reminder_job.rb` | Envoi notifications |
| `app/jobs/candidate_auto_expiration_job.rb` | Dépublication auto |
| `app/mailers/agent_mailer.rb` | Email avec tokens |
| `app/views/agent_mailer/candidate_expiration_reminder.*` | Templates email |
| `app/controllers/candidate_expirations_controller.rb` | Actions extend/unpublish |
| `config/routes/base.rb` | Routes publiques |
| `config/schedule.yml` | Cron jobs |

### Tests

```bash
# Lancer tous les tests de la feature
bundle exec rspec \
  spec/models/candidate_spec.rb \
  spec/jobs/candidate_auto_expiration_job_spec.rb \
  spec/jobs/candidate_expiration_reminder_job_spec.rb \
  spec/controllers/candidate_expirations_controller_spec.rb \
  spec/features/candidate_expiration_workflow_spec.rb \
  spec/mailers/agent_mailer/candidate_expiration_reminder_spec.rb
```

**Couverture** : 125 tests couvrant modèle, jobs, controller, mailer et workflow complet.
