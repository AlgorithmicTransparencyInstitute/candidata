Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    invitations: 'users/invitations',
    registrations: 'users/registrations'
  }

  # Custom user routes
  devise_scope :user do
    delete 'users/avatar', to: 'users/registrations#destroy_avatar', as: :destroy_user_avatar
  end

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
    get 'guide', to: 'guide#show', as: :guide
    resources :visits, only: [:index]
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
    resources :bodies
    resources :offices
    resources :elections
    resources :ballots
    resources :contests
    resources :candidates
    resources :officeholders
    resources :assignments do
      member do
        patch :complete
        patch :mark_incomplete
      end
    end
    resources :social_media_accounts
    resources :users do
      collection do
        get :export_invitations
        post :stop_impersonating
      end
      member do
        post :resend_invitation
        post :send_reset_password
        post :impersonate
        post :generate_invitation_link
        post :send_assignment_reminder
      end
    end
    resources :researchers, only: [:index]
    resources :invitations, only: [:new, :create]
  end

  # Researcher workspace
  namespace :researcher do
    root "dashboard#index"
    get 'guide', to: 'guide#show', as: :guide
    get "queue", to: "queue#index"
    resources :assignments, only: [:index, :show] do
      member do
        patch :start
        patch :complete
        patch :reopen
      end
    end
    resources :accounts, only: [:show, :update] do
      member do
        patch :mark_entered
        patch :mark_not_found
        patch :reset_status
        patch :toggle_researcher_verified
        patch :update_notes
      end
    end
  end

  # Verification workspace
  namespace :verification do
    root "dashboard#index"
    get "queue", to: "queue#index"
    resources :assignments, only: [:index, :show] do
      member do
        patch :start
        patch :complete
        patch :reopen
      end
    end
    resources :accounts, only: [:show, :update, :edit] do
      member do
        patch :mark_entered
        patch :mark_not_found
        patch :reset_status
        patch :verify
        patch :unverify
        patch :verify_with_changes
        patch :reject
      end
    end
  end

  # User profile
  resource :profile, only: [:show, :edit, :update]

  # Public browsing
  resources :people, only: [:index, :show]
  resources :offices, only: [:index, :show]
  resources :bodies, only: [:index, :show], param: :id
  resources :parties, only: [:index, :show]
  resources :states, only: [:index, :show], param: :id
  resources :districts, only: [:index, :show]
  resources :elections, only: [:index, :show]
  resources :ballots, only: [:index, :show]
  resources :contests, only: [:index, :show]

  # Public help section
  get "help", to: "help#index", as: :help
  get "help/data-sources", to: "help#data_sources", as: :help_data_sources
  get "help/data-model", to: "help#data_model", as: :help_data_model
  get "help/coverage", to: "help#coverage", as: :help_coverage
  get "help/researcher-guide", to: "help#researcher_guide", as: :help_researcher_guide

  # About page
  get "about", to: "about#index", as: :about

  # Defines the root path route ("/")
  root "home#index"
end
