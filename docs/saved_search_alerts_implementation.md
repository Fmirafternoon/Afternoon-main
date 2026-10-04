# 📧 Implémentation des Alertes Email pour les Saved Searches

## 🎯 Vue d'ensemble

Cette fonctionnalité permet aux utilisateurs (customers) de recevoir des alertes email (digest hebdomadaire) lorsque de nouveaux candidats correspondent à leurs recherches sauvegardées. L'approche est optimisée pour éviter le spam et réduire la charge serveur.

## 🏗️ Architecture technique

### 1. 🗄️ Modifications de la base de données

#### Table `saved_searches` - Ajout de colonnes

```ruby
class AddEmailAlertsToSavedSearches < ActiveRecord::Migration[8.0]
  def change
    add_column :saved_searches, :email_alerts_enabled, :boolean, default: false, null: false
    add_column :saved_searches, :last_alert_sent_at, :datetime

    add_index :saved_searches, :email_alerts_enabled
    add_index :saved_searches, [:email_alerts_enabled, :last_alert_sent_at]
  end
end
```

#### Table `saved_search_viewed_candidates` - Tracking des candidats vus

```ruby
class CreateSavedSearchViewedCandidates < ActiveRecord::Migration[8.0]
  def change
    create_table :saved_search_viewed_candidates do |t|
      t.references :saved_search, null: false, foreign_key: true
      t.references :candidate, null: false, foreign_key: true
      t.datetime :viewed_at, null: false

      t.timestamps
    end

    add_index :saved_search_viewed_candidates,
              [:saved_search_id, :candidate_id],
              unique: true,
              name: 'idx_unique_saved_search_candidate'
  end
end
```

### 2. 📦 Modifications des modèles

#### SavedSearch

```ruby
class SavedSearch < ApplicationRecord
  # Associations existantes...
  has_many :saved_search_viewed_candidates, dependent: :destroy
  has_many :viewed_candidates, through: :saved_search_viewed_candidates, source: :candidate
  
  # Constants
  ALERT_FREQUENCY = 1.week # V2: rendre configurable (2.weeks, 1.month, etc.)
  
  # Scopes
  scope :with_alerts_enabled, -> { where(email_alerts_enabled: true) }
  scope :ready_for_alert, -> {
    with_alerts_enabled
      .where('last_alert_sent_at IS NULL OR last_alert_sent_at < ?', ALERT_FREQUENCY.ago)
  }

  def toggle_email_alerts!
    update!(email_alerts_enabled: !email_alerts_enabled)
  end

  def mark_candidates_as_viewed(candidates)
    return if candidates.empty?
    
    # Utilise upsert pour éviter les doublons
    viewed_records = candidates.map do |candidate|
      {
        saved_search_id: id,
        candidate_id: candidate.id,
        viewed_at: Time.current,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    SavedSearchViewedCandidate.upsert_all(viewed_records, unique_by: [:saved_search_id, :candidate_id])
  end

  def find_new_candidates
    # Utilise le même actor que le contrôleur pour la recherche
    result = Candidate::Search.call(
      scope: Candidate.all,
      form: Customer::SearchForm.new(criteria)
    )
    
    candidates = result.candidates.published.kept
    
    # Exclut les candidats déjà vus
    viewed_candidate_ids = SavedSearchViewedCandidate
      .where(saved_search_id: id)
      .pluck(:candidate_id)
    
    candidates = candidates.where.not(id: viewed_candidate_ids) if viewed_candidate_ids.any?
    
    # Filtre par date de création pour les nouveaux candidats
    if last_alert_sent_at.present?
      candidates = candidates.where('candidates.created_at >= ?', last_alert_sent_at)
    end
    
    candidates
  end
  
  def should_send_alert?
    return false unless email_alerts_enabled?
    
    last_alert_sent_at.nil? || last_alert_sent_at < ALERT_FREQUENCY.ago
  end
end
```

