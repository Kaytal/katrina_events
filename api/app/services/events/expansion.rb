module Events
  # Turns stored events — one-off and recurring — into a flat, ordered list of
  # concrete occurrences overlapping a window. The frontend never sees an RRULE:
  # it asks for a date range and gets rows it can draw.
  class Expansion
    # A recurring event with no `recurrence_until` is unbounded, so the window
    # is what limits the work. Guard against a client asking for a century.
    MAX_WINDOW = 400.days

    class RangeTooLarge < StandardError; end

    def self.call(from:, to:, events: nil)
      new(from: from, to: to, events: events).call
    end

    def initialize(from:, to:, events: nil)
      @from = from
      @to = to
      @events = events
    end

    def call
      raise ArgumentError, "`to` must be after `from`" if to <= from
      raise RangeTooLarge, "range may not exceed #{MAX_WINDOW.inspect}" if to - from > MAX_WINDOW

      scope.flat_map { |event| occurrences_for(event) }.sort_by(&:starts_at)
    end

    private

    attr_reader :from, :to

    def scope
      base = @events || Event.scheduled
      base.possibly_within(from, to).includes(:event_type, :venue, :event_exceptions)
    end

    def occurrences_for(event)
      exceptions = event.event_exceptions.index_by(&:original_date)
      starts_by_date = rule_starts(event).index_by(&:to_date)

      # An occurrence moved *into* the window has to be considered even though
      # the date its rule produced lies outside, so the rule never offered it.
      exceptions.each_value do |exception|
        next unless exception.move? && exception.starts_at < to && exception.ends_at > from

        starts_by_date[exception.original_date] ||= nil
      end

      starts_by_date
        .filter_map { |date, local_start| build(event, date, local_start, exceptions[date]) }
        .select { |occurrence| occurrence.overlaps?(from, to) }
    end

    # Local wall-clock start times the rule produces, before exceptions, at most
    # one per date.
    #
    # The dedupe is not cosmetic. On the fall-back date the 1am–2am wall clock
    # happens twice, so ice_cube legitimately yields two occurrences that
    # re-anchor to the same local time — the duplicate the plan warns about. It
    # also reflects a real invariant: `event_exceptions` is unique on
    # (event_id, original_date), so an event has at most one occurrence per day
    # by construction. Two classes on one day are two events.
    def rule_starts(event)
      return [ event.starts_at.in_time_zone ] unless event.recurring?

      # Pad the lower bound by the duration so an occurrence that began before
      # the window but runs into it is still considered.
      schedule_for(event)
        .occurrences_between(from - event.duration, to)
        .filter_map { |occurrence| reanchor(occurrence, event) }
        .uniq(&:to_date)
    end

    def schedule_for(event)
      start = event.starts_at.in_time_zone
      schedule = IceCube::Schedule.new(start, duration: event.duration)

      rule = IceCube::Rule.from_ical(event.recurrence_rule)
      rule = rule.until(event.recurrence_until.in_time_zone) if event.recurrence_until.present?
      schedule.add_recurrence_rule(rule)

      schedule
    end

    # The DST invariant, made explicit rather than trusted to the library: a 6pm
    # Tuesday class is 6pm on every Tuesday, so we keep the *date* the rule
    # produced and re-apply the event's original wall-clock time in the app's
    # zone. Denver's offset changes twice a year; the class does not move.
    #
    # Returns nil when that wall-clock time does not exist on that date — the
    # hour skipped by the spring-forward transition. A 2:30am slot on the second
    # Sunday in March is not a real time, and inventing one is worse than
    # dropping it.
    def reanchor(occurrence, event)
      base = event.starts_at.in_time_zone
      date = occurrence.to_time.in_time_zone.to_date

      anchored = Time.zone.local(date.year, date.month, date.day, base.hour, base.min, base.sec)

      return nil unless anchored.hour == base.hour && anchored.min == base.min

      anchored
    end

    def build(event, original_date, local_start, exception)
      return nil if exception&.skip?

      if exception&.move?
        return Occurrence.new(
          event: event,
          starts_at: exception.starts_at.in_time_zone,
          ends_at: exception.ends_at.in_time_zone,
          original_date: original_date,
          moved: true
        )
      end

      # Only reachable for a move exception whose destination fell outside the
      # window: the date was added as a candidate, then the exception turned out
      # not to apply here.
      return nil if local_start.nil?

      Occurrence.new(
        event: event,
        starts_at: local_start,
        ends_at: local_start + event.duration,
        original_date: original_date,
        moved: false
      )
    end
  end
end
