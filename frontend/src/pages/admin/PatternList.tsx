import { useState } from 'react'
import { useMutation, useQuery } from '@apollo/client'
import {
  ADMIN_PATTERNS_QUERY,
  ADMIN_VENUES_QUERY,
  CREATE_PATTERN_MUTATION,
  DELETE_PATTERN_MUTATION,
  EVENT_TYPES_QUERY,
  UPDATE_PATTERN_MUTATION,
  type AdminPatternsData,
  type AdminVenuesData,
  type AvailabilityPattern,
  type EventTypesQueryData,
  type FieldError,
  type PatternMutationData,
} from '../../lib/queries'
import { WEEKDAYS } from '../../lib/recurrence'
import { ZONE_LABEL } from '../../lib/mountainTime'
import { useDocumentMeta } from '../../lib/useDocumentMeta'

type Draft = {
  id: string | null
  eventTypeId: string
  venueId: string
  weekday: number
  startTime: string
  endTime: string
  slotMinutes: number
  capacity: number
  priceNote: string
  effectiveFrom: string
  effectiveTo: string
  active: boolean
}

const BLANK: Draft = {
  id: null,
  eventTypeId: '',
  venueId: '',
  weekday: 2,
  startTime: '16:00',
  endTime: '18:00',
  slotMinutes: 30,
  capacity: 1,
  priceNote: '',
  effectiveFrom: new Date().toISOString().slice(0, 10),
  effectiveTo: '',
  active: true,
}

function minutesBetween(start: string, end: string): number {
  const [sh, sm] = start.split(':').map(Number)
  const [eh, em] = end.split(':').map(Number)

  return (eh ?? 0) * 60 + (em ?? 0) - ((sh ?? 0) * 60 + (sm ?? 0))
}

function describe(draft: Draft): string {
  const day = WEEKDAYS[draft.weekday]?.plural ?? '?'
  const span = minutesBetween(draft.startTime, draft.endTime)

  if (span <= 0) return 'The end time needs to be after the start time.'
  if (span % draft.slotMinutes !== 0) {
    return `${span} minutes does not divide evenly into ${draft.slotMinutes}-minute slots — ${span % draft.slotMinutes} minutes would be left over.`
  }

  const count = span / draft.slotMinutes
  const each = draft.capacity === 1 ? 'one person at a time' : `${draft.capacity} people at a time`

  return `${day}: ${count} slot${count === 1 ? '' : 's'} of ${draft.slotMinutes} minutes, ${each}.`
}

function summarise(pattern: AvailabilityPattern): string {
  const day = WEEKDAYS[pattern.weekday]?.plural ?? '?'

  return `${day} ${pattern.startTime}–${pattern.endTime} · ${pattern.slotCount} × ${pattern.slotMinutes} min · ${pattern.capacity} at a time`
}

