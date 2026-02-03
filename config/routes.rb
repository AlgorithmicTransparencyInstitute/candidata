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
    resources :people
    resources :districts
    resources :offices
    resources :ballots
    resources :contests
    resources :candidates
    resources :officeholders
  end

  # Public help section
  get "help", to: "help#index", as: :help
  get "help/data-sources", to: "help#data_sources", as: :help_data_sources
  get "help/data-model", to: "help#data_model", as: :help_data_model
  get "help/coverage", to: "help#coverage", as: :help_coverage

  # Defines the root path route ("/")
  root "home#index"
end
