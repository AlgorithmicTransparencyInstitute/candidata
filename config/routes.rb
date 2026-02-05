Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Admin namespace
  namespace :admin do
    root "dashboard#index"
    resources :parties
    resources :people do
      member do
        post :assign_researcher
        post :prepopulate_accounts
      end
      collection do
        get :bulk_assign
        post :create_bulk_assignments
      end
    end
    resources :districts
    resources :offices
    resources :ballots
    resources :contests
    resources :candidates
    resources :officeholders
    resources :assignments do
      member do
        patch :complete
      end
    end
    resources :users
  end

  # Researcher workspace
  namespace :researcher do
    root "dashboard#index"
    resources :assignments, only: [:index, :show] do
      member do
        patch :start
        patch :complete
      end
    end
    resources :accounts, only: [:show, :update] do
      member do
        patch :mark_entered
        patch :mark_not_found
      end
    end
  end

  # Verification workspace
  namespace :verification do
    root "dashboard#index"
    resources :assignments, only: [:index, :show] do
      member do
        patch :start
        patch :complete
      end
    end
    resources :accounts, only: [:show, :update] do
      member do
        patch :verify
        patch :reject
      end
    end
  end

  # Public browsing
  resources :people, only: [:index, :show]
  resources :offices, only: [:index, :show]
  resources :bodies, only: [:index, :show], param: :id
  resources :parties, only: [:index, :show]
  resources :states, only: [:index, :show], param: :id
  resources :districts, only: [:index, :show]

  # Public help section
  get "help", to: "help#index", as: :help
  get "help/data-sources", to: "help#data_sources", as: :help_data_sources
  get "help/data-model", to: "help#data_model", as: :help_data_model
  get "help/coverage", to: "help#coverage", as: :help_coverage

  # Defines the root path route ("/")
  root "home#index"
end
