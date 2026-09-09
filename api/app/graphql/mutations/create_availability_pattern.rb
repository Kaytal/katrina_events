# frozen_string_literal: true

module Mutations
  class CreateAvailabilityPattern < BaseMutation
    description "Add a weekly availability template. Slots are materialized from it; nobody proposes a time, they pick from what exists."

    argument :event_type_id, ID, required: true
    argument :venue_id, ID, required: false
    argument :weekday, Integer, required: true, description: "0 = Sunday."
    argument :start_time, String, required: true, description: "Wall clock, Mountain, e.g. \"16:00\"."
    argument :end_time, String, required: true
    argument :slot_minutes, Integer, required: true
    argument :capacity, Integer, required: true
    argument :price_note, String, required: false
    argument :effective_from, GraphQL::Types::ISO8601Date, required: true
    argument :effective_to, GraphQL::Types::ISO8601Date, required: false
    argument :active, Boolean, required: false

    field :availability_pattern, Types::AvailabilityPatternType, null: true
    field :errors, [ Types::FieldErrorType ], null: false

    def resolve(**attributes)
      require_admin!

      pattern = AvailabilityPattern.new(attributes)

      if pattern.save
        MaterializeTimeBlocksJob.perform_later
        { availability_pattern: pattern, errors: [] }
      else
        { availability_pattern: nil, errors: field_errors(pattern) }
      end
    end
  end
end
