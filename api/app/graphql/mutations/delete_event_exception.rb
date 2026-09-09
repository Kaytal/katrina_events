# frozen_string_literal: true

module Mutations
  class DeleteEventException < BaseMutation
    description "Restore an occurrence to what its rule says — undoing a cancellation or a move."

    argument :id, ID, required: true

    field :deleted_id, ID, null: true
    field :event, Types::EventAdminType, null: true
    field :errors, [ Types::FieldErrorType ], null: false

    def resolve(id:)
      require_admin!

      exception = EventException.find(id)
      event = exception.event

      exception.destroy!

      MaterializeTimeBlocksJob.perform_later
      { deleted_id: id, event: event.reload, errors: [] }
    end
  end
end
