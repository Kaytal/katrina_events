import { useQuery } from '@apollo/client'
import { Link } from 'react-router-dom'
import { ADMIN_EVENTS_QUERY, type AdminEventsData } from '../../lib/queries'
import { describeRecurrence, parseRule } from '../../lib/recurrence'
import { formatMountain } from '../../lib/mountainTime'
import { useDocumentMeta } from '../../lib/useDocumentMeta'

export default function EventList() {
  const { data, loading, error } = useQuery<AdminEventsData>(ADMIN_EVENTS_QUERY, {
    fetchPolicy: 'cache-and-network',
  })

  useDocumentMeta('Events', null)

  if (loading && !data) return <p className="notice" role="status">Loading…</p>

  if (error) {
    return (
      <div className="notice notice--bad" role="alert">
        <h1>Couldn&rsquo;t load your events</h1>
        <p>{error.message}</p>
      </div>
    )
  }

  const events = data?.admin.events ?? []

  return (
    <div className="admin">
      <div className="admin-head">
        <div>
          <h1>Events</h1>
          <p className="muted">
            Everything on the calendar. An announcement is an event nobody can
            request — a performance to come and watch.
          </p>
        </div>
        <Link className="button-link" to="/admin/events/new">
          Add an event
        </Link>
      </div>

      {events.length === 0 ? (
        <p className="muted">Nothing on the calendar yet.</p>
      ) : (
        <ul className="record-list">
          {events.map((event) => (
            <li key={event.id}>
              <div>
                <Link to={`/admin/events/${event.id}`} className="record-title">
                  {event.title}
                </Link>
                <p className="record-meta">
                  {formatMountain(event.startsAt)} · {event.eventType.name}
                  {event.venue && <> · {event.venue.name}</>}
                </p>
                <p className="record-meta">
                  {describeRecurrence(parseRule(event.recurrenceRule))}
                  {event.bookable
                    ? ` Requestable, room for ${event.capacity}.`
                    : ' Announcement — nothing to request.'}
                </p>
              </div>
              <div className="record-badges">
                {event.status === 'cancelled' && <span className="badge">Cancelled</span>}
                <span className={event.bookable ? 'badge badge--live' : 'badge'}>
                  {event.bookable ? 'Requestable' : 'Announcement'}
                </span>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