### 3. ⚙️ Job d'envoi des alertes (Digest)

```ruby
class WeeklyDigestJob < ApplicationJob
  queue_as :mailers

  def perform
    User.joins(:saved_searches)
        .where(saved_searches: { email_alerts_enabled: true })
        .distinct
        .find_each do |customer|
      process_customer_digest(customer)
    end
  end

  private

  def process_customer_digest(customer)
    alerts_data = []
    
    customer.saved_searches.with_alerts_enabled.each do |saved_search|
      next unless saved_search.should_send_alert?
      
      new_candidates = saved_search.find_new_candidates.limit(5)
      next if new_candidates.empty?
      
      alerts_data << {
        search: saved_search,
        candidates: new_candidates,
        total_count: saved_search.find_new_candidates.count
      }
      
      # Marque les candidats comme vus
      saved_search.mark_candidates_as_viewed(new_candidates)
    end
    
    return if alerts_data.empty?
    
    # Envoie le digest
    DigestMailer.weekly_alert(
      customer: customer,
      alerts_data: alerts_data
    ).deliver_later
    
    # Met à jour la date du dernier envoi
    customer.saved_searches.with_alerts_enabled.update_all(
      last_alert_sent_at: Time.current
    )
  rescue => e
    Rails.logger.error "Erreur digest pour customer #{customer.id}: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
  end
end
```

### 4. ✉️ Mailer

```ruby
class DigestMailer < ApplicationMailer
  def weekly_alert(customer:, alerts_data:)
    @customer = customer
    @alerts_data = alerts_data
    @total_candidates = alerts_data.sum { |data| data[:candidates].size }
    @unsubscribe_token = generate_unsubscribe_token

    mail(
      to: @customer.email,
      subject: "📊 #{@total_candidates} nouveaux candidats cette semaine"
    )
  end

  private

  def generate_unsubscribe_token
    Rails.application.message_verifier(:unsubscribe).generate(
      {
        customer_id: @customer.id,
        action: 'unsubscribe_all',
        expires_at: 30.days.from_now
      }
    )
  end
end
```

### 5. ⏰ Configuration Sidekiq-scheduler

```yaml
# config/sidekiq-scheduler.yml
weekly_digest:
  cron: "0 12 * * 1"  # Tous les lundis à 12h00
  class: WeeklyDigestJob
  queue: mailers
  description: "Envoie le digest hebdomadaire des saved searches"
  # V2: Pour bi-hebdomadaire, utiliser un job qui vérifie le modulo des semaines
```

## 🎨 Flow utilisateur (UX)

### 🗺️ Vue d'ensemble du parcours utilisateur

1. **Activation des alertes** : Lors de la sauvegarde d'une recherche, l'utilisateur peut cocher "Recevoir des alertes par email"
2. **Confirmation visuelle** : Une icône de cloche verte apparaît sur la saved search dans la liste
3. **Réception du digest** : Chaque lundi à 12h, l'utilisateur reçoit un email récapitulatif avec tous les nouveaux candidats de la semaine pour toutes ses recherches actives
4. **Actions possibles** :
   - Cliquer sur un candidat pour voir son profil complet
   - Désactiver les alertes depuis le dropdown menu de chaque recherche
   - Se désinscrire via le lien en bas de l'email
5. **Tracking automatique** : Les candidats envoyés sont marqués comme "vus" pour éviter les doublons la semaine suivante

### 1. ➕ Création d'une saved search avec alerte (Modal Turbo Frame)

