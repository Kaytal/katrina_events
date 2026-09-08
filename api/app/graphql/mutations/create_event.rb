# frozen_string_literal: true

module Mutations
  class CreateEvent < BaseMutation
    description "Add an event to the calendar. `bookable: false` is an announcement — shown with no request button."

    argument :event_type_id, ID, required: true
    argument :venue_id, ID, required: false
    argument :title, String, required: true
    argument :description, String, required: false
    argument :starts_at, GraphQL::Types::ISO8601DateTime, required: true
    argument :ends_at, GraphQL::Types::ISO8601DateTime, required: true
    argument :all_day, Boolean, required: false
    argument :recurrence_rule, String, required: false,
             description: "RFC-5545 RRULE, e.g. FREQ=WEEKLY;BYDAY=TU. Sub-daily rules are rejected."
    argument :recurrence_until, GraphQL::Types::ISO8601DateTime, required: false
    argument :bookable, Boolean, required: false
    argument :capacity, Integer, required: false
    argument :price_note, String, required: false

    field :event, Types::EventAdminType, null: true
    field :errors, [ Types::FieldErrorType ], null: false

    def resolve(**attributes)
      require_admin!

      event = Event.new(attributes)

      if event.save
        { event: event, errors: [] }
      else
        { event: nil, errors: field_errors(event) }
      end
    end
  end
end
