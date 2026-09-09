module TimeBlocks
  # An availability pattern becomes (end_time − start_time) / slot_minutes
  # blocks per covered day, each with the pattern's capacity — normally 1.
  # Tuesdays 4–6pm at 30 minutes is four blocks.
  #
  # Identity is the slot's start time: a pattern has no notion of an occurrence,
  # and moving the window genuinely retires the old slots.
  class PatternGenerator < Generator
    def call
      reconcile(desired, existing)
    end

    private

    def existing
      TimeBlock.from_pattern(source).where(starts_at: from..to).index_by(&:starts_at)
    end

    def desired
      dates.flat_map { |date| slots_on(date) }.to_h
    end

    def dates
      (from.to_date..to.to_date).select { |date| source.covers?(date) }
    end

    def slots_on(date)
      day_start = anchored(date)
      return [] if day_start.nil?

      Array.new(source.slot_count) do |index|
        starts_at = day_start + (index * source.slot_minutes).minutes
        ends_at = starts_at + source.slot_minutes.minutes

        next nil unless starts_at >= from && starts_at < to

        [ starts_at, attributes_for(starts_at, ends_at) ]
      end.compact
    end

    # Same rule as recurrence expansion: a wall-clock time the spring-forward
    # transition skips does not exist, and inventing one would put a slot at a
    # time nobody can turn up for.
    def anchored(date)
      time = source.start_time
      local = Time.zone.local(date.year, date.month, date.day, time.hour, time.min)

      return nil unless local.hour == time.hour && local.min == time.min

      local
    end

    def attributes_for(starts_at, ends_at)
      {
        availability_pattern: source,
        event_type_id: source.event_type_id,
        venue_id: source.venue_id,
        starts_at: starts_at,
        ends_at: ends_at,
        status: TimeBlock::OPEN,
        auto_closed: false
      }
    end
  end
end