```erb
<%= turbo_frame_tag :modal do %>
  <div class="bg-white max-w-full w-[600px] p-8 rounded-lg">
    <h1 class="modal-title mb-6">Sauvegarder cette recherche</h1>

    <%= simple_form_for @saved_search,
        url: customer_saved_searches_path,
        html: { data: { turbo_frame: "_top" } } do |f| %>

      <!-- Existing criteria summary div... -->

      <%= f.input :name,
                  label: "Nom de la recherche",
                  placeholder: "Ex: Géomètres Bordeaux",
                  input_html: { class: "mt-1", autofocus: true } %>

      <div class="mt-6 p-4 bg-gray-50 rounded-lg">
        <div class="flex items-start">
          <%= f.input :email_alerts_enabled,
                      as: :boolean,
                      label: false,
                      inline_label: "Recevoir des alertes par email",
                      input_html: { 
                        class: "mr-2",
                        data: { 
                          action: "change->saved-search-form#toggleFrequency" 
                        }
                      } %>
        </div>
        
          <!-- Fréquence fixée à hebdomadaire pour le moment -->
        <p class="text-sm text-gray-600 mt-2" data-saved-search-form-target="frequencyInfo">
          ℹ️ Vous recevrez un récapitulatif chaque lundi avec tous les nouveaux candidats de la semaine
        </p>
      </div>

      <%= f.hidden_field :criteria, value: @search_form.attributes.to_json %>

      <div class="flex justify-end gap-2 mt-6">
        <%= f.submit 'Sauvegarder', class: 'button-primary' %>
        <%= link_to 'Annuler', '#',
            data: { action: 'turbo-modal#close' },
            class: 'button-secondary' %>
      </div>
    <% end %>
  </div>
<% end %>
```

### 2. 📋 SavedSearchItemComponent modifié

```erb
<!-- app/components/saved_search_item_component.html.erb -->
<li id="saved_search_<%= saved_search.id %>" class="<%= container_classes %> p-4">
  <div class="flex items-center gap-x-4 w-full">
    <!-- Dropdown menu existant -->
    <div class="flex items-start gap-x-2 self-start">
      <!-- Icône d'alerte -->
      <% if saved_search.email_alerts_enabled? %>
        <div class="relative" title="Alertes activées (hebdomadaires)">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5 text-green-600">
            <path stroke-linecap="round" stroke-linejoin="round" d="M14.857 17.082a23.848 23.848 0 0 0 5.454-1.31A8.967 8.967 0 0 1 18 9.75V9A6 6 0 0 0 6 9v.75a8.967 8.967 0 0 1-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 0 1-5.714 0m5.714 0a3 3 0 1 1-5.714 0" />
          </svg>
          <!-- Le badge de comptage sera ajouté dans une V2 -->
        </div>
      <% else %>
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5 text-gray-400">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9.143 17.082a24.248 24.248 0 0 0 3.844.148m-3.844-.148a23.856 23.856 0 0 1-5.455-1.31 8.964 8.964 0 0 0 2.3-5.542m3.155 6.852a3 3 0 0 0 5.667 1.97m1.965-2.277L21 21m-4.225-4.225a23.81 23.81 0 0 0 3.536-1.003A8.967 8.967 0 0 1 18 9.75V9A6 6 0 0 0 6.53 6.53m10.245 10.245L6.53 6.53M3 3l3.53 3.53" />
        </svg>
      <% end %>
      
      <%= render DropdownComponent.new(position: :left) do |dropdown| %>
        <!-- Trigger existant... -->
        <%= dropdown.with_body do %>
          <%= link_to toggle_alerts_customer_saved_search_path(saved_search),
                      data: { turbo_method: :post },
                      class: "link-dropdown" do %>
            <% if saved_search.email_alerts_enabled? %>
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 inline mr-2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9.143 17.082a24.248 24.248 0 0 0 3.844.148m-3.844-.148a23.856 23.856 0 0 1-5.455-1.31 8.964 8.964 0 0 0 2.3-5.542m3.155 6.852a3 3 0 0 0 5.667 1.97m1.965-2.277L21 21m-4.225-4.225a23.81 23.81 0 0 0 3.536-1.003A8.967 8.967 0 0 1 18 9.75V9A6 6 0 0 0 6.53 6.53m10.245 10.245L6.53 6.53M3 3l3.53 3.53" />
              </svg>
              Désactiver les alertes
            <% else %>
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 inline mr-2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M14.857 17.082a23.848 23.848 0 0 0 5.454-1.31A8.967 8.967 0 0 1 18 9.75V9A6 6 0 0 0 6 9v.75a8.967 8.967 0 0 1-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 0 1-5.714 0m5.714 0a3 3 0 1 1-5.714 0" />
              </svg>
              Activer les alertes
            <% end %>
          <% end %>
          <div class="border-t border-gray-100 my-1"></div>
          <!-- Delete link existant... -->
        <% end %>
      <% end %>
    </div>
    
    <!-- Rest of the component... -->
  </div>
</li>
```

