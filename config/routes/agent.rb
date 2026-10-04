namespace :agent do
  root to: "candidates#index"

  resources :users, only: %i[index new create show edit update destroy] do
    member do
      post :enable
      post :disable
      post :invite
    end
  end

  resources :candidates, only: %i[index new create show edit update destroy] do
    collection do
      post :cancel
    end

    member do
      post :publish
      patch :archive
      patch :restore
    end

    resources :red_flags, only: %i[update], shallow: true
    resources :candidate_documents, only: %i[create]
  end

  resources :candidate_skills, only: [:destroy, :update, :edit], controller: "candidates/skills"
  resources :candidate_languages, only: [:destroy], controller: "candidates/languages"
  resources :candidate_employments, only: [:destroy], controller: "candidates/employments"
  resources :candidate_educations, only: [:destroy], controller: "candidates/educations"
  resources :candidate_trainings, only: [:destroy], controller: "candidates/trainings"
  resources :candidate_referrals, only: [:destroy], controller: "candidates/referrals"
  resources :candidate_mobilities, only: [:destroy], controller: "candidates/mobilities"
  resources :candidate_sectors, only: [:destroy], controller: "candidates/sectors"

  match "/candidates(/:candidate_id)/wizard/:id",
        to: "candidates/wizard#show",
        via: :get,
        as: :candidate_wizard
  match "/candidates(/:candidate_id)/wizard/:id",
        to: "candidates/wizard#update",
        via: [:patch, :put]

  match "/onboarding/:id",
        to: "onboarding#show",
        via: :get,
        as: :onboarding
  match "/onboarding/:id",
        to: "onboarding#update",
        via: [:patch, :put]

  resources :company_locations, only: [:destroy]
  resources :partner_companies, only: [:destroy]

  resources :projects, only: [:index, :show] do
    resources :candidates, only: [:show], controller: "projects/candidates" do
      member do
        get :push, action: :push_form
        post :push
        post :cancel
        get :questions
        post :questions, action: :submit_questions
      end
    end
  end
end
