module Events
  # One concrete instance of an event on the calendar. Not a row: recurring
  # events produce these on the fly, which is why the id is composite.
  Occurrence = Struct.new(
    :event, :starts_at, :ends_at, :original_date, :moved,
    keyword_init: true
  ) do
    # Stable across requests and unique within a range, so FullCalendar can key
    # on it and a detail panel can be linked to.
    def id
      "#{event.id}:#{original_date.iso8601}"
    end

    def moved?
      moved
    end

    def overlaps?(from, to)
      starts_at < to && ends_at > from
    end
  end
end
