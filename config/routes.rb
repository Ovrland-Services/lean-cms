Rails.application.routes.draw do
  namespace :lean_cms, path: 'lean-cms' do
    # Authentication
    get    'login',   to: 'sessions#new',     as: :new_session
    post   'login',   to: 'sessions#create',  as: :session
    delete 'login',   to: 'sessions#destroy'

    # Password reset (email-driven, sets a signed token on the user)
    get   'reset-password',              to: 'passwords#new',    as: :new_password
    post  'reset-password',              to: 'passwords#create', as: :passwords
    get   'reset-password/:token/edit',  to: 'passwords#edit',   as: :edit_password
    patch 'reset-password/:token',       to: 'passwords#update', as: :password
    put   'reset-password/:token',       to: 'passwords#update'

    # Magic-link password setup (new user invitations + admin-triggered resets)
    get   'setup-password/:token', to: 'password_setup#show',   as: :password_setup
    patch 'setup-password/:token', to: 'password_setup#update'

    root to: 'dashboard#index'

    # User Management
    resources :users, except: [:destroy] do
      member do
        patch :deactivate
        patch :activate
        post :send_password_reset
      end
    end

    resources :posts

    # Page Contents - section-based editing
    get 'page-contents', to: 'page_contents#index', as: :page_contents

    # Page Contents - inline field editing (MUST come before section routes)
    get 'page-contents/field/:id/edit', to: 'page_contents#edit_field', as: :edit_page_content_field
    patch 'page-contents/field/:id', to: 'page_contents#update_field', as: :update_page_content_field
    get  'page-contents/field/:id/undo/preview', to: 'page_contents#preview_undo_field', as: :preview_undo_page_content_field
    post 'page-contents/field/:id/undo', to: 'page_contents#undo_field', as: :undo_page_content_field

    # Page Contents - section routes
    get 'page-contents/:page/:section/edit', to: 'page_contents#edit', as: :edit_page_content
    patch 'page-contents/:page/:section', to: 'page_contents#update', as: :page_content

    resources :form_submissions, only: [:index, :show, :destroy] do
      member do
        patch :mark_as_read
        patch :mark_as_replied
      end
    end

    # Activity Log
    get 'activity', to: 'activity#index', as: :activity

    # Settings
    get 'settings', to: 'settings#edit', as: :settings
    patch 'settings', to: 'settings#update'
    patch 'settings/update_override', to: 'settings#update_override'
    post 'settings/lock', to: 'settings#lock', as: :lock_content
    post 'settings/unlock', to: 'settings#unlock', as: :unlock_content

    # Notification Settings
    resource :notification_settings, only: [:edit, :update] do
      post :test_email, on: :collection
      post :test_sms, on: :collection
    end

    # In-app Notifications
    resources :notifications, only: [:index, :show] do
      member do
        patch :mark_as_read
      end
      collection do
        patch :mark_all_as_read
      end
    end
  end
end
