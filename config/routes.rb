Rails.application.routes.draw do
  devise_for :users
  resources :users
  resources :clients
  resources :carriers
  resources :master_bls do
    member do
      get :template
      post :import
    end
  end
  resources :containers do
    member { patch :transition }
  end
  get "home/index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # Los administradores aterrizan en MBL; el resto en la página de inicio.
  authenticated :user, ->(user) { user.admin? } do
    root "master_bls#index", as: :admin_root
  end
  root "home#index"

  match "/:code", to: "errors#show", via: :all, constraints: { code: /400|404|422|500/ }, as: :error
end
