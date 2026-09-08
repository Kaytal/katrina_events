import { useCallback, useRef, useState } from 'react'
import { useQuery } from '@apollo/client'
import FullCalendar from '@fullcalendar/react'
import dayGridPlugin from '@fullcalendar/daygrid'
import listPlugin from '@fullcalendar/list'
import type { DatesSetArg, EventClickArg } from '@fullcalendar/core'
import {
  EVENTS_QUERY,
  EVENT_TYPES_QUERY,
  type EventOccurrence,
  type EventTypesQueryData,
  type EventsQueryData,
  type EventsQueryVars,
} from '../../lib/queries'
import EventDetail from './EventDetail'
import { STATE_ICONS, STATE_LABELS, stateOf } from './occurrenceState'

// Month grid reads well on a desktop and terribly on a phone, where a list of
// what is coming up is what someone actually wants.
function initialView(): 'dayGridMonth' | 'listMonth' {
  if (typeof window === 'undefined') return 'dayGridMonth'
  return window.matchMedia('(max-width: 40rem)').matches ? 'listMonth' : 'dayGridMonth'
}

export default function Calendar() {
  // FullCalendar tells us the visible window; that drives the query, so paging
  // to another month refetches rather than showing an empty grid.
  const [range, setRange] = useState<EventsQueryVars | null>(null)
  const [selected, setSelected] = useState<EventOccurrence | null>(null)
  const view = useRef(initialView())

  const { data, previousData, loading, error } = useQuery<EventsQueryData, EventsQueryVars>(
    EVENTS_QUERY,
    {
      variables: range ?? { from: '', to: '' },
      skip: range === null,
    },
  )

  const { data: typeData } = useQuery<EventTypesQueryData>(EVENT_TYPES_QUERY)

  const handleDatesSet = useCallback((arg: DatesSetArg) => {
    setRange({ from: arg.start.toISOString(), to: arg.end.toISOString() })
    // Paging away leaves the open panel describing an occurrence that is no
    // longer on screen — a September class shown under an October grid.
    setSelected(null)
  }, [])

  const handleEventClick = useCallback((arg: EventClickArg) => {
    // Clicking must not navigate — the detail panel is the whole interaction.
    arg.jsEvent.preventDefault()
    setSelected((arg.event.extendedProps as { occurrence: EventOccurrence }).occurrence)
  }, [])

  // Keep the previous window's events on screen while the next one loads,
  // rather than blanking the calendar on every page.
  const occurrences = (data ?? previousData)?.events ?? []

  const fcEvents = occurrences.map((occurrence) => ({
    id: occurrence.id,
    title: occurrence.title,
    start: occurrence.startsAt,
    end: occurrence.endsAt,
    allDay: occurrence.allDay,
    backgroundColor: occurrence.eventType.color,
    borderColor: occurrence.eventType.color,
    extendedProps: { occurrence },
  }))

  return (
    <section className="calendar" aria-label="Calendar">
      {error && (
        <p className="notice notice--bad" role="alert">
          The calendar couldn&rsquo;t load. {error.message}
        </p>
      )}

      <div className={loading ? 'calendar-grid is-loading' : 'calendar-grid'}>
        <FullCalendar
          plugins={[dayGridPlugin, listPlugin]}
          initialView={view.current}
          headerToolbar={{
            left: 'prev,next today',
            center: 'title',
            right: 'dayGridMonth,listMonth',
          }}
          buttonText={{ today: 'Today', month: 'Month', list: 'List' }}
          events={fcEvents}
          datesSet={handleDatesSet}
          eventClick={handleEventClick}
          height="auto"
          firstDay={0}
          eventTimeFormat={{ hour: 'numeric', minute: '2-digit', meridiem: 'short' }}
          noEventsText="Nothing on the calendar for this month."
          views={{
            // A month cell is ~120px wide. Showing "4:30pm - 5:15pm" there
            // leaves nothing for the title, which is the part that tells
            // someone what the event actually is. The end time belongs in the
            // list view and the detail panel, where there is room for it.
            dayGridMonth: { displayEventEnd: false },
            listMonth: { displayEventEnd: true },
          }}
        />
      </div>

      {selected && <EventDetail occurrence={selected} onClose={() => setSelected(null)} />}

      <div className="legend">
        <h2>What&rsquo;s what</h2>

        <ul className="legend-states">
          {(['open', 'announcement'] as const).map((state) => (
            <li key={state}>
              <span aria-hidden="true">{STATE_ICONS[state]}</span> {STATE_LABELS[state]}
            </li>
          ))}
        </ul>

        <ul className="legend-types">
          {(typeData?.eventTypes ?? []).map((type) => (
            <li key={type.id}>
              <span className="swatch" style={{ backgroundColor: type.color }} aria-hidden="true" />
              {type.name}
            </li>
          ))}
        </ul>

        <p className="muted">
          Colour shows the kind of event. <strong>Requesting is not booking</strong> —
          Katrina confirms each request by email.
        </p>
      </div>
    </section>
  )
}
