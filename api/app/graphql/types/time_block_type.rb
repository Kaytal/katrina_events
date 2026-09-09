# frozen_string_literal: true

module Types
  # The public view of a bookable slot. Deliberately excludes her notes, the
  # raw override columns, and the review flag — those are hers.
  class TimeBlockType < Types::BaseObject
    description "A concrete slot a request can point at. Capacity and price may be inherited from the class or pattern that generated it."

    field :id, ID, null: false
    field :starts_at, GraphQL::Types::ISO8601DateTime, null: false
    field :ends_at, GraphQL::Types::ISO8601DateTime, null: false
    field :status, String, null: false, description: "\"open\", \"closed\", or \"full\"."

    field :capacity, Integer, null: true,
          description: "The capacity in force, inherited unless overridden for this slot."
    field :spots_remaining, Integer, null: true,
          description: "Null when the slot has no capacity limit."
    field :price_note, String, null: true,
          description: "The price note in force, inherited unless overridden."

    field :standalone, Boolean, null: false,
          description: "True for an open-availability slot, which the calendar must show in its own right. False for a slot generated from an event, which is already on the calendar as that event's occurrence."

    field :event_type, Types::EventTypeType, null: false
    field :venue, Types::VenueType, null: true

    def capacity = object.effective_capacity
    def price_note = object.effective_price_note
    def standalone = object.event_id.nil?
  end
end
