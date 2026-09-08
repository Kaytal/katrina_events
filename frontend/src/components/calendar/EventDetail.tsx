import type { EventOccurrence } from '../../lib/queries'
import { STATE_ICONS, STATE_LABELS, stateOf } from './occurrenceState'

function formatRange(startsAt: string, endsAt: string, allDay: boolean): string {
  const start = new Date(startsAt)
  const end = new Date(endsAt)

  const day = start.toLocaleDateString(undefined, {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
  })

  if (allDay) return day

  const time = (date: Date) =>
    date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })

  return `${day}, ${time(start)}–${time(end)}`
}

export default function EventDetail({
  occurrence,
  onClose,
}: {
  occurrence: EventOccurrence
  onClose: () => void
}) {
  const state = stateOf(occurrence)

  return (
    <aside className="detail" aria-label={`${occurrence.title} details`}>
      <div className="detail-head">
        <div>
          <span className="type-chip" style={{ backgroundColor: occurrence.eventType.color }}>
            {occurrence.eventType.name}
          </span>
          <h2>{occurrence.title}</h2>
          <p className="detail-when">{formatRange(occurrence.startsAt, occurrence.endsAt, occurrence.allDay)}</p>
        </div>
        <button type="button" className="close" onClick={onClose} aria-label="Close details">
          ×
        </button>
      </div>

      {occurrence.moved && (
        <p className="detail-flag">This session was rescheduled from its usual time.</p>
      )}

      {occurrence.venue && (
        <p className="detail-line">
          <strong>{occurrence.venue.name}</strong>
          {occurrence.venue.address && <> · {occurrence.venue.address}</>}
        </p>
      )}

      {occurrence.description && <p className="detail-body">{occurrence.description}</p>}

      {occurrence.priceNote && (
        <p className="detail-line">
          <strong>Cost:</strong> {occurrence.priceNote}
        </p>
      )}

      <p className={`state state--${state}`}>
        <span aria-hidden="true">{STATE_ICONS[state]}</span> {STATE_LABELS[state]}
      </p>

      {state === 'announcement' ? (
        <p className="muted">Nothing to sign up for — just come along.</p>
      ) : (
        /*
          Deliberately not a button yet. Requesting needs time_blocks (Phase 7)
          and the request form (Phase 8); a button that did nothing, or that
          said "Book", would set exactly the expectation this design exists to
          avoid.
        */
        <p className="muted">
          {occurrence.capacity !== null && <>Room for {occurrence.capacity}. </>}
          Requesting opens soon — for now, use the{' '}
          <a href="/contact">contact page</a>. Requesting is not booking:
          Katrina confirms each one by email.
        </p>
      )}
    </aside>
  )
}
