# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    include Authorizable

    description "Read access to the public site and, once authenticated, to Katrina's admin data."

    field :health, Types::HealthType, null: false,
          description: "Liveness plus a database round-trip."

    field :me, Types::UserType, null: true,
          description: "The signed-in administrator, or null when the request carries no valid token."

    field :page, Types::PageType, null: true,
          description: "One published static page by slug. Drafts and future-dated pages are not visible." do
      argument :slug, String, required: true
    end

    def health
      Health.new
    end

    # Null rather than an error when unauthenticated: this is how the client
    # asks "am I signed in?" on boot, and a failed boot check is not an error.
    # Fields that expose her data call require_admin! and do raise.
    def me
      current_user
    end

    def page(slug:)
      # find_by! rather than find_by: a missing page is a NOT_FOUND error, not a
      # silent null the client has to interpret.
      Page.published.find_by!(slug: slug.to_s.strip.downcase)
    end
  end
end
