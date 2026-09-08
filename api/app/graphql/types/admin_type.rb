# frozen_string_literal: true

module Types
  # Everything readable only by Katrina hangs off this one field, and the field
  # itself is what enforces authentication. That is the point: a new admin query
  # added under here cannot forget to check, because if `admin` raises, nothing
  # beneath it resolves.
  class AdminType < Types::BaseObject
    description "Authenticated read access. Requesting any field here without a valid token fails."

    field :pages, [ Types::PageType ], null: false,
          description: "Every page, drafts included, in a stable order for the editor's list."

    field :page, Types::PageType, null: true,
          description: "One page by slug, whether or not it is published." do
      argument :slug, String, required: true
    end

    field :events, [ Types::EventAdminType ], null: false,
          description: "Stored events — one row per event, not per occurrence. Newest start first." do
      argument :include_cancelled, Boolean, required: false, default_value: true
    end

    field :event, Types::EventAdminType, null: true do
      argument :id, ID, required: true
    end

    field :venues, [ Types::VenueType ], null: false

    field :venue, Types::VenueType, null: true do
      argument :id, ID, required: true
    end

    def pages
      Page.order(:slug)
    end

    def events(include_cancelled:)
      scope = Event.all
      scope = scope.scheduled unless include_cancelled
      scope.includes(:event_type, :venue).order(starts_at: :desc)
    end

    def event(id:)
      Event.includes(:event_type, :venue, :event_exceptions).find(id)
    end

    def venues
      Venue.order(:name)
    end

    def venue(id:)
      Venue.find(id)
    end

    def page(slug:)
      Page.find_by!(slug: slug.to_s.strip.downcase)
    end
  end
end
