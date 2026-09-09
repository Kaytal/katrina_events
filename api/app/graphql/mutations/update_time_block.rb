# frozen_string_literal: true

module Mutations
  class UpdateTimeBlock < BaseMutation
    description "Open or close one slot, or override its capacity or price for that occasion only."

    argument :id, ID, required: true
    argument :status, String, required: false, description: "\"open\", \"closed\", or \"full\"."
    argument :capacity, Integer, required: false,
             description: "An override for this slot alone. Use resetCapacity to go back to inheriting."
    argument :price_note, String, required: false
    argument :notes, String, required: false

    # Null cannot express "go back to inheriting" — a GraphQL null argument is
    # indistinguishable from an absent one — and without a way back, the first
    # override she sets can never be undone.
    argument :reset_capacity, Boolean, required: false,
             description: "Drop the override and inherit from the class or pattern again."
    argument :reset_price_note, Boolean, required: false

    argument :clear_review, Boolean, required: false,
             description: "Dismiss the needs-review flag once she has dealt with it."

    field :time_block, Types::TimeBlockAdminType, null: true
    field :errors, [ Types::FieldErrorType ], null: false

    def resolve(id:, reset_capacity: false, reset_price_note: false, clear_review: false, **attributes)
      require_admin!

      block = TimeBlock.find(id)
      block.assign_attributes(attributes)

      block.capacity = nil if reset_capacity
      block.price_note = nil if reset_price_note

      if clear_review
        block.needs_review = false
        block.review_reason = nil
      end

      # A close she makes by hand must survive the next regeneration, so mark it
      # as hers rather than leaving it looking like one the job made.
      block.auto_closed = false if attributes.key?(:status)

      if block.save
        { time_block: block, errors: [] }
      else
        { time_block: nil, errors: field_errors(block) }
      end
    end
  end
end
