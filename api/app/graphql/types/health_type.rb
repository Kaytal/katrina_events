# frozen_string_literal: true

module Types
  class HealthType < Types::BaseObject
    description "Service health. Kept in the schema so the client can surface a real diagnosis; /up stays as a plain HTTP check for load balancers and container healthchecks."

    field :status, String, null: false
    field :service, String, null: false
    field :environment, String, null: false
    field :time, GraphQL::Types::ISO8601DateTime, null: false
    field :time_zone, String, null: false
    field :database, String, null: false,
          description: "\"connected\" when a SELECT 1 succeeds, \"unavailable\" otherwise."
  end
end
