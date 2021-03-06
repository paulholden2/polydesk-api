Rails.application.routes.draw do
  mount_devise_token_auth_for 'User', at: 'auth', controllers: {
    sessions:  'overrides/sessions',
    confirmations: 'overrides/confirmations'
  }, skip: [:confirmations]

  devise_scope :user do
    get '/confirmations/new', to: 'overrides/confirmations#new'
    get '/confirmations/:confirmation_token', to: 'overrides/confirmations#show', as: :user_confirmation
    post '/confirmations/:confirmation_token', to: 'overrides/confirmations#confirm', as: :user_confirmation_confirm
  end

  resources :accounts
  resources :users

  get '/', to: 'application#show'

  scope '/:identifier' do
    resources :documents
    resources :folders
    resources :reports
    resources :options
    resources :account_users, path: 'users'
    resources :blueprints
    resources :groups

    scope 'prefabs/:namespace' do
      get '/', to: 'prefabs#index'
      get '/:id', to: 'prefabs#show'
      post '/', to: 'prefabs#create'
      delete '/', to: 'prefabs#destroy'
      patch ':id', to: 'prefabs#update'
    end

    post '/documents/upload', to: 'documents#upload_new'
    post '/folders/:id/upload', to: 'folders#upload_document'
    patch '/documents/:id/upload', to: 'documents#upload_version'

    post '/users', to: 'users#create_auth'
    get '/users/:id/permissions', to: 'permissions#index'
    post '/users/:id/permissions', to: 'permissions#create'
    delete '/users/:id/permissions', to: 'permissions#destroy'

    get '/documents/:id/folder', to: 'documents#folder', as: :document_folder
    get '/documents/:id/download', to: 'documents#download', as: :document_download
    get '/documents/:id/versions/:version/download', to: 'documents#download_version', as: :document_download_version
    put '/documents/:id/restore', to: 'documents#restore', as: :document_restore

    get '/folders/:id/folder', to: 'folders#folder', as: :folder_folder
    get '/folders/:id/folders', to: 'folders#folders', as: :folder_folders
    post '/folders/:id/folders', to: 'folders#add_folder'
    get '/folders/:id/documents', to: 'folders#documents', as: :folder_documents
    post '/folders/:id/documents', to: 'folders#add_document'
    put '/folders/:id/restore', to: 'folders#restore', as: :folder_restore
    get '/folders/:id/content', to: 'folders#content', as: :folder_content
    get '/content', to: 'folders#content', as: :content

    get '/:model/:id/versions', to: 'versions#index', as: :versions
    get '/:model/:id/versions/:version', to: 'versions#show', as: :version
    put '/:model/:id/versions/:version', to: 'versions#restore', as: :version_restore

    get '/forms/:id/form-submissions', to: 'forms#form_submissions', as: :form_form_submissions
  end
end
