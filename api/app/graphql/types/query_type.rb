# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    description "Read access to the public site and, once authenticated, to Katrina's admin data."

    field :health, Types::HealthType, null: false,
          description: "Liveness plus a database round-trip."

    field :page, Types::PageType, null: true,
          description: "One published static page by slug. Drafts and future-dated pages are not visible." do
      argument :slug, String, required: true
    end

    def health
      Health.new
    end

    def page(slug:)
      # find_by! rather than find_by: a missing page is a NOT_FOUND error, not a
      # silent null the client has to interpret.
      Page.published.find_by!(slug: slug.to_s.strip.downcase)
    end
  end
end
