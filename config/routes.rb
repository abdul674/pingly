Rails.application.routes.draw do
  root "dashboard#index"

  resources :messages, only: [ :index, :show ] do
    member do
      patch :mark_read
      patch :mark_done
      patch :snooze
      patch :unsnooze
    end
  end

  resources :categories do
    resources :category_rules, only: [ :create, :destroy ], shallow: true
  end

  resources :platform_connections, path: "connections" do
    member do
      patch :toggle
    end
    resources :sources, only: [ :index ] do
      member do
        patch :toggle_monitor
      end
    end
  end

  namespace :oauth do
    get "slack/callback", to: "slack#callback"
    get "slack/install", to: "slack#install"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
