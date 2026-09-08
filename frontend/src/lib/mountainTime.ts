/**
 * The app has one time zone, America/Denver (plan §2), but `<input
 * type="datetime-local">` has no zone at all — the browser interprets what it
 * shows in *its own* zone. On a Mountain-time machine the two coincide and
 * everything looks right, which is what makes this worth doing explicitly: edit
 * an event from a laptop set to another zone and every time shifts silently.
 *
 * So the editor treats every datetime-local value as Mountain wall-clock and
 * converts here, rather than leaning on where the browser happens to be.
 */
const ZONE = 'America/Denver'

const PARTS = new Intl.DateTimeFormat('en-US', {
  timeZone: ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  hour12: false,
})

type Wall = { year: number; month: number; day: number; hour: number; minute: number; second: number }

function wallClockIn(instant: Date): Wall {
  const parts = PARTS.formatToParts(instant)
  const get = (type: Intl.DateTimeFormatPartTypes) =>
    Number(parts.find((part) => part.type === type)?.value ?? '0')

  // Intl renders midnight as hour 24 in some engines; normalize to 0.
  const hour = get('hour') % 24

  return {
    year: get('year'),
    month: get('month'),
    day: get('day'),
    hour,
    minute: get('minute'),
    second: get('second'),
  }
}

/** Minutes to add to a UTC instant to get Mountain wall-clock (negative). */
function offsetMinutes(instant: Date): number {
  const wall = wallClockIn(instant)
  const asUtc = Date.UTC(wall.year, wall.month - 1, wall.day, wall.hour, wall.minute, wall.second)

  return (asUtc - instant.getTime()) / 60_000
}

function pad(value: number): string {
  return String(value).padStart(2, '0')
}

/** An ISO instant → the "YYYY-MM-DDTHH:mm" a datetime-local input wants, in Mountain. */
export function toMountainInput(iso: string): string {
  const wall = wallClockIn(new Date(iso))

  return `${wall.year}-${pad(wall.month)}-${pad(wall.day)}T${pad(wall.hour)}:${pad(wall.minute)}`
}

/**
 * A datetime-local value, read as Mountain wall-clock → an ISO instant.
 *
 * Two passes: guess the instant by reading the value as UTC, look up the real
 * offset at that guess, then re-check, because the offset itself depends on the
 * date and the first guess can land on the wrong side of a transition.
 */
export function fromMountainInput(value: string): string | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(value)
  if (!match) return null

  const [, year, month, day, hour, minute] = match.map(Number) as [
    number, number, number, number, number, number,
  ]

  const asUtc = Date.UTC(year, month - 1, day, hour, minute)

  let instant = new Date(asUtc)
  for (let pass = 0; pass < 2; pass += 1) {
    instant = new Date(asUtc - offsetMinutes(instant) * 60_000)
  }

  return instant.toISOString()
}

/** "Tue 7 Apr 2026, 4:30 PM" in Mountain, whatever zone the reader is in. */
export function formatMountain(iso: string, options: Intl.DateTimeFormatOptions = {}): string {
  return new Date(iso).toLocaleString('en-US', {
    timeZone: ZONE,
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    ...options,
  })
}

export function formatMountainDate(iso: string): string {
  return formatMountain(iso, { hour: undefined, minute: undefined })
}

/** The label to show beside every time field, so the zone is never a guess. */
export const ZONE_LABEL = 'Mountain time'