### 3. 🎮 Contrôleur modifié pour les alertes

```ruby
class Customer::SavedSearchesController < Customer::BaseController
  # Actions existantes : new, create, destroy, load
  
  def toggle_alerts
    @saved_search = current_user.saved_searches.find(params[:id])
    authorize @saved_search
    
    @saved_search.toggle_email_alerts!
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(@saved_search, 
            SavedSearchItemComponent.new(
              saved_search: @saved_search,
              active: session[:current_saved_search_id] == @saved_search.id
            )),
          turbo_stream.prepend("flash", 
            partial: "shared/flash",
            locals: { 
              type: :notice, 
              message: @saved_search.email_alerts_enabled? ? 
                "Alertes activées" : 
                "Alertes désactivées" 
            })
        ]
      end
    end
  end
  
  def unsubscribe
    if valid_unsubscribe_token?
      case params[:action_type]
      when 'unsubscribe_all'
        current_user.saved_searches.update_all(email_alerts_enabled: false)
        message = "Vous avez été désinscrit de toutes les alertes"
      else
        saved_search = SavedSearch.find(params[:id])
        saved_search.update!(email_alerts_enabled: false)
        message = "Alertes désactivées pour cette recherche"
      end
      
      redirect_to root_path, notice: message
    else
      redirect_to root_path, alert: "Lien invalide ou expiré"
    end
  end
  
  private
  
  def saved_search_params
    params.require(:saved_search).permit(:name, :criteria, :email_alerts_enabled)
  end
end
```

### 4. 📨 Template Email Digest (app/views/digest_mailer/weekly_alert.html.erb)

