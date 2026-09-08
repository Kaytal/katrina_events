# frozen_string_literal: true

module Mutations
  class UpdateVenue < BaseMutation
    description "Edit a place."

    argument :id, ID, required: true
    argument :name, String, required: false
    argument :address, String, required: false
    argument :url, String, required: false
    argument :notes, String, required: false

    field :venue, Types::VenueType, null: true
    field :errors, [ Types::FieldErrorType ], null: false

    def resolve(id:, **attributes)
      require_admin!

      venue = Venue.find(id)
      venue.assign_attributes(attributes)

      if venue.save
        { venue: venue, errors: [] }
      else
        { venue: nil, errors: field_errors(venue) }
      end
    end
  end
end
