import type { EventOccurrence, TimeBlock } from '../../lib/queries'

/**
 * The four states the calendar has to distinguish at a glance (plan §5).
 * Colour is already carrying event type, so state is conveyed with an icon and
 * a label — someone clicking a festival appearance expecting to sign up is the
 * failure this exists to prevent.
 *
 * "pending" needs booking_requests and arrives in Phase 8. Rendering it now
 * would mean a badge that lies.
 */
export type OccurrenceState = 'announcement' | 'open' | 'full' | 'closed'

export function stateOfBlock(block: Pick<TimeBlock, 'status' | 'spotsRemaining'>): OccurrenceState {
  if (block.status === 'closed') return 'closed'
  if (block.status === 'full') return 'full'
  if (block.spotsRemaining !== null && block.spotsRemaining <= 0) return 'full'

  return 'open'
}

export function stateOf(occurrence: EventOccurrence): OccurrenceState {
  if (!occurrence.bookable) return 'announcement'

  // Bookable but no slot yet: materialization has not reached it, or it is in
  // the past. Either way it cannot be requested, so say so rather than inviting
  // a request that would fail.
  if (!occurrence.timeBlock) return 'closed'

  return stateOfBlock(occurrence.timeBlock)
}

export const STATE_LABELS: Record<OccurrenceState, string> = {
  announcement: 'Come and watch',
  open: 'Places available',
  full: 'Full',
  closed: 'Not open for requests',
}

export const STATE_ICONS: Record<OccurrenceState, string> = {
  announcement: '◆',
  open: '●',
  full: '◼',
  closed: '○',
}
