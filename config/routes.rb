RedmineApp::Application.routes.draw do
  resources :projects do
    get 'agile_metrics', to: 'agile_metrics#index'
  end
end
