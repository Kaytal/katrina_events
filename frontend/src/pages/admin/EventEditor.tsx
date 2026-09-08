import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery } from '@apollo/client'
import { Link, useNavigate, useParams } from 'react-router-dom'
import OccurrenceList, { type OccurrenceAction } from '../../components/admin/OccurrenceList'
import RecurrenceEditor from '../../components/admin/RecurrenceEditor'
import {
  ADMIN_EVENTS_QUERY,
  ADMIN_EVENT_QUERY,
  ADMIN_VENUES_QUERY,
  CREATE_EVENT_MUTATION,
  CREATE_EXCEPTION_MUTATION,
  DELETE_EVENT_MUTATION,
  DELETE_EXCEPTION_MUTATION,
  EVENT_TYPES_QUERY,
  UPDATE_EVENT_MUTATION,
  type AdminEventData,
  type AdminEventVars,
  type AdminVenuesData,
  type CreateEventData,
  type CreateExceptionData,
  type DeleteEventData,
  type DeleteExceptionData,
  type EventTypesQueryData,
  type FieldError,
  type UpdateEventData,
} from '../../lib/queries'
import { ZONE_LABEL, fromMountainInput, toMountainInput } from '../../lib/mountainTime'
import { NO_RECURRENCE, buildRule, parseRule, type Recurrence } from '../../lib/recurrence'
import { useDocumentMeta } from '../../lib/useDocumentMeta'

type Draft = {
  title: string
  description: string
  eventTypeId: string
  venueId: string
  startsAt: string
  endsAt: string
  bookable: boolean
  capacity: string
  priceNote: string
  recurrenceUntil: string
  cancelled: boolean
}

const BLANK: Draft = {
  title: '',
  description: '',
  eventTypeId: '',
  venueId: '',
  startsAt: '',
  endsAt: '',
  bookable: false,
  capacity: '',
  priceNote: '',
  recurrenceUntil: '',
  cancelled: false,
}

// The occurrence list needs a window, and the server caps a range at 400 days
// (an unbounded weekly rule means the range is the only thing bounding the
// work). Three months back and nine forward is ~365 days: enough to see what
// was cancelled recently and what is coming, with headroom under the cap.
const MONTHS_BACK = 3
const MONTHS_FORWARD = 9

function occurrenceWindow() {
  const from = new Date()
  from.setMonth(from.getMonth() - MONTHS_BACK)
  const to = new Date()
  to.setMonth(to.getMonth() + MONTHS_FORWARD)

  return { from: from.toISOString(), to: to.toISOString() }
}

function messagesFor(errors: FieldError[], field: string): string[] {
  return errors.find((error) => error.field === field)?.messages ?? []
}

