# frozen_string_literal: true

module Sources
  # Occurrences are generated, not stored, so each one has to find its block by
  # (event_id, original_date). Doing that per occurrence would be a query per
  # row on every calendar render; this batches a month into one.
  class TimeBlockForOccurrence < GraphQL::Dataloader::Source
    def fetch(keys)
      pairs = keys.map { |event_id, original_date| [ event_id.to_i, original_date ] }

      blocks = TimeBlock
               .where(event_id: pairs.map(&:first).uniq)
               .where(original_date: pairs.map(&:last).uniq)
               .index_by { |block| [ block.event_id, block.original_date ] }

      pairs.map { |pair| blocks[pair] }
    end
  end
end
