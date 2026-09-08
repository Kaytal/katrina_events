# frozen_string_literal: true

module Types
  class VenueType < Types::BaseObject
    description "Where an event happens."

    field :id, ID, null: false
    field :name, String, null: false
    field :address, String, null: true
    field :url, String, null: true
  end
end
