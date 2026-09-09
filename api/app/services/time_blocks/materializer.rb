module TimeBlocks
  # Turns the two things she edits — bookable events and availability patterns —
  # into the concrete rows a request can point at, over a rolling window.
  #
  # THE PROTECTION RULE (§2), which everything here is arranged around:
  # regeneration may freely replace future blocks with no requests attached; a
  # block with requests is never deleted and never silently moved. It is left
  # exactly where it is and flagged for her to resolve.
  #
  # Overrides survive because this never writes `capacity` or `price_note` on an
  # existing row. Those columns mean "she said so"; null means inherit. An empty
  # block can carry a deliberate override too, which is why identity-based
  # upsert matters rather than delete-and-recreate.
  class Materializer
    DEFAULT_WINDOW = 90.days

    Result = Struct.new(:created, :updated, :removed, :flagged, keyword_init: true) do
      def to_s
        "created=#{created} updated=#{updated} removed=#{removed} flagged=#{flagged}"
      end
    end

    def self.call(from: Time.current.beginning_of_day, to: nil, events: nil, patterns: nil)
      new(from: from, to: to || (Time.current.beginning_of_day + DEFAULT_WINDOW),
          events: events, patterns: patterns).call
    end

    def initialize(from:, to:, events: nil, patterns: nil)
      @from = from
      @to = to
      @events = events
      @patterns = patterns
      @result = Result.new(created: 0, updated: 0, removed: 0, flagged: 0)
    end

    def call
      raise ArgumentError, "`to` must be after `from`" if to <= from

      event_scope.find_each { |event| EventGenerator.new(event, from, to, result).call }
      pattern_scope.find_each { |pattern| PatternGenerator.new(pattern, from, to, result).call }

      result
    end

    private

    attr_reader :from, :to, :result

    # Sources that should produce blocks, PLUS sources that already own blocks in
    # the window. The second half is what makes turning `bookable` off,
    # cancelling an event, or deactivating a pattern actually clean up: those
    # sources fall out of the first filter, and a source never visited is a
    # source whose stale blocks are never removed.
    def event_scope
      base = @events || Event.all

      generating = base.scheduled.where(bookable: true).possibly_within(from, to)
      owning = base.where(id: TimeBlock.where(starts_at: from..to).select(:event_id))

      Event.where(id: generating).or(Event.where(id: owning))
    end

    def pattern_scope
      base = @patterns || AvailabilityPattern.all

      generating = base.active.effective_between(from, to)
      owning = base.where(id: TimeBlock.where(starts_at: from..to).select(:availability_pattern_id))

      AvailabilityPattern.where(id: generating).or(AvailabilityPattern.where(id: owning))
    end
  end
end
