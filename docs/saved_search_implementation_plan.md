# Plan d'implémentation - Recherches sauvegardées

## Vue d'ensemble
Ajouter une fonctionnalité permettant aux utilisateurs (customers) de sauvegarder leurs critères de recherche de candidats pour les réutiliser ultérieurement.

## Architecture proposée

### 1. Modèle de données

#### Nouveau modèle `SavedSearch`
```ruby
# Attributs :
# - name: string (obligatoire) - nom de la recherche
# - criteria: jsonb - stockage des paramètres du formulaire SearchForm
# - customer_id: bigint (obligatoire) - relation avec le customer
# - last_used_at: datetime - tracking de l'utilisation
# - created_at, updated_at: timestamps
```

Relations :
- `belongs_to :customer`
- Customer : `has_many :saved_searches`

### 2. Structure des données sauvegardées

Le champ `criteria` stockera tous les paramètres du `Customer::SearchForm` :
```json
{
  "query": "développeur web",
  "lat": 48.8566,
  "lng": 2.3522,
  "autocomplete_address": "Paris, France",
  "zip_code": "75001",
  "city": "Paris",
  "sector_ids": [1, 3, 5],
  "skills": ["ruby", "rails", "javascript"]
}
```

### 3. Controllers

#### `Customer::SavedSearchesController`
Actions nécessaires :
- `new` : Afficher la modale de sauvegarde (avec `render layout: false`)
- `create` : Créer une nouvelle recherche sauvegardée
- `destroy` : Supprimer une recherche sauvegardée
- `load` : Charger les critères et mettre à jour le formulaire via Turbo Streams

#### Modifications de `Customer::CandidatesController`
- Charger les recherches sauvegardées du customer dans `index`
- Ajouter la logique pour détecter si une recherche sauvegardée est active

### 4. Interface utilisateur

#### Sur la page de recherche (`customer/candidates/index`)

**Zone des recherches sauvegardées** (au-dessus des filtres) :
- Liste des recherches sauvegardées sous forme de boutons/liens
- Indicateur visuel de la recherche active
- Bouton de suppression (icône poubelle) pour chaque recherche avec confirmation
- Style : cartes compactes

**Bouton "Sauvegarder la recherche"** :
- Positionné après les critères courants
- Ouvre une modale pour nommer la recherche et affiche les critères qui seront enregistrés.
- Caché si aucun critère n'est sélectionné

#### Modale de sauvegarde
- Champ de saisie pour le nom de la recherche
- Affichage récapitulatif des critères qui seront sauvegardés
- Boutons : "Sauvegarder" et "Annuler"

### 5. Flux utilisateur

1. **Sauvegarder une recherche** :
   - L'utilisateur définit ses critères de recherche
   - Clique sur "Sauvegarder la recherche"
   - Nomme sa recherche dans la modale
   - La recherche est sauvegardée et apparaît dans la liste

2. **Charger une recherche sauvegardée** :
   - L'utilisateur clique sur une recherche sauvegardée
   - Les critères sont chargés et la recherche s'exécute
   - L'URL est mise à jour avec les paramètres
   - La recherche sauvegardée est visuellement marquée comme active

3. **Modifier une recherche chargée** :
   - Les critères peuvent être modifiés après chargement
   - Ces modifications ne sont pas automatiquement sauvegardées
   - L'utilisateur doit créer une nouvelle recherche sauvegardée s'il veut conserver les modifications

### 6. Détails techniques

#### Routes
```ruby
namespace :customer do
  resources :saved_searches, only: [:new, :create, :destroy] do
    member do
      get :load
    end
  end
end
```

#### Sécurité
- Utiliser les strong parameters pour les critères
- Valider que le customer ne peut accéder qu'à ses propres recherches
- Limiter le nombre de recherches sauvegardées par customer (ex: 10)

#### JavaScript (Stimulus)
- Controller pour gérer l'ouverture/fermeture de la modale
- Soumission turbo pour créer/supprimer sans recharger la page
- Mise à jour dynamique de la liste des recherches sauvegardées

### 7. Étapes d'implémentation

1. **Phase 1 - Backend** :
   - Créer la migration pour la table `saved_searches`
   - Créer le modèle `SavedSearch` avec validations
   - Implémenter le controller `SavedSearchesController`
   - Ajouter les routes

2. **Phase 2 - Frontend de base** :
   - Modifier la vue `candidates/index` pour afficher les recherches sauvegardées
   - Ajouter le bouton "Sauvegarder la recherche"
   - Implémenter la modale de sauvegarde

3. **Phase 3 - Interactions** :
   - Implémenter le chargement des recherches sauvegardées
   - Ajouter les indicateurs visuels pour la recherche active
   - Gérer la suppression des recherches

4. **Phase 4 - Polish** :
   - Ajouter des animations/transitions
   - Messages de confirmation/succès (avec le système de notification/alert de rails)
   - Gestion des erreurs
   - Tests

