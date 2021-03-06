Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  # namespace :api, {format: 'json'} do
  #   namespace :v1 do
  #     resources :hl7parses
  #   end
  # end

  # resources :hl7parses
  # root to: 'hl7parses#create'

  namespace :api, {format: 'xml'} do
    namespace :hl7cda do
      resources :prescription
    end
  end

  namespace :api, {format: 'json'} do
    namespace :hl7 do
      resources :parse
    end
  end

  resources :parse
  root to: 'parse#create'
end