export default function EventEditor() {
  const { id } = useParams()
  const isNew = id === undefined
  const navigate = useNavigate()

  const [draft, setDraft] = useState<Draft>(BLANK)
  const [recurrence, setRecurrence] = useState<Recurrence>(NO_RECURRENCE)
  const [loadedId, setLoadedId] = useState<string | null>(null)
  const [saved, setSaved] = useState(false)

  const window = useMemo(occurrenceWindow, [])

  const { data: typeData } = useQuery<EventTypesQueryData>(EVENT_TYPES_QUERY)
  const { data: venueData } = useQuery<AdminVenuesData>(ADMIN_VENUES_QUERY)

  const { data, loading, error, refetch } = useQuery<AdminEventData, AdminEventVars>(
    ADMIN_EVENT_QUERY,
    {
      variables: { id: id ?? '', ...window },
      skip: isNew,
      fetchPolicy: 'cache-and-network',
    },
  )

  const event = data?.admin.event ?? null

  useEffect(() => {
    if (!event || loadedId === event.id) return

    setDraft({
      title: event.title,
      description: event.description ?? '',
      eventTypeId: event.eventType.id,
      venueId: event.venue?.id ?? '',
      startsAt: toMountainInput(event.startsAt),
      endsAt: toMountainInput(event.endsAt),
      bookable: event.bookable,
      capacity: event.capacity === null ? '' : String(event.capacity),
      priceNote: event.priceNote ?? '',
      recurrenceUntil: event.recurrenceUntil ? toMountainInput(event.recurrenceUntil) : '',
      cancelled: event.status === 'cancelled',
    })
    setRecurrence(parseRule(event.recurrenceRule))
    setLoadedId(event.id)
  }, [event, loadedId])

  // Default a new event's type once the list arrives, so the select is never
  // sitting on a blank that fails validation.
  useEffect(() => {
    if (!isNew || draft.eventTypeId !== '') return

    const first = typeData?.eventTypes[0]
    if (first) setDraft((current) => ({ ...current, eventTypeId: first.id }))
  }, [isNew, draft.eventTypeId, typeData])

  const [createEvent, createState] = useMutation<CreateEventData>(CREATE_EVENT_MUTATION, {
    refetchQueries: [ADMIN_EVENTS_QUERY],
    onError: () => undefined,
  })
  const [updateEvent, updateState] = useMutation<UpdateEventData>(UPDATE_EVENT_MUTATION, {
    onError: () => undefined,
  })
  const [deleteEvent, deleteState] = useMutation<DeleteEventData>(DELETE_EVENT_MUTATION, {
    refetchQueries: [ADMIN_EVENTS_QUERY],
    onError: () => undefined,
  })
  const [createException, exceptionState] = useMutation<CreateExceptionData>(
    CREATE_EXCEPTION_MUTATION,
    { onError: () => undefined },
  )
  const [deleteException, restoreState] = useMutation<DeleteExceptionData>(
    DELETE_EXCEPTION_MUTATION,
    { onError: () => undefined },
  )

  const saving = createState.loading || updateState.loading
  const occurrenceBusy = exceptionState.loading || restoreState.loading

  const errors: FieldError[] =
    createState.data?.createEvent?.errors ?? updateState.data?.updateEvent?.errors ?? []

  const exceptionErrors = exceptionState.data?.createEventException?.errors ?? []

  useDocumentMeta(isNew ? 'New event' : `Editing ${event?.title ?? ''}`, null)

  const save = async () => {
    setSaved(false)

    const startsAt = fromMountainInput(draft.startsAt)
    const endsAt = fromMountainInput(draft.endsAt)
    if (!startsAt || !endsAt) return

    const rule = buildRule(recurrence)
    const shared = {
      eventTypeId: draft.eventTypeId,
      venueId: draft.venueId === '' ? null : draft.venueId,
      title: draft.title,
      description: draft.description.trim() === '' ? null : draft.description,
      startsAt,
      endsAt,
      recurrenceRule: rule,
      recurrenceUntil:
        rule && draft.recurrenceUntil !== '' ? fromMountainInput(draft.recurrenceUntil) : null,
      bookable: draft.bookable,
      capacity: draft.bookable && draft.capacity !== '' ? Number(draft.capacity) : null,
      priceNote: draft.priceNote.trim() === '' ? null : draft.priceNote,
    }

    if (isNew) {
      const result = await createEvent({ variables: shared })
      const created = result.data?.createEvent
      if ((created?.errors ?? []).length === 0 && created?.event) {
        navigate(`/admin/events/${created.event.id}`, { replace: true })
      }
      return
    }

    const result = await updateEvent({
      variables: {
        id: id ?? '',
        ...shared,
        status: draft.cancelled ? 'cancelled' : 'scheduled',
        clearVenue: draft.venueId === '',
        clearRecurrence: rule === null,
      },
    })

    if ((result.data?.updateEvent?.errors ?? []).length === 0) {
      setSaved(true)
      setLoadedId(null)
      await refetch()
    }
  }

  const runOccurrenceAction = async (action: OccurrenceAction) => {
    if (action.kind === 'restore') {
      await deleteException({ variables: { id: action.exceptionId } })
    } else if (action.kind === 'skip') {
      await createException({
        variables: { eventId: id ?? '', originalDate: action.originalDate, action: 'skip' },
      })
    } else {
      await createException({
        variables: {
          eventId: id ?? '',
          originalDate: action.originalDate,
          action: 'move',
          startsAt: action.startsAt,
          endsAt: action.endsAt,
        },
      })
    }

    await refetch()
  }

  const remove = async () => {
    const result = await deleteEvent({ variables: { id: id ?? '' } })
    if (result.data?.deleteEvent?.deletedId) navigate('/admin/events', { replace: true })
  }

  if (!isNew && loading && !event) {
    return <p className="notice" role="status">Loading…</p>
  }

  if (error) {
    return (
      <div className="notice notice--bad" role="alert">
        <h1>Couldn&rsquo;t load that event</h1>
        <p>{error.message}</p>
        <p><Link to="/admin/events">Back to events</Link></p>
      </div>
    )
  }

  const titleErrors = messagesFor(errors, 'title')
  const capacityErrors = messagesFor(errors, 'capacity')
  const endErrors = messagesFor(errors, 'endsAt')
  const ruleErrors = messagesFor(errors, 'recurrenceRule')

  return (
    <div className="admin">
      <div className="admin-head">
        <div>
          <h1>{isNew ? 'New event' : draft.title || 'Event'}</h1>
          <p className="muted">
            <Link to="/admin/events">← Events</Link> · all times {ZONE_LABEL}
          </p>
        </div>
        {draft.cancelled && <span className="badge">Cancelled</span>}
      </div>

      <form
        className="editor"
        onSubmit={(submitEvent) => {
          submitEvent.preventDefault()
          void save()
        }}
      >
        {saved && (
          <p className="form-ok" role="status">
            Saved.
          </p>
        )}
        {ruleErrors.map((message) => (
          <p className="form-error" role="alert" key={message}>
            Repeat rule {message}
          </p>
        ))}

        <div className="editor-fields">
          <label htmlFor="title">Title</label>
          <input
            id="title"
            value={draft.title}
            aria-invalid={titleErrors.length > 0}
            onChange={(changeEvent) => setDraft({ ...draft, title: changeEvent.target.value })}
          />
          {titleErrors.map((message) => (
            <p className="field-error" key={message}>Title {message}</p>
          ))}

          <label htmlFor="eventType">Kind</label>
          <select
            id="eventType"
            value={draft.eventTypeId}
            onChange={(changeEvent) => setDraft({ ...draft, eventTypeId: changeEvent.target.value })}
          >
            {(typeData?.eventTypes ?? []).map((type) => (
              <option key={type.id} value={type.id}>{type.name}</option>
            ))}
          </select>

          <label htmlFor="venue">Place</label>
          <select
            id="venue"
            value={draft.venueId}
            onChange={(changeEvent) => setDraft({ ...draft, venueId: changeEvent.target.value })}
          >
            <option value="">No particular place</option>
            {(venueData?.admin.venues ?? []).map((venue) => (
              <option key={venue.id} value={venue.id}>{venue.name}</option>
            ))}
          </select>
          <p className="hint">
            Somewhere new? <Link to="/admin/venues">Add a place</Link> first.
          </p>

          <label htmlFor="startsAt">Starts ({ZONE_LABEL})</label>
          <input
            id="startsAt"
            type="datetime-local"
            value={draft.startsAt}
            onChange={(changeEvent) => setDraft({ ...draft, startsAt: changeEvent.target.value })}
          />

          <label htmlFor="endsAt">Ends ({ZONE_LABEL})</label>
          <input
            id="endsAt"
            type="datetime-local"
            value={draft.endsAt}
            aria-invalid={endErrors.length > 0}
            onChange={(changeEvent) => setDraft({ ...draft, endsAt: changeEvent.target.value })}
          />
          {endErrors.map((message) => (
            <p className="field-error" key={message}>End time {message}</p>
          ))}

          <label htmlFor="description">Description</label>
          <textarea
            id="description"
            className="short"
            value={draft.description}
            onChange={(changeEvent) => setDraft({ ...draft, description: changeEvent.target.value })}
          />
        </div>

        <RecurrenceEditor value={recurrence} onChange={setRecurrence} />

        {recurrence.frequency !== 'none' && (
          <div className="editor-fields">
            <label htmlFor="recurrenceUntil">
              Stop repeating after <span className="hint">optional</span>
            </label>
            <input
              id="recurrenceUntil"
              type="datetime-local"
              value={draft.recurrenceUntil}
              onChange={(changeEvent) =>
                setDraft({ ...draft, recurrenceUntil: changeEvent.target.value })
              }
            />
          </div>
        )}

        <fieldset className="recurrence">
          <legend>Requests</legend>

          <label className="checkbox">
            <input
              type="checkbox"
              checked={draft.bookable}
              onChange={(changeEvent) => setDraft({ ...draft, bookable: changeEvent.target.checked })}
            />
            People can request a place
          </label>
          <p className="hint">
            Leave this off for a performance or notice — it appears on the
            calendar with nothing to sign up for.
          </p>

          {draft.bookable && (
            <div className="editor-fields">
              <label htmlFor="capacity">How many people fit</label>
              <input
                id="capacity"
                type="number"
                min={1}
                value={draft.capacity}
                aria-invalid={capacityErrors.length > 0}
                onChange={(changeEvent) => setDraft({ ...draft, capacity: changeEvent.target.value })}
              />
              {capacityErrors.map((message) => (
                <p className="field-error" key={message}>How many people fit {message}</p>
              ))}

              <label htmlFor="priceNote">Cost note</label>
              <input
                id="priceNote"
                value={draft.priceNote}
                placeholder="$15 per class, Venmo at the door"
                onChange={(changeEvent) => setDraft({ ...draft, priceNote: changeEvent.target.value })}
              />
              <p className="hint">
                Shown on the calendar. The website never takes payment.
              </p>
            </div>
          )}
        </fieldset>

        {!isNew && (
          <fieldset className="recurrence">
            <legend>Status</legend>
            <label className="checkbox">
              <input
                type="checkbox"
                checked={draft.cancelled}
                onChange={(changeEvent) => setDraft({ ...draft, cancelled: changeEvent.target.checked })}
              />
              Cancelled — hide the whole event from the calendar
            </label>
            <p className="hint">
              To call off a single session instead, use the list below.
            </p>
          </fieldset>
        )}

        <div className="editor-actions">
          <button type="submit" disabled={saving}>
            {saving ? 'Saving…' : isNew ? 'Create event' : 'Save changes'}
          </button>
          {!isNew && (
            <button
              type="button"
              className="link danger"
              disabled={deleteState.loading}
              onClick={() => void remove()}
            >
              Delete this event
            </button>
          )}
        </div>
      </form>

      {!isNew && event && (
        <section className="sessions">
          <h2>Sessions</h2>
          <p className="muted">
            Call off or move one session without touching the rest. A cancelled
            session stays listed here so you can put it back; visitors never see
            it.
          </p>

          {exceptionErrors.map((fieldError) => (
            <p className="form-error" role="alert" key={fieldError.field}>
              {fieldError.messages.join(', ')}
            </p>
          ))}

          <OccurrenceList
            occurrences={event.occurrences}
            exceptions={event.exceptions}
            busy={occurrenceBusy}
            onAction={(action) => void runOccurrenceAction(action)}
          />
        </section>
      )}
    </div>
  )
}
