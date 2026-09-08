# frozen_string_literal: true

module Types
  class EventExceptionType < Types::BaseObject
    graphql_name "EventException"
    description "One deviation from a recurring event's rule: a cancelled or moved occurrence."

    field :id, ID, null: false
    field :original_date, GraphQL::Types::ISO8601Date, null: false,
          description: "The local date the rule produced. This identifies the occurrence."
    field :action, String, null: false, description: "\"skip\" or \"move\"."
    field :starts_at, GraphQL::Types::ISO8601DateTime, null: true
    field :ends_at, GraphQL::Types::ISO8601DateTime, null: true
  end
end
