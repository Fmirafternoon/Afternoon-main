get "up" => "rails/health#show", as: :rails_health_check


devise_for :users, controllers: {
  registrations: "users/registrations"
}


namespace :users do
  resources :password_creations, only: %i[new create]
end

authenticate :user, lambda(&:super_admin?) do
  mount Sidekiq::Web => "/sidekiq"
end

# authenticated as customer or super_admin
authenticate :user, lambda { |u| u.customer? || u.super_admin? } do
  draw(:customer)
end

# authenticated as agent or super_admin
authenticate :user, lambda { |u| u.agent? || u.super_admin? } do
  draw(:agent)
end

root to: "pages#home"

resources :terms, only: %i[new create]

# Unsubscribe routes (no authentication required)
get "unsubscribe/saved_search/:id", to: "unsubscribe#saved_search", as: :unsubscribe_saved_search
get "unsubscribe/saved_searches", to: "unsubscribe#saved_search", as: :unsubscribe_all_saved_searches

# Public access with signed token (no authentication required)
get "p/:token", to: "public_access#show", as: :public_access

# Candidate expiration routes (no authentication required)
get "candidate_expirations/extend", to: "candidate_expirations#extend_publication", as: :extend_candidate_expiration
get "candidate_expirations/unpublish", to: "candidate_expirations#unpublish", as: :unpublish_candidate_expiration
