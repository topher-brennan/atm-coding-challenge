Rails.application.routes.draw do
  resources :ip_addresses, :id => /[0-9\.]+/, only: [:index, :show]
end
