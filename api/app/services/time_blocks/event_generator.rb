module TimeBlocks
  # A bookable event's occurrence becomes ONE block spanning the whole
  # occurrence, inheriting the event's capacity and price note. A 4:30–5:15
  # class with capacity 12 is one block twelve people can be approved into — it
  # is emphatically not twelve slots.
  #
  # Identity is the occurrence's `original_date`, not its start time, so moving
  # a session updates its own block instead of orphaning one and making another.
  class EventGenerator < Generator
    def call
      reconcile(desired, existing)
    end

    private

    def existing
      TimeBlock.from_event(source).where(starts_at: from..to)
               .or(TimeBlock.from_event(source).where(original_date: from.to_date..to.to_date))
               .index_by(&:original_date)
    end

    def desired
      return {} unless generates_blocks?

      occurrences.to_h do |occurrence|
        [ occurrence.original_date, attributes_for(occurrence) ]
      end
    end

    # An announcement generates nothing, and neither does a cancelled event.
    # Returning an empty desired set is what makes turning `bookable` off, or
    # cancelling an event, clean up the blocks it used to own.
    def generates_blocks?
      source.bookable? && source.status == Event::SCHEDULED
    end

    def occurrences
      Events::Expansion.call(
        from: from, to: to,
        events: Event.where(id: source.id),
        # Cancelled occurrences still need their block *closed* rather than
        # deleted — the block may already have people in it.
        include_skipped: true
      )
    end

    def attributes_for(occurrence)
      {
        event: source,
        original_date: occurrence.original_date,
        event_type_id: source.event_type_id,
        venue_id: source.venue_id,
        starts_at: occurrence.starts_at,
        ends_at: occurrence.ends_at,
        status: occurrence.skipped? ? TimeBlock::CLOSED : TimeBlock::OPEN,
        auto_closed: occurrence.skipped?
      }
    end
  end
end
