# frozen_string_literal: true

module Mutations
  class DeleteEvent < BaseMutation
    description "Remove an event and its exceptions. Cancelling (status: \"cancelled\") is usually what she wants instead — it keeps the record."

    argument :id, ID, required: true

    field :deleted_id, ID, null: true
    field :errors, [ Types::FieldErrorType ], null: false

    def resolve(id:)
      require_admin!

      event = Event.find(id)

      # Phase 8 adds the real guard here: an event with approved requests must
      # not be deletable, because the people holding those approvals would
      # never be told.
      if event.destroy
        { deleted_id: id, errors: [] }
      else
        { deleted_id: nil, errors: field_errors(event) }
      end
    end
  end
end
