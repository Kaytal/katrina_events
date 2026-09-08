Rails.application.routes.draw do
  # GraphQL is the API. Queries are sent as GET so they stay HTTP-cacheable
  # (ETag + conditional GET); mutations are POST.
  get "/graphql", to: "graphql#execute"
  post "/graphql", to: "graphql#execute"

  # The REST edge, deliberately small: responses that are not JSON for our own
  # client. Calendar feeds (Phase 9) return text/calendar to Google Calendar and
  # Apple Calendar, and /uploads is served by nginx, not Rails.
  #
  # Plain-HTTP liveness for load balancers and container healthchecks: 200 if
  # the app booted. The `health` GraphQL query is the richer one.
  get "up" => "rails/health#show", as: :rails_health_check
end
