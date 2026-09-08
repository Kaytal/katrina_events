import { useState } from 'react'
import type { AdminOccurrence, EventException } from '../../lib/queries'
import { ZONE_LABEL, formatMountain, fromMountainInput, toMountainInput } from '../../lib/mountainTime'

export type OccurrenceAction =
  | { kind: 'skip'; originalDate: string }
  | { kind: 'move'; originalDate: string; startsAt: string; endsAt: string }
  | { kind: 'restore'; exceptionId: string }

/**
 * Per-occurrence cancel and move. Cancelled sessions stay in this list, flagged
 * — they have to be visible somewhere for her to undo them, and they are never
 * shown publicly.
 */
export default function OccurrenceList({
  occurrences,
  exceptions,
  busy,
  onAction,
}: {
  occurrences: AdminOccurrence[]
  exceptions: EventException[]
  busy: boolean
  onAction: (action: OccurrenceAction) => void
}) {
  const [moving, setMoving] = useState<string | null>(null)
  const [newStart, setNewStart] = useState('')
  const [newEnd, setNewEnd] = useState('')

  const exceptionFor = (originalDate: string) =>
    exceptions.find((exception) => exception.originalDate === originalDate)

  const beginMove = (occurrence: AdminOccurrence) => {
    setMoving(occurrence.originalDate)
    setNewStart(toMountainInput(occurrence.startsAt))
    setNewEnd(toMountainInput(occurrence.endsAt))
  }

  const submitMove = (originalDate: string) => {
    const startsAt = fromMountainInput(newStart)
    const endsAt = fromMountainInput(newEnd)
    if (!startsAt || !endsAt) return

    onAction({ kind: 'move', originalDate, startsAt, endsAt })
    setMoving(null)
  }

  if (occurrences.length === 0) {
    return <p className="muted">No sessions in the next few months.</p>
  }

  return (
    <ul className="occurrences">
      {occurrences.map((occurrence) => {
        const exception = exceptionFor(occurrence.originalDate)
        const isMoving = moving === occurrence.originalDate

        return (
          <li key={occurrence.id} className={occurrence.skipped ? 'is-skipped' : undefined}>
            <div className="occurrence-when">
              <span className={occurrence.skipped ? 'struck' : undefined}>
                {formatMountain(occurrence.startsAt)}
              </span>
              {occurrence.skipped && <span className="badge">Cancelled</span>}
              {occurrence.moved && <span className="badge">Moved</span>}
              {occurrence.moved && (
                <span className="occurrence-note">
                  originally {occurrence.originalDate}
                </span>
              )}
            </div>

            {isMoving ? (
              <div className="move-form">
                <label>
                  New start
                  <input
                    type="datetime-local"
                    value={newStart}
                    onChange={(event) => setNewStart(event.target.value)}
                  />
                </label>
                <label>
                  New end
                  <input
                    type="datetime-local"
                    value={newEnd}
                    onChange={(event) => setNewEnd(event.target.value)}
                  />
                </label>
                <span className="hint">{ZONE_LABEL}</span>
                <div className="occurrence-actions">
                  <button type="button" disabled={busy} onClick={() => submitMove(occurrence.originalDate)}>
                    Save new time
                  </button>
                  <button type="button" className="link" onClick={() => setMoving(null)}>
                    Cancel
                  </button>
                </div>
              </div>
            ) : (
              <div className="occurrence-actions">
                {exception ? (
                  <button
                    type="button"
                    className="link"
                    disabled={busy}
                    onClick={() => onAction({ kind: 'restore', exceptionId: exception.id })}
                  >
                    {occurrence.skipped ? 'Restore this session' : 'Undo the move'}
                  </button>
                ) : (
                  <>
                    <button type="button" className="link" onClick={() => beginMove(occurrence)}>
                      Move
                    </button>
                    <button
                      type="button"
                      className="link danger"
                      disabled={busy}
                      onClick={() =>
                        onAction({ kind: 'skip', originalDate: occurrence.originalDate })
                      }
                    >
                      Cancel this one
                    </button>
                  </>
                )}
              </div>
            )}
          </li>
        )
      })}
    </ul>
  )
}
