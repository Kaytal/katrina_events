# frozen_string_literal: true

module Types
  class TimeBlockAdminType < Types::BaseObject
    graphql_name "AdminTimeBlock"
    description "A slot as she sees it: what it inherits, what she has overridden, and whether regeneration needs her to look at it."

    field :id, ID, null: false
    field :starts_at, GraphQL::Types::ISO8601DateTime, null: false
    field :ends_at, GraphQL::Types::ISO8601DateTime, null: false
    field :status, String, null: false
    field :notes, String, null: true

    field :capacity_override, Integer, null: true,
          description: "Null means inherit. A value is a deliberate override for this slot alone."
    field :price_note_override, String, null: true,
          description: "Null means inherit."
    field :effective_capacity, Integer, null: true
    field :effective_price_note, String, null: true
    field :inherited_capacity, Integer, null: true,
          description: "What this slot would use with no override — shown as the placeholder in the editor."
    field :inherited_price_note, String, null: true
    field :overridden, Boolean, null: false

    field :spots_remaining, Integer, null: true
    field :approved_count, Integer, null: false

    field :needs_review, Boolean, null: false,
          description: "Regeneration wanted to change or remove this slot but was not allowed to. It has been left alone for you to resolve."
    field :review_reason, String, null: true

    field :event_type, Types::EventTypeType, null: false
    field :venue, Types::VenueType, null: true
    field :source_kind, String, null: false, description: "\"event\", \"pattern\", or \"manual\"."
    field :source_title, String, null: true

    def capacity_override = object.capacity
    def price_note_override = object.price_note
    def inherited_capacity = object.source&.capacity
    def inherited_price_note = object.source&.price_note
    def overridden = object.overridden?

    def source_kind
      return "event" if object.event_id.present?
      return "pattern" if object.availability_pattern_id.present?

      "manual"
    end

    def source_title
      object.event&.title || object.availability_pattern&.event_type&.name
    end
  end
end
