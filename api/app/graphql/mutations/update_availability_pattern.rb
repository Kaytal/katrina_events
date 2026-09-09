# frozen_string_literal: true

module Mutations
  class UpdateAvailabilityPattern < BaseMutation
    description "Edit a weekly template. Slots are regenerated; slots with requests are never deleted or moved (see the protection rule)."

    argument :id, ID, required: true
    argument :event_type_id, ID, required: false
    argument :venue_id, ID, required: false
    argument :weekday, Integer, required: false
    argument :start_time, String, required: false
    argument :end_time, String, required: false
    argument :slot_minutes, Integer, required: false
    argument :capacity, Integer, required: false
    argument :price_note, String, required: false
    argument :effective_from, GraphQL::Types::ISO8601Date, required: false
    argument :effective_to, GraphQL::Types::ISO8601Date, required: false
    argument :active, Boolean, required: false
    argument :clear_effective_to, Boolean, required: false,
             description: "Remove the end date, making the pattern open-ended."
    argument :clear_venue, Boolean, required: false

    field :availability_pattern, Types::AvailabilityPatternType, null: true
    field :errors, [ Types::FieldErrorType ], null: false

    def resolve(id:, clear_effective_to: false, clear_venue: false, **attributes)
      require_admin!

      pattern = AvailabilityPattern.find(id)
      pattern.assign_attributes(attributes)
      pattern.effective_to = nil if clear_effective_to
      pattern.venue = nil if clear_venue

      if pattern.save
        MaterializeTimeBlocksJob.perform_later
        { availability_pattern: pattern, errors: [] }
      else
        { availability_pattern: nil, errors: field_errors(pattern) }
      end
    end
  end
end
