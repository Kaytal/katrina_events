Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get "health" => "health#show"
    end
  end

  # Boot-only check for load balancers: 200 if the app loaded, 500 otherwise.
  # /api/v1/health is the richer one, and the one the frontend calls.
  get "up" => "rails/health#show", as: :rails_health_check
end
