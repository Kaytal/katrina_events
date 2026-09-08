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

    def pages
      Page.order(:slug)
    end

    def page(slug:)
      Page.find_by!(slug: slug.to_s.strip.downcase)
    end
  end
end
