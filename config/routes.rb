Rails.application.routes.draw do
  devise_for :users
  resources :users
  resources :clients do
    member do
      post "users", action: :link_user, as: :link_user
      delete "users/:user_id", action: :unlink_user, as: :unlink_user
    end
  end
  resources :carriers do
    member do
      post "users", action: :link_user, as: :link_user
      delete "users/:user_id", action: :unlink_user, as: :unlink_user
    end
  end
  resources :master_bls do
    member do
      get :template
      post :import
      patch :upload_document
      get :document
      delete :remove_document
    end
  end
  resources :cargo_manifests do
    member do
      get :template
      post :import
      patch :confirm
      patch :reopen
    end
    resources :cargo_items, only: %i[show create update destroy]
  end
  resources :cargo_packagings, except: :show
  resources :containers do
    member do
      patch :transition
      get :photos
      post :upload_photos
      delete :remove_photos
      post :zip_photos
      delete "photos/:photo_id", action: :remove_photo, as: :remove_photo
    end
  end
  get "yard", to: "yard#index", as: :yard
  resources :yard_slots, only: [] do
    patch :toggle, on: :member
  end
  get "warehouse", to: "warehouse#index", as: :warehouse
  get "warehouse/labels", to: "warehouse#labels", as: :warehouse_labels
  resources :warehouse_slots, only: :show do
    patch :store, on: :member
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
  authenticated :user, ->(user) { user.cliente? && user.client_id.present? } do
    root "master_bls#index", as: :client_root
  end
  root "home#index"

  match "/:code", to: "errors#show", via: :all, constraints: { code: /400|404|422|500/ }, as: :error
end
