# frozen_string_literal: true

module Types
  class FieldErrorType < Types::BaseObject
    description "A validation failure on one input field, in a shape the admin forms render directly."

    field :field, String, null: false,
          description: "camelCase input field name, e.g. metaDescription. \"base\" for record-level errors."
    field :messages, [ String ], null: false
  end
end
