# frozen_string_literal: true

module Types
  class PageType < Types::BaseObject
    description "A static content page. The body is Markdown, sanitized on the client before rendering."

    field :slug, String, null: false
    field :title, String, null: false
    field :body, String, null: false, description: "Markdown source, not HTML."
    field :meta_description, String, null: true
    field :published_at, GraphQL::Types::ISO8601DateTime, null: true
    field :published, Boolean, null: false,
          description: "False for a draft, and for a page whose published_at is still in the future."
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    def published
      object.published?
    end
  end
end
