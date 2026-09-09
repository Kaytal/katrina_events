/**
 * Composes and reads the RFC-5545 RRULE the API stores. She never types one:
 * the editor offers a frequency and, for weekly, a set of weekdays.
 *
 * Sub-daily frequencies are absent on purpose. An occurrence is identified by
 * its local date on the server, so an event can occur at most once a day; the
 * API rejects FREQ=HOURLY and BYHOUR, and offering them here would only produce
 * a form that fails on save.
 */
export type Frequency = 'none' | 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'YEARLY'

// `label` is for the compact day toggles; `plural` is for prose, because
// "Thu" + "s" reads as "Thus".
export const WEEKDAYS = [
  { code: 'SU', label: 'Sun', plural: 'Sundays' },
  { code: 'MO', label: 'Mon', plural: 'Mondays' },
  { code: 'TU', label: 'Tue', plural: 'Tuesdays' },
  { code: 'WE', label: 'Wed', plural: 'Wednesdays' },
  { code: 'TH', label: 'Thu', plural: 'Thursdays' },
  { code: 'FR', label: 'Fri', plural: 'Fridays' },
  { code: 'SA', label: 'Sat', plural: 'Saturdays' },
] as const

export const FREQUENCY_LABELS: Record<Frequency, string> = {
  none: 'Does not repeat',
  DAILY: 'Every day',
  WEEKLY: 'Every week',
  MONTHLY: 'Every month',
  YEARLY: 'Every year',
}

export type Recurrence = {
  frequency: Frequency
  weekdays: string[]
  interval: number
}

export const NO_RECURRENCE: Recurrence = { frequency: 'none', weekdays: [], interval: 1 }

export function parseRule(rule: string | null): Recurrence {
  if (!rule) return NO_RECURRENCE

  const parts = new Map(
    rule
      .split(';')
      .map((part) => part.split('='))
      .filter((pair): pair is [string, string] => pair.length === 2)
      .map(([key, value]) => [key.toUpperCase(), value.toUpperCase()]),
  )

  const frequency = parts.get('FREQ')
  if (frequency !== 'DAILY' && frequency !== 'WEEKLY' && frequency !== 'MONTHLY' && frequency !== 'YEARLY') {
    return NO_RECURRENCE
  }

  return {
    frequency,
    weekdays: parts.get('BYDAY')?.split(',').filter(Boolean) ?? [],
    interval: Number(parts.get('INTERVAL') ?? 1) || 1,
  }
}

export function buildRule(recurrence: Recurrence): string | null {
  if (recurrence.frequency === 'none') return null

  const parts = [`FREQ=${recurrence.frequency}`]

  if (recurrence.interval > 1) parts.push(`INTERVAL=${recurrence.interval}`)
  if (recurrence.frequency === 'WEEKLY' && recurrence.weekdays.length > 0) {
    parts.push(`BYDAY=${recurrence.weekdays.join(',')}`)
  }

  return parts.join(';')
}

/** A sentence she can check at a glance, rather than an RRULE she has to trust. */
export function describeRecurrence(recurrence: Recurrence): string {
  if (recurrence.frequency === 'none') return 'Happens once.'

  const every =
    recurrence.interval > 1
      ? `Every ${recurrence.interval} ${{ DAILY: 'days', WEEKLY: 'weeks', MONTHLY: 'months', YEARLY: 'years' }[recurrence.frequency]}`
      : { DAILY: 'Every day', WEEKLY: 'Every week', MONTHLY: 'Every month', YEARLY: 'Every year' }[
          recurrence.frequency
        ]

  if (recurrence.frequency === 'WEEKLY' && recurrence.weekdays.length > 0) {
    const names = recurrence.weekdays
      .map((code) => WEEKDAYS.find((day) => day.code === code)?.label ?? code)
      .join(', ')

    return `${every} on ${names}.`
  }

  return `${every}, on the same day as the start date.`
}
