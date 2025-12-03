Rails.application.routes.draw do
  devise_for :users

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"

  resources :projects do
    resources :tasks
  end

  # Premium tabs
  get "workload", to: "workload#index", as: :workload_index
  get "schedules", to: "schedules#index", as: :schedules_index
  get "analytics", to: "analytics#index", as: :analytics_index
  get "simulation", to: "simulation#index", as: :simulation_index
  post "simulation", to: "simulation#create"
  get "activity", to: "activity#index", as: :activity_index
  get "team", to: "team#index", as: :team_index
  get "billing", to: "billing#index", as: :billing_index
  get "settings", to: "settings#index", as: :settings_index

  namespace :api do
    resources :tasks, only: [] do
      collection do
        post :score
        get :estimation_stats
        get :estimate
      end
    end
  end

  # Stripe webhooks
  post "stripe/webhooks", to: "stripe_webhooks#create"
  post "stripe/checkout", to: "stripe_checkout#create"
end
