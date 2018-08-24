Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  namespace :api, {format: 'json'} do
    namespace :v1 do
      resources :hl7parses
    end
  end

  resources :hl7parses
  root to: 'hl7parses#create'
end
