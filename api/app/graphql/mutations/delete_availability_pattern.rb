# frozen_string_literal: true

module Mutations
  class DeleteAvailabilityPattern < BaseMutation
    description "Remove a template. Refuses while any of its slots have requests — deactivating it instead retires the free slots and keeps those."

    argument :id, ID, required: true

    field :deleted_id, ID, null: true
    field :errors, [ Types::FieldErrorType ], null: false

    def resolve(id:)
      require_admin!

      pattern = AvailabilityPattern.find(id)

      free, held = pattern.time_blocks.partition { |block| !block.protected_from_regeneration? }

      free.each(&:destroy!)

      # The protection rule says a block with requests is never deleted. It does
      # not say the pattern must go anyway — and detaching the block to force
      # that through would leave a slot no source regenerates and nothing ever
      # tidies. Deactivating is the action she actually wants: it retires
      # everything free and leaves the held slots attached and visible.
      return refuse(held, pattern) if held.any?

      # `restrict_with_error` consults the association, and the rows just
      # destroyed are still sitting in its cache — without this the pattern
      # refuses to go on the strength of blocks that no longer exist.
      pattern.time_blocks.reset
      pattern.destroy!
      { deleted_id: id, errors: [] }
    end

    private

    def refuse(held, pattern)
      held.each do |block|
        block.flag_for_review!(
          "The availability this slot came from is being removed, but people " \
          "have already asked for it. Decide what to tell them."
        )
      end

      {
        deleted_id: nil,
        errors: [ {
          field: "base",
          messages: [
            "#{held.size} #{'slot'.pluralize(held.size)} already #{held.size == 1 ? 'has' : 'have'} " \
            "requests, so this cannot be deleted. Turn it off instead — that retires the free " \
            "slots and leaves those alone until you have dealt with them."
          ]
        } ]
      }.tap { pattern.reload }
    end
  end
end
