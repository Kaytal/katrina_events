# frozen_string_literal: true

module Types
  # Named EventTypeType because the model is EventType — awkward, but renaming
  # it to `Category` in the schema alone would make the two harder to line up.
  class EventTypeType < Types::BaseObject
    graphql_name "EventType"
    description "A category of event, which drives the calendar's colour coding."

    field :id, ID, null: false
    field :name, String, null: false
    field :slug, String, null: false
    field :color, String, null: false, description: "Hex, e.g. #6b3f7a."
    field :description, String, null: true
  end
end
