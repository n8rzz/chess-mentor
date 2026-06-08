Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  authenticated :user do
    root "dashboard#show", as: :authenticated_root
  end

  resource :dashboard, only: :show, controller: "dashboard"

  namespace :settings do
    resource :providers, only: :show, controller: "providers" do
      delete :disconnect
    end
  end

  resources :import_batches, only: %i[index show new create]
  resources :games, only: %i[index show]

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  draw :sidekiq
  root "home#index"
end