### 8. Considérations futures

- Notifications pour nouvelles correspondances sur une recherche sauvegardée

## TODO List détaillée

### Phase 1 - Backend
- [ ] Créer la migration pour la table `saved_searches`
  - `name` : string, NOT NULL
  - `criteria` : jsonb, NOT NULL
  - `customer_id` : bigint, NOT NULL, foreign key
  - `last_used_at` : datetime
  - Index sur `customer_id`
- [ ] Créer le modèle `SavedSearch`
  - Validations (presence de name et criteria)
  - Association avec Customer
  - Scope pour ordonner par date d'utilisation
- [ ] Créer le controller `Customer::SavedSearchesController`
  - Action `new` pour afficher la modale (render layout: false)
  - Action `create` avec Turbo Streams pour mise à jour dynamique
  - Action `destroy` avec Turbo Streams
  - Action `load` avec Turbo Streams pour mettre à jour le formulaire
- [ ] Ajouter les routes dans le namespace customer

### Phase 2 - Interface utilisateur
- [ ] Ajouter le bouton "Save search" dans la vue
  - Positionner après les tags de filtres actifs
  - Style : bouton rouge arrondi comme sur la maquette
  - Désactivé si aucun filtre actif
- [ ] Créer la modale de sauvegarde
  - Titre : "Sauvegarder cette recherche"
  - Champ de saisie pour le nom (obligatoire)
  - Récapitulatif des filtres actifs :
    - Query (si présent)
    - Localisation (ville, code postal)
    - Secteurs sélectionnés
    - Compétences sélectionnées
  - Boutons : "Sauvegarder" et "Annuler"
- [ ] Ajouter le bloc "Recherches sauvegardées" dans la sidebar
  - Positionner au-dessus de la section "Filtres"
  - Style : encadré rouge comme sur la maquette
  - Afficher le nom en gras
  - Afficher les critères en dessous (format condensé)
  - Icône chevron à droite pour accéder

### Phase 3 - Interactions JavaScript (Stimulus)
- [ ] Controller Stimulus pour la modale
  - Ouverture/fermeture
  - Soumission turbo du formulaire
  - Mise à jour de la liste sans rechargement
- [ ] Clic sur une recherche sauvegardée
  - Appel turbo pour charger les critères
  - Mise à jour des filtres dans le formulaire
  - Soumission automatique pour lancer la recherche
  - Indication visuelle de la recherche active
- [ ] Suppression d'une recherche
  - Icône poubelle au survol
  - Confirmation : "Êtes-vous sûr de vouloir supprimer cette recherche ?"
  - Suppression turbo avec mise à jour de la liste

### Phase 4 - Détails UX
- [ ] Limiter à 10 recherches sauvegardées par customer (mettre dans une constante)
- [ ] Message si limite atteinte
- [ ] Animation lors de l'ajout/suppression
- [ ] Toast de confirmation après sauvegarde
- [ ] Gestion des erreurs (nom déjà utilisé pour un user, etc.)
- [ ] Mise à jour de `last_used_at` lors du chargement


### Notes d'implémentation

#### Système de modales Turbo existant

Voici un système de modale à implémenter :

**1. Controller Stimulus (`turbo_modal_controller.js`)** :
- Gère l'ouverture/fermeture automatique
- Observe les changements de contenu dans le turbo-frame
- Support de la touche Escape et clic sur le backdrop
- Fermeture automatique sur soumission réussie

**2. Component ViewComponent (`ModalComponent`)** :
- Wrapper réutilisable pour toutes les modales
- Inclut le turbo-frame "modal"
- Gère les animations et le z-index

**3. Utilisation** :
```erb
<%= turbo_frame_tag :modal do %>
  <div class="bg-white max-w-[600px] p-8">
    <h1 class="modal-title">Titre de la modale</h1>

    <%= simple_form_for @form,
        url: chemin_url,
        html: { data: { turbo_frame: :modal, target: "_top" } } do |f| %>
      <!-- Contenu du formulaire -->
      <div class="flex justify-end gap-2">
        <%= f.submit 'Confirmer', class: 'button-primary' %>
        <%= link_to 'Annuler', '#', data: { action: 'turbo-modal#close' }, class: 'button-secondary' %>
      </div>
    <% end %>
  </div>
<% end %>
```

**4. Déclenchement** :
Pour ouvrir la modale, il suffit de créer un lien ou bouton qui cible le turbo-frame "modal" :
```erb
<%= link_to "Ouvrir modale", path_to_modal, data: { turbo_frame: "modal" } %>
```

#### Structure de la modale pour sauvegarder une recherche

Avec le système Turbo existant, la modale sera implémentée ainsi :

