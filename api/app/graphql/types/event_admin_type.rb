# frozen_string_literal: true

module Types
  # The stored event, as the editor sees it: the recurrence rule itself, the
  # exceptions, and the occurrences the rule produces. The public schema never
  # exposes a rule — EventOccurrence is the public shape.
  class EventAdminType < Types::BaseObject
    graphql_name "AdminEvent"
    description "A stored event, including its recurrence rule and per-occurrence exceptions."

    field :id, ID, null: false
    field :title, String, null: false
    field :description, String, null: true
    field :starts_at, GraphQL::Types::ISO8601DateTime, null: false
    field :ends_at, GraphQL::Types::ISO8601DateTime, null: false
    field :all_day, Boolean, null: false
    field :recurrence_rule, String, null: true
    field :recurrence_until, GraphQL::Types::ISO8601DateTime, null: true
    field :status, String, null: false
    field :bookable, Boolean, null: false
    field :capacity, Integer, null: true
    field :price_note, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :event_type, Types::EventTypeType, null: false
    field :venue, Types::VenueType, null: true
    field :recurring, Boolean, null: false

    field :exceptions, [ Types::EventExceptionType ], null: false,
          description: "Cancelled and moved occurrences, oldest first."

    field :occurrences, [ Types::EventOccurrenceType ], null: false,
          description: "Occurrences this event produces in a window, cancelled ones included and flagged, so they can be restored." do
      argument :from, GraphQL::Types::ISO8601DateTime, required: true
      argument :to, GraphQL::Types::ISO8601DateTime, required: true
    end

    def recurring = object.recurring?

    def exceptions
      object.event_exceptions.order(:original_date)
    end

    def occurrences(from:, to:)
      Events::Expansion.call(
        from: from.in_time_zone,
        to: to.in_time_zone,
        events: Event.where(id: object.id),
        include_skipped: true
      )
    rescue Events::Expansion::RangeTooLarge => e
      raise GraphQL::ExecutionError.new(e.message, extensions: { "code" => "RANGE_TOO_LARGE" })
    rescue ArgumentError => e
      raise GraphQL::ExecutionError.new(e.message, extensions: { "code" => "BAD_REQUEST" })
    end
  end
end
