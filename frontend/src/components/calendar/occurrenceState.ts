import type { EventOccurrence } from '../../lib/queries'

/**
 * The calendar has to distinguish these at a glance (plan §5). Colour is
 * already carrying event type, so state is conveyed with a label and an icon
 * instead — someone clicking a festival appearance expecting to sign up is the
 * failure this exists to prevent.
 *
 * `open` is as far as Phase 5 goes: "full", "closed", and "pending your
 * request" need time_blocks (Phase 7) and booking_requests (Phase 8), and
 * inventing them here would mean a badge that lies.
 */
export type OccurrenceState = 'announcement' | 'open'

export function stateOf(occurrence: EventOccurrence): OccurrenceState {
  return occurrence.bookable ? 'open' : 'announcement'
}

export const STATE_LABELS: Record<OccurrenceState, string> = {
  announcement: 'Come and watch',
  open: 'Requestable',
}

export const STATE_ICONS: Record<OccurrenceState, string> = {
  announcement: '◆',
  open: '●',
}
