# frozen_string_literal: true

module Types
  class EventOccurrenceType < Types::BaseObject
    description "One concrete instance of an event on the calendar. Recurring events are expanded server-side, so this is not a stored row."

    field :id, ID, null: false,
          description: "\"<eventId>:<originalDate>\" — stable across requests. Not a database id."
    field :event_id, ID, null: false
    field :title, String, null: false
    field :description, String, null: true
    field :starts_at, GraphQL::Types::ISO8601DateTime, null: false
    field :ends_at, GraphQL::Types::ISO8601DateTime, null: false
    field :all_day, Boolean, null: false
    field :event_type, Types::EventTypeType, null: false
    field :venue, Types::VenueType, null: true

    field :bookable, Boolean, null: false,
          description: "False for an announcement — shown on the calendar with no request button."
    field :capacity, Integer, null: true
    field :price_note, String, null: true

    field :time_block, Types::TimeBlockType, null: true,
          description: "The slot generated from this occurrence, when the event is bookable and a block has been materialized. Carried here so the calendar needs no second call."
    field :spots_remaining, Integer, null: true,
          description: "Shortcut for timeBlock.spotsRemaining; null when the occurrence is not bookable."

    field :recurring, Boolean, null: false
    field :moved, Boolean, null: false,
          description: "True when this occurrence was rescheduled away from the time its rule would have produced."
    field :skipped, Boolean, null: false,
          description: "True only in the admin occurrence list: a cancelled session, shown so it can be restored. Never true on the public calendar."
    field :original_date, GraphQL::Types::ISO8601Date, null: false,
          description: "The local date the recurrence rule produced. Identifies the occurrence even after a move."

    delegate :event, to: :object

    def event_id = event.id
    def title = event.title
    def description = event.description
    def all_day = event.all_day
    def event_type = event.event_type
    def venue = event.venue
    def bookable = event.bookable
    def capacity = event.capacity
    def price_note = event.price_note
    def recurring = event.recurring?
    def moved = object.moved?

    # Batched through a Dataloader source: one query per calendar render rather
    # than one per occurrence.
    def time_block
      return nil unless event.bookable?

      dataloader.with(Sources::TimeBlockForOccurrence)
                .load([ event.id, object.original_date ])
    end

    def spots_remaining
      block = time_block
      block&.spots_remaining
    end
    def skipped = object.skipped? || false
  end
end