```erb
<!DOCTYPE html>
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; line-height: 1.6; color: #111827; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background-color: #000; color: #fff; padding: 32px; text-align: center; border-radius: 8px 8px 0 0; }
    .header h1 { margin: 0; font-size: 24px; font-weight: 600; }
    .header p { margin: 8px 0 0 0; opacity: 0.9; }
    .content { background-color: #fff; padding: 32px; border: 1px solid #e5e7eb; border-top: none; }
    .search-section { margin-bottom: 40px; }
    .search-header { 
      background-color: #f9fafb; 
      padding: 16px; 
      border-radius: 8px; 
      margin-bottom: 20px;
      border-left: 4px solid #10b981;
    }
    .search-header h2 { margin: 0; font-size: 18px; color: #111827; }
    .search-header p { margin: 4px 0 0 0; color: #6b7280; font-size: 14px; }
    .candidate-card { 
      border: 1px solid #e5e7eb; 
      padding: 20px; 
      margin-bottom: 16px;
      border-radius: 8px;
      transition: all 0.2s;
    }
    .candidate-card:hover { box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); }
    .candidate-name { font-weight: 600; color: #111827; margin: 0; }
    .candidate-title { color: #6b7280; margin: 4px 0; }
    .candidate-meta { color: #9ca3af; font-size: 14px; margin: 4px 0; }
    .candidate-skills { margin: 8px 0; }
    .skill-tag { 
      display: inline-block; 
      background-color: #f3f4f6; 
      padding: 4px 8px; 
      border-radius: 4px; 
      font-size: 12px; 
      margin-right: 8px;
      margin-bottom: 4px;
    }
    .button-primary {
      display: inline-block;
      background-color: #000;
      color: #fff;
      padding: 10px 20px;
      text-decoration: none;
      border-radius: 6px;
      font-weight: 500;
      margin-top: 12px;
    }
    .button-secondary {
      display: inline-block;
      background-color: #fff;
      color: #000;
      padding: 10px 20px;
      text-decoration: none;
      border-radius: 6px;
      font-weight: 500;
      border: 1px solid #e5e7eb;
    }
    .footer { 
      background-color: #f9fafb; 
      padding: 24px;
      text-align: center;
      font-size: 14px;
      color: #6b7280;
      border-radius: 0 0 8px 8px;
    }
    .footer a { color: #6b7280; text-decoration: underline; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>📊 <%= @total_candidates %> nouveaux candidats cette semaine</h1>
      <p>Récapitulatif de vos <%= @alerts_data.size %> recherches actives</p>
    </div>
    
    <div class="content">
      <% @alerts_data.each do |data| %>
        <div class="search-section">
          <div class="search-header">
            <h2><%= data[:search].name %></h2>
            <p>
              <%= data[:candidates].size %> nouveaux candidats
              <% if data[:total_count] > data[:candidates].size %>
                sur <%= data[:total_count] %> au total
              <% end %>
            </p>
          </div>
          
          <% data[:candidates].first(3).each do |candidate| %>
            <div class="candidate-card">
              <h3 class="candidate-name"><%= candidate.full_name %></h3>
              <p class="candidate-title"><%= candidate.current_job_title %></p>
              <p class="candidate-meta">
                <%= candidate.years_of_experience %> ans d'expérience • <%= candidate.city %>
              </p>
              <div class="candidate-skills">
                <% candidate.skills.first(5).each do |skill| %>
                  <span class="skill-tag"><%= skill %></span>
                <% end %>
              </div>
              <a href="<%= customer_candidate_url(candidate) %>" class="button-primary">
                Voir le profil →
              </a>
            </div>
          <% end %>
          
          <% if data[:total_count] > 3 %>
            <div style="text-align: center; margin-top: 24px;">
              <a href="<%= load_customer_saved_search_url(data[:search]) %>" class="button-secondary">
                Voir les <%= data[:total_count] %> candidats →
              </a>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    
    <div class="footer">
      <p style="margin-bottom: 16px;">Vous recevez ce digest car vous avez activé les alertes sur vos recherches.</p>
      <p>
        <a href="<%= unsubscribe_customer_saved_searches_url(token: @unsubscribe_token, action_type: 'unsubscribe_all') %>">
          Se désinscrire de toutes les alertes
        </a>
        •
        <a href="<%= customer_saved_searches_url %>">
          Gérer mes recherches
        </a>
      </p>
    </div>
  </div>
</body>
</html>
```

## 🧪 Tests recommandés

### 1. 🔬 Tests unitaires

```ruby
# spec/models/saved_search_spec.rb
RSpec.describe SavedSearch do
  describe '#find_new_candidates' do
    it 'returns only candidates not previously viewed'
    it 'uses the saved criteria for searching'
    it 'returns empty collection when all candidates are viewed'
  end

  describe '#mark_candidates_as_viewed' do
    it 'creates viewed records for all candidates'
    it 'ignores already viewed candidates'
    it 'handles empty candidate lists'
  end
end

# spec/jobs/saved_search_alert_job_spec.rb
RSpec.describe SavedSearchAlertJob do
  it 'processes only saved searches with alerts enabled'
  it 'skips searches that received alert in last 24h'
  it 'sends email when new candidates are found'
  it 'marks candidates as viewed after sending'
  it 'handles errors gracefully'
  it 'limits candidates per alert to 20'
end

# spec/mailers/saved_search_mailer_spec.rb
RSpec.describe SavedSearchMailer do
  describe '#new_candidates_alert' do
    it 'sends to the correct email'
    it 'includes candidate information'
    it 'generates unsubscribe link'
    it 'uses correct subject with count'
  end
end
```

