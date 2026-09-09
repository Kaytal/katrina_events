# frozen_string_literal: true

module Mutations
  class MaterializeTimeBlocks < BaseMutation
    description "Regenerate slots now rather than waiting for the nightly run. Safe to call repeatedly — it is idempotent and honours the protection rule."

    field :created, Integer, null: false
    field :updated, Integer, null: false
    field :removed, Integer, null: false
    field :flagged, Integer, null: false

    def resolve
      require_admin!

      result = TimeBlocks::Materializer.call

      {
        created: result.created, updated: result.updated,
        removed: result.removed, flagged: result.flagged
      }
    end
  end
end
