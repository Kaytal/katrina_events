# frozen_string_literal: true

module Mutations
  class CreateVenue < BaseMutation
    description "Add a place. Needed so she can announce a festival at a venue that is not already on file."

    argument :name, String, required: true
    argument :address, String, required: false
    argument :url, String, required: false
    argument :notes, String, required: false

    field :venue, Types::VenueType, null: true
    field :errors, [ Types::FieldErrorType ], null: false

    def resolve(**attributes)
      require_admin!

      venue = Venue.new(attributes)

      if venue.save
        { venue: venue, errors: [] }
      else
        { venue: nil, errors: field_errors(venue) }
      end
    end
  end
end
