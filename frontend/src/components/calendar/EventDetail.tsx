import type { EventOccurrence, TimeBlock } from '../../lib/queries'
import { STATE_ICONS, STATE_LABELS, stateOf, stateOfBlock, type OccurrenceState } from './occurrenceState'

function formatRange(startsAt: string, endsAt: string, allDay = false): string {
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

function Availability({ state, spots }: { state: OccurrenceState; spots: number | null }) {
  return (
    <>
      <p className={`state state--${state}`}>
        <span aria-hidden="true">{STATE_ICONS[state]}</span> {STATE_LABELS[state]}
      </p>

      {state === 'announcement' && <p className="muted">Nothing to sign up for — just come along.</p>}

      {state === 'open' && (
        <p className="muted">
          {spots !== null && <>{spots} {spots === 1 ? 'place' : 'places'} left. </>}
          Requesting opens soon — for now, use the <a href="/contact">contact page</a>.{' '}
          <strong>Requesting is not booking</strong>: Katrina confirms each one by email.
        </p>
      )}

      {state === 'full' && <p className="muted">This one is full. The contact page is the place to ask about another time.</p>}

      {state === 'closed' && <p className="muted">Not taking requests for this one.</p>}
    </>
  )
}

export function BlockDetail({ block, onClose }: { block: TimeBlock; onClose: () => void }) {
  const state = stateOfBlock(block)

  return (
    <aside className="detail" aria-label="Slot details">
      <div className="detail-head">
        <div>
          <span className="type-chip" style={{ backgroundColor: block.eventType.color }}>
            {block.eventType.name}
          </span>
          <h2>Available slot</h2>
          <p className="detail-when">{formatRange(block.startsAt, block.endsAt)}</p>
        </div>
        <button type="button" className="close" onClick={onClose} aria-label="Close details">
          ×
        </button>
      </div>

      {block.venue && (
        <p className="detail-line">
          <strong>{block.venue.name}</strong>
          {block.venue.address && <> · {block.venue.address}</>}
        </p>
      )}

      {block.priceNote && (
        <p className="detail-line">
          <strong>Cost:</strong> {block.priceNote}
        </p>
      )}

      <Availability state={state} spots={block.spotsRemaining} />
    </aside>
  )
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
          <p className="detail-when">
            {formatRange(occurrence.startsAt, occurrence.endsAt, occurrence.allDay)}
          </p>
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

      <Availability state={state} spots={occurrence.spotsRemaining} />
    </aside>
  )
}
