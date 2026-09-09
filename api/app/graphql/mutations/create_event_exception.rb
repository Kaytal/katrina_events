# frozen_string_literal: true

module Mutations
  class CreateEventException < BaseMutation
    description "Cancel or move a single occurrence of a recurring event, without touching the rest."

    argument :event_id, ID, required: true
    argument :original_date, GraphQL::Types::ISO8601Date, required: true,
             description: "The local date the rule produced. This identifies the occurrence, and stays its identity even after a move."
    argument :action, String, required: true, description: "\"skip\" or \"move\"."
    argument :starts_at, GraphQL::Types::ISO8601DateTime, required: false,
             description: "Required for \"move\"."
    argument :ends_at, GraphQL::Types::ISO8601DateTime, required: false,
             description: "Required for \"move\"."

    field :exception, Types::EventExceptionType, null: true
    field :event, Types::EventAdminType, null: true
    field :errors, [ Types::FieldErrorType ], null: false

    def resolve(event_id:, original_date:, **attributes)
      require_admin!

      event = Event.find(event_id)

      unless produces_occurrence_on?(event, original_date)
        return {
          exception: nil, event: nil,
          errors: [ {
            field: "originalDate",
            messages: [ "is not a date this event occurs on" ]
          } ]
        }
      end

      exception = event.event_exceptions.new(original_date: original_date, **attributes)

      if exception.save
        # PHASE 8 — §2: cancelling an occurrence that already has approved
        # requests must offer her a "notify the N people approved for this"
        # action. Someone told yes who then finds a locked door is the worst
        # outcome this system can produce, and a silent close causes it.
        MaterializeTimeBlocksJob.perform_later
        { exception: exception, event: event.reload, errors: [] }
      else
        { exception: nil, event: nil, errors: field_errors(exception) }
      end
    end

    private

    # Without this she can create an exception for a Wednesday on a Tuesday
    # class: a row that matches nothing, silently does nothing, and looks like a
    # cancelled session in the editor.
    def produces_occurrence_on?(event, date)
      day_start = Time.zone.local(date.year, date.month, date.day)

      Events::Expansion.call(
        from: day_start,
        to: day_start + 1.day,
        events: Event.where(id: event.id),
        include_skipped: true
      ).any? { |occurrence| occurrence.original_date == date }
    end
  end
end