**Controller action pour afficher la modale** :
```ruby
# app/controllers/customer/saved_searches_controller.rb
def new
  @saved_search = current_customer.saved_searches.build
  @search_form = Customer::SearchForm.new(search_params)
  render layout: false # Important pour Turbo
end
```

**Vue de la modale** (`app/views/customer/saved_searches/new.html.erb`) :
```erb
<%= turbo_frame_tag :modal do %>
  <div class="bg-white max-w-[600px] p-8">
    <h1 class="modal-title">Sauvegarder cette recherche</h1>

    <%= simple_form_for @saved_search,
        url: customer_saved_searches_path,
        html: { data: { turbo_frame: :modal, target: "_top" } } do |f| %>

      <%= f.input :name, label: "Nom de la recherche", placeholder: "Ex: Géomètres Bordeaux" %>

      <div class="criteria-summary mt-4 p-4 bg-gray-50 rounded">
        <h4 class="font-semibold mb-2">Critères sauvegardés :</h4>
        <ul class="space-y-1 text-sm">
          <% if @search_form.query.present? %>
            <li>• Recherche : <%= @search_form.query %></li>
          <% end %>
          <% if @search_form.city.present? %>
            <li>• Ville : <%= @search_form.city %></li>
          <% end %>
          <% if @search_form.sector_ids.any? %>
            <li>• Secteurs : <%= Sector.where(id: @search_form.sector_ids).pluck(:name).join(", ") %></li>
          <% end %>
          <% if @search_form.skills.any? %>
            <li>• Compétences : <%= @search_form.skills.join(", ") %></li>
          <% end %>
        </ul>
      </div>

      <%= f.hidden_field :criteria, value: @search_form.attributes.to_json %>

      <div class="flex justify-end gap-2 mt-6">
        <%= f.submit 'Sauvegarder', class: 'button-primary' %>
        <%= link_to 'Annuler', '#', data: { action: 'turbo-modal#close' }, class: 'button-secondary' %>
      </div>
    <% end %>
  </div>
<% end %>
```

**Déclenchement depuis la page de recherche** :
```erb
<%= link_to "Save search", new_customer_saved_search_path(search_params),
    data: { turbo_frame: "modal" },
    class: "button-secondary-red" %>
```

#### Format d'affichage dans la sidebar
```erb
<div class="saved-searches">
  <h3>Recherches sauvegardées</h3>
  <div class="saved-search-item">
    <strong>Géomètre Bordeaux</strong>
    <span class="criteria">Géomètre, Bordeaux, BTP</span>
    <i class="chevron-right"></i>
  </div>
</div>
```

## Améliorations possibles du système de modales

Après analyse du système de modales existant, voici quelques améliorations potentielles :

### 1. **Simplification avec Turbo 8**
Le code actuel est très bien, mais pourrait être légèrement simplifié avec les nouvelles fonctionnalités de Turbo 8 :
- Utiliser `turbo_stream` pour la fermeture automatique après soumission
- Exploiter les `turbo-frame[busy]` attributes pour les états de chargement

### 2. **Amélioration de l'accessibilité**
```javascript
// Ajouter dans turbo_modal_controller.js
connect() {
  // ... code existant ...
  this.trapFocus() // Piéger le focus dans la modale
  this.setAriaAttributes()
}

setAriaAttributes() {
  this.element.setAttribute('role', 'dialog')
  this.element.setAttribute('aria-modal', 'true')
  // Focus sur le premier élément interactif
  const firstInput = this.contentTarget.querySelector('input, button, select, textarea')
  firstInput?.focus()
}
```

### 3. **Gestion des tailles de modales**
Ajouter des classes CSS prédéfinies :
```erb
# modal_component.rb
class ModalComponent < ViewComponent::Base
  def initialize(size: :medium)
    @size = size
  end

  private

  def size_classes
    {
      small: "max-w-[400px]",
      medium: "max-w-[600px]",
      large: "max-w-[800px]",
      full: "max-w-[95vw]"
    }[@size]
  end
end
```

### 4. **Animations Tailwind améliorées**
Le code actuel a des commentaires sur les animations mais ne les implémente pas. On pourrait :
```javascript
// Dans turbo_modal_controller.js
show() {
  this.element.classList.remove('hidden')
  // Forcer le reflow pour l'animation
  this.element.offsetHeight
  this.backdropTarget.classList.add('opacity-100')
  this.contentTarget.classList.add('opacity-100', 'scale-100')
}
```

### 5. **Hook de confirmation avant fermeture**
Pour les formulaires avec des modifications non sauvegardées :
```javascript
// Ajouter une option pour demander confirmation
static values = { confirmClose: Boolean }

hide() {
  if (this.confirmCloseValue && this.hasUnsavedChanges()) {
    if (!confirm("Vous avez des modifications non sauvegardées. Voulez-vous vraiment fermer ?")) {
      return
    }
  }
  // ... reste du code
}
```