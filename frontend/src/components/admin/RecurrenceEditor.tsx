import {
  FREQUENCY_LABELS,
  WEEKDAYS,
  describeRecurrence,
  type Frequency,
  type Recurrence,
} from '../../lib/recurrence'

/**
 * She picks a frequency and, for weekly, the days. The RRULE is composed for
 * her — nobody should have to type RFC-5545 — and the sentence underneath is
 * what she actually checks before saving.
 */
export default function RecurrenceEditor({
  value,
  onChange,
}: {
  value: Recurrence
  onChange: (next: Recurrence) => void
}) {
  const toggleDay = (code: string) => {
    const weekdays = value.weekdays.includes(code)
      ? value.weekdays.filter((day) => day !== code)
      : [...value.weekdays, code]

    // Keep calendar order, so BYDAY reads MO,WE,FR rather than the click order.
    onChange({
      ...value,
      weekdays: WEEKDAYS.filter((day) => weekdays.includes(day.code)).map((day) => day.code),
    })
  }

  return (
    <fieldset className="recurrence">
      <legend>Repeats</legend>

      <select
        aria-label="Repeat frequency"
        value={value.frequency}
        onChange={(event) => onChange({ ...value, frequency: event.target.value as Frequency })}
      >
        {(Object.keys(FREQUENCY_LABELS) as Frequency[]).map((frequency) => (
          <option key={frequency} value={frequency}>
            {FREQUENCY_LABELS[frequency]}
          </option>
        ))}
      </select>

      {value.frequency !== 'none' && (
        <label className="interval">
          every
          <input
            type="number"
            min={1}
            max={52}
            value={value.interval}
            onChange={(event) =>
              onChange({ ...value, interval: Math.max(1, Number(event.target.value) || 1) })
            }
          />
          {{ DAILY: 'day(s)', WEEKLY: 'week(s)', MONTHLY: 'month(s)', YEARLY: 'year(s)' }[
            value.frequency
          ]}
        </label>
      )}

      {value.frequency === 'WEEKLY' && (
        <div className="weekdays" role="group" aria-label="Days of the week">
          {WEEKDAYS.map((day) => (
            <button
              key={day.code}
              type="button"
              className={value.weekdays.includes(day.code) ? 'day is-on' : 'day'}
              aria-pressed={value.weekdays.includes(day.code)}
              onClick={() => toggleDay(day.code)}
            >
              {day.label}
            </button>
          ))}
        </div>
      )}

      <p className="hint">{describeRecurrence(value)}</p>

      {/*
        An event can occur at most once a day: the server identifies an
        occurrence by its local date, so a twice-a-day rule is not
        representable. Saying so here is better than a rejected save.
      */}
      {value.frequency !== 'none' && (
        <p className="hint">
          An event happens at most once a day. For a morning and an afternoon
          class, make two events.
        </p>
      )}
    </fieldset>
  )
}
