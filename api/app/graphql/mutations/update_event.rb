# frozen_string_literal: true

module Mutations
  class UpdateEvent < BaseMutation
    description "Edit a stored event. Changes to a recurring event reach every occurrence that has no exception of its own."

    argument :id, ID, required: true
    argument :event_type_id, ID, required: false
    argument :venue_id, ID, required: false
    argument :title, String, required: false
    argument :description, String, required: false
    argument :starts_at, GraphQL::Types::ISO8601DateTime, required: false
    argument :ends_at, GraphQL::Types::ISO8601DateTime, required: false
    argument :all_day, Boolean, required: false
    argument :recurrence_rule, String, required: false
    argument :recurrence_until, GraphQL::Types::ISO8601DateTime, required: false
    argument :status, String, required: false, description: "\"scheduled\" or \"cancelled\"."
    argument :bookable, Boolean, required: false
    argument :capacity, Integer, required: false
    argument :price_note, String, required: false

    # Clearing a value needs to be distinguishable from not mentioning it, and a
    # GraphQL null argument is indistinguishable from an absent one here.
    argument :clear_venue, Boolean, required: false,
             description: "Detach the venue. Sending venueId: null cannot express this."
    argument :clear_recurrence, Boolean, required: false,
             description: "Turn a repeating event into a one-off, dropping the rule and its end date."

    field :event, Types::EventAdminType, null: true
    field :errors, [ Types::FieldErrorType ], null: false

    def resolve(id:, clear_venue: false, clear_recurrence: false, **attributes)
      require_admin!

      event = Event.find(id)

      event.assign_attributes(attributes)
      event.venue = nil if clear_venue
      if clear_recurrence
        event.recurrence_rule = nil
        event.recurrence_until = nil
      end

      # PHASE 8 — §2 requires that flipping `bookable` true → false on an event
      # with approved requests *refuses*, not warns: it is a one-checkbox way to
      # orphan real bookings. The check belongs exactly here, and cannot be
      # written yet because booking_requests does not exist. It is recorded in
      # the plan's Phase 8 line so it is a listed deliverable rather than a
      # comment someone has to find.

      if event.save
        MaterializeTimeBlocksJob.perform_later
        { event: event, errors: [] }
      else
        { event: nil, errors: field_errors(event) }
      end
    end
  end
end