### 2. 🔗 Tests d'intégration

```ruby
# spec/system/saved_search_alerts_spec.rb
RSpec.describe 'Saved Search Alerts', type: :system do
  scenario 'Customer enables alerts when creating saved search'
  scenario 'Customer toggles alerts from saved search list'
  scenario 'Customer receives alert email with new candidates'
  scenario 'Customer unsubscribes via email link'
end
```

### 3. 🚀 Tests de performance

```ruby
# spec/performance/alert_job_spec.rb
RSpec.describe 'Alert Job Performance' do
  it 'handles 1000+ saved searches efficiently'
  it 'batches database queries appropriately'
  it 'completes within reasonable time'
end
```

## 💡 Recommandations et points d'attention

### ✅ Points positifs de l'implémentation

1. **Tracking précis** : Suivi candidat par candidat basé sur la date de publication
2. **Performant** : Utilisation d'index appropriés et requêtes optimisées
3. **Sécurisé** : Tokens pour les liens de désinscription
4. **Évolutif** : La constante ALERT_FREQUENCY permet de changer facilement la fréquence
5. **Robuste** : Évite les doublons grâce au tracking individuel des candidats vus

### 🔮 Évolutions V2 prévues

#### 1. **Fréquence personnalisable**

- Ajouter un champ `alert_frequency` (enum) sur SavedSearch
- Options : hebdomadaire, bi-hebdomadaire, mensuelle
- Job unique qui filtre selon la fréquence choisie

#### 2. **Volume de candidats**

- **Problème** : Limite fixe de 20 candidats peut frustrer certains utilisateurs
- **Solution** : Rendre configurable ou adapter selon la fréquence d'envoi

#### 3. **Personnalisation**

- **Problème** : Tous les utilisateurs reçoivent à 12h00
- **Solution** : Permettre de choisir l'heure de réception

#### 4. **Gestion de la délivrabilité**

- **Problème** : Pas de gestion des bounces/plaintes
- **Solution** : Intégrer un service comme SendGrid avec webhooks

#### 5. **Analytics**

- **Problème** : Pas de tracking des ouvertures/clics
- **Solution** : Ajouter des métriques pour optimiser les envois

### ⚠️ Risques à anticiper

1. **Scalabilité** : Avec beaucoup d'utilisateurs, le job peut prendre du temps

   - Solution : Paralléliser avec plusieurs workers
1. **Coûts email** : Volume important = coûts élevés

   - Solution : Limiter le nombre d'alertes par utilisateur
1. **Spam** : Risque d'être marqué comme spam

   - Solution : Double opt-in, headers appropriés, contenu de qualité
1. **RGPD** : Conformité sur le traitement des données

   - Solution : Logs d'audit, suppression automatique des anciennes données

### 🚀 Évolutions futures

1. **Alertes temps réel** : Via websockets pour les utilisateurs connectés
2. **Alertes SMS** : Pour les recherches urgentes
3. **Machine Learning** : Prédire les meilleurs moments d'envoi
4. **Digest intelligent** : Regrouper plusieurs recherches en un email
5. **Préférences avancées** : Filtres sur le type de candidats à inclure

## 📊 Métriques de succès

1. **Taux d'activation** : % d'utilisateurs activant les alertes
2. **Taux d'ouverture** : % d'emails ouverts
3. **Taux de clic** : % de clics sur les profils
4. **Taux de désabonnement** : % de désactivations
5. **Conversion** : % d'alertes menant à un contact

## ✨ Conclusion

Cette fonctionnalité apporte une vraie valeur ajoutée en permettant une veille passive pour les recruteurs. L'implémentation proposée est solide mais devra évoluer selon les retours utilisateurs, notamment sur la fréquence et la personnalisation des envois.