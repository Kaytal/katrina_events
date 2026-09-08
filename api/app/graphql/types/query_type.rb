# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    include Authorizable

    description "Read access to the public site and, once authenticated, to Katrina's admin data."

    field :health, Types::HealthType, null: false,
          description: "Liveness plus a database round-trip."

    field :me, Types::UserType, null: true,
          description: "The signed-in administrator, or null when the request carries no valid token."

    field :admin, Types::AdminType, null: false,
          description: "Authenticated read access. Fails without a valid token."

    field :page, Types::PageType, null: true,
          description: "One published static page by slug. Drafts and future-dated pages are not visible." do
      argument :slug, String, required: true
    end

    field :events, [ Types::EventOccurrenceType ], null: false,
          description: "Expanded occurrences overlapping [from, to), in chronological order. Recurrence rules never reach the client." do
      argument :from, GraphQL::Types::ISO8601DateTime, required: true
      argument :to, GraphQL::Types::ISO8601DateTime, required: true
    end

    field :event_types, [ Types::EventTypeType ], null: false,
          description: "Every category, for the calendar's colour legend."

    def health
      Health.new
    end

    # Null rather than an error when unauthenticated: this is how the client
    # asks "am I signed in?" on boot, and a failed boot check is not an error.
    # Fields that expose her data call require_admin! and do raise.
    def me
      current_user
    end

    # The single gate for every authenticated read. Returns self only so that
    # AdminType's own resolvers have an object to hang off; the check is here.
    def admin
      require_admin!
      Types::AdminType
    end

    def events(from:, to:)
      Events::Expansion.call(from: from.in_time_zone, to: to.in_time_zone)
    rescue Events::Expansion::RangeTooLarge => e
      raise GraphQL::ExecutionError.new(e.message, extensions: { "code" => "RANGE_TOO_LARGE" })
    rescue ArgumentError => e
      raise GraphQL::ExecutionError.new(e.message, extensions: { "code" => "BAD_REQUEST" })
    end

    def event_types
      EventType.alphabetical
    end

    def page(slug:)
      # find_by! rather than find_by: a missing page is a NOT_FOUND error, not a
      # silent null the client has to interpret.
      Page.published.find_by!(slug: slug.to_s.strip.downcase)
    end
  end
end