export default function PatternList() {
  const [draft, setDraft] = useState<Draft | null>(null)
  const { data, loading, error } = useQuery<AdminPatternsData>(ADMIN_PATTERNS_QUERY, {
    fetchPolicy: 'cache-and-network',
  })
  const { data: typeData } = useQuery<EventTypesQueryData>(EVENT_TYPES_QUERY)
  const { data: venueData } = useQuery<AdminVenuesData>(ADMIN_VENUES_QUERY)

  useDocumentMeta('Open availability', null)

  const refetch = { refetchQueries: [ADMIN_PATTERNS_QUERY], onError: () => undefined }
  const [createPattern, createState] = useMutation<PatternMutationData>(CREATE_PATTERN_MUTATION, refetch)
  const [updatePattern, updateState] = useMutation<PatternMutationData>(UPDATE_PATTERN_MUTATION, refetch)
  const [deletePattern, deleteState] = useMutation(DELETE_PATTERN_MUTATION, refetch)

  const busy = createState.loading || updateState.loading || deleteState.loading
  const errors: FieldError[] =
    createState.data?.createAvailabilityPattern?.errors ??
    updateState.data?.updateAvailabilityPattern?.errors ??
    []

  const save = async () => {
    if (!draft) return

    const shared = {
      eventTypeId: draft.eventTypeId,
      venueId: draft.venueId === '' ? null : draft.venueId,
      weekday: draft.weekday,
      startTime: draft.startTime,
      endTime: draft.endTime,
      slotMinutes: draft.slotMinutes,
      capacity: draft.capacity,
      priceNote: draft.priceNote.trim() === '' ? null : draft.priceNote,
      effectiveFrom: draft.effectiveFrom,
      effectiveTo: draft.effectiveTo === '' ? null : draft.effectiveTo,
    }

    const result = draft.id
      ? await updatePattern({
          variables: { id: draft.id, ...shared, active: draft.active, clearEffectiveTo: draft.effectiveTo === '' },
        })
      : await createPattern({ variables: shared })

    const payload =
      result.data?.createAvailabilityPattern ?? result.data?.updateAvailabilityPattern
    if ((payload?.errors ?? []).length === 0 && payload?.availabilityPattern) setDraft(null)
  }

  const beginNew = () => {
    const firstType = typeData?.eventTypes[0]
    setDraft({ ...BLANK, eventTypeId: firstType?.id ?? '' })
  }

  if (loading && !data) return <p className="notice" role="status">Loading…</p>

  if (error) {
    return (
      <div className="notice notice--bad" role="alert">
        <h1>Couldn&rsquo;t load your availability</h1>
        <p>{error.message}</p>
      </div>
    )
  }

  const patterns = data?.admin.availabilityPatterns ?? []

  return (
    <div className="admin">
      <div className="admin-head">
        <div>
          <h1>Open availability</h1>
          <p className="muted">
            Recurring windows that become individual slots people can ask for —
            private lessons and one-off work. All times {ZONE_LABEL}.
          </p>
        </div>
        <button type="button" onClick={beginNew} disabled={draft !== null}>
          Add availability
        </button>
      </div>

      {draft && (
        <div className="panel panel--wide">
          <h2>{draft.id ? 'Edit availability' : 'New availability'}</h2>

          {errors.map((fieldError) => (
            <p className="field-error" key={fieldError.field}>
              {fieldError.messages.join(', ')}
            </p>
          ))}

          <div className="editor-fields">
            <label htmlFor="pattern-day">Day of the week</label>
            <select
              id="pattern-day"
              value={draft.weekday}
              onChange={(e) => setDraft({ ...draft, weekday: Number(e.target.value) })}
            >
              {WEEKDAYS.map((day, index) => (
                <option key={day.code} value={index}>{day.label}</option>
              ))}
            </select>

            <label htmlFor="pattern-start">From ({ZONE_LABEL})</label>
            <input
              id="pattern-start"
              type="time"
              value={draft.startTime}
              onChange={(e) => setDraft({ ...draft, startTime: e.target.value })}
            />

            <label htmlFor="pattern-end">Until</label>
            <input
              id="pattern-end"
              type="time"
              value={draft.endTime}
              onChange={(e) => setDraft({ ...draft, endTime: e.target.value })}
            />

            <label htmlFor="pattern-slot">Each slot lasts (minutes)</label>
            <input
              id="pattern-slot"
              type="number"
              min={5}
              step={5}
              value={draft.slotMinutes}
              onChange={(e) => setDraft({ ...draft, slotMinutes: Number(e.target.value) || 30 })}
            />

            <label htmlFor="pattern-capacity">People per slot</label>
            <input
              id="pattern-capacity"
              type="number"
              min={1}
              value={draft.capacity}
              onChange={(e) => setDraft({ ...draft, capacity: Number(e.target.value) || 1 })}
            />

            <label htmlFor="pattern-type">Kind</label>
            <select
              id="pattern-type"
              value={draft.eventTypeId}
              onChange={(e) => setDraft({ ...draft, eventTypeId: e.target.value })}
            >
              {(typeData?.eventTypes ?? []).map((type) => (
                <option key={type.id} value={type.id}>{type.name}</option>
              ))}
            </select>

            <label htmlFor="pattern-venue">Place</label>
            <select
              id="pattern-venue"
              value={draft.venueId}
              onChange={(e) => setDraft({ ...draft, venueId: e.target.value })}
            >
              <option value="">No particular place</option>
              {(venueData?.admin.venues ?? []).map((venue) => (
                <option key={venue.id} value={venue.id}>{venue.name}</option>
              ))}
            </select>

            <label htmlFor="pattern-price">Cost note</label>
            <input
              id="pattern-price"
              value={draft.priceNote}
              placeholder="$40 for a half-hour, Venmo"
              onChange={(e) => setDraft({ ...draft, priceNote: e.target.value })}
            />

            <label htmlFor="pattern-from">Starting from</label>
            <input
              id="pattern-from"
              type="date"
              value={draft.effectiveFrom}
              onChange={(e) => setDraft({ ...draft, effectiveFrom: e.target.value })}
            />

            <label htmlFor="pattern-to">
              Until <span className="hint">optional — leave blank to keep going</span>
            </label>
            <input
              id="pattern-to"
              type="date"
              value={draft.effectiveTo}
              onChange={(e) => setDraft({ ...draft, effectiveTo: e.target.value })}
            />

            {draft.id && (
              <label className="checkbox">
                <input
                  type="checkbox"
                  checked={draft.active}
                  onChange={(e) => setDraft({ ...draft, active: e.target.checked })}
                />
                Active — turning this off retires its future slots
              </label>
            )}
          </div>

          <p className="hint">{describe(draft)}</p>

          <div className="editor-actions">
            <button type="button" disabled={busy} onClick={() => void save()}>
              {busy ? 'Saving…' : 'Save availability'}
            </button>
            <button type="button" className="link" onClick={() => setDraft(null)}>
              Cancel
            </button>
          </div>
        </div>
      )}

      {patterns.length === 0 ? (
        <p className="muted">No open availability yet.</p>
      ) : (
        <ul className="record-list">
          {patterns.map((pattern) => (
            <li key={pattern.id}>
              <div>
                <span className="record-title">{summarise(pattern)}</span>
                <p className="record-meta">
                  {pattern.eventType.name}
                  {pattern.venue && <> · {pattern.venue.name}</>}
                  {' · from '}{pattern.effectiveFrom}
                  {pattern.effectiveTo && <> until {pattern.effectiveTo}</>}
                </p>
              </div>
              <div className="record-badges">
                {!pattern.active && <span className="badge">Off</span>}
                <button
                  type="button"
                  className="link"
                  onClick={() =>
                    setDraft({
                      id: pattern.id,
                      eventTypeId: pattern.eventType.id,
                      venueId: pattern.venue?.id ?? '',
                      weekday: pattern.weekday,
                      startTime: pattern.startTime,
                      endTime: pattern.endTime,
                      slotMinutes: pattern.slotMinutes,
                      capacity: pattern.capacity,
                      priceNote: pattern.priceNote ?? '',
                      effectiveFrom: pattern.effectiveFrom,
                      effectiveTo: pattern.effectiveTo ?? '',
                      active: pattern.active,
                    })
                  }
                >
                  Edit
                </button>
                <button
                  type="button"
                  className="link danger"
                  disabled={busy}
                  onClick={() => void deletePattern({ variables: { id: pattern.id } })}
                >
                  Delete
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
