# frozen_string_literal: true

module Types
  class AvailabilityPatternType < Types::BaseObject
    graphql_name "AvailabilityPattern"
    description "A weekly template — \"Tuesdays 4–6pm, 30-minute slots\" — that the app materializes into slots."

    field :id, ID, null: false
    field :weekday, Integer, null: false, description: "0 = Sunday, matching Ruby's Date#wday."
    field :start_time, String, null: false, description: "Wall clock, Mountain, e.g. \"16:00\"."
    field :end_time, String, null: false
    field :slot_minutes, Integer, null: false
    field :capacity, Integer, null: false
    field :price_note, String, null: true
    field :effective_from, GraphQL::Types::ISO8601Date, null: false
    field :effective_to, GraphQL::Types::ISO8601Date, null: true
    field :active, Boolean, null: false
    field :slot_count, Integer, null: false, description: "Slots produced on each covered day."

    field :event_type, Types::EventTypeType, null: false
    field :venue, Types::VenueType, null: true

    def start_time = object.start_time&.strftime("%H:%M")
    def end_time = object.end_time&.strftime("%H:%M")
  end
end
