# frozen_string_literal: true

module Types
  class PageType < Types::BaseObject
    description "A static content page. The body is Markdown, sanitized on the client before rendering."

    field :slug, String, null: false
    field :title, String, null: false
    field :body, String, null: false, description: "Markdown source, not HTML."
    field :meta_description, String, null: true
    field :published_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
