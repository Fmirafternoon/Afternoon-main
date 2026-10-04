namespace :customer do
  root to: "candidates#index"

  match "/onboarding/:id",
        to: "onboarding#show",
        via: :get,
        as: :onboarding
  match "/onboarding/:id",
        to: "onboarding#update",
        via: [:patch, :put]

  resources :company_locations, only: [:destroy]
  resources :company_positions, only: [:destroy]
  resources :company_sectors, only: [:destroy]

  resources :candidates, only: [:index, :show]
  resources :projects, only: [:index, :show, :destroy] do
    member do
      post :duplicate
      patch :save_draft
      post :rebroadcast
      post :archive
      post :unarchive
    end
    resources :wizard, only: [:show, :update, :create], controller: "projects/wizard"
    resources :candidates, only: [:show], controller: "projects/candidates" do
      member do
        get :interest_form
        post :interest
        get :reject_form
        post :reject
        get :pdf
      end
    end
  end

  resources :saved_searches, only: [:new, :create, :destroy] do
    member do
      get :load
      post :toggle_alerts
    end
  end

  resource :basket, only: [:show]

  post "basket/add_candidate/:candidate_id", to: "baskets#add_candidate", as: :basket_add_candidate
  delete "basket/remove_candidate/:basket_item_id/:candidate_id", to: "baskets#remove_candidate", as: :basket_remove_candidate
  get "basket/request_meeting/:id", to: "baskets#request_meeting", as: :basket_request_meeting
  post "basket/send_meeting_request/:id", to: "baskets#send_meeting_request", as: :basket_send_meeting_request
  get "basket/calendar/:id", to: "baskets#calendar", as: :basket_calendar

  # TODO: alerts
end
