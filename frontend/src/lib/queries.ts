import { gql } from '@apollo/client'

/**
 * Types are hand-written to match the schema. Worth revisiting once the schema
 * grows past a handful of types — graphql-codegen would generate these from
 * `bin/rails graphql:dump_schema` output instead.
 */
export type Page = {
  __typename?: 'Page'
  slug: string
  title: string
  body: string
  metaDescription: string | null
  published: boolean
  publishedAt: string | null
  updatedAt: string
}

/**
 * The public query selects less than the admin one does. Spelling that out
 * keeps the types honest about what each response actually contains, rather
 * than claiming a field the server was never asked for.
 */
export type PageContent = Pick<
  Page,
  'slug' | 'title' | 'body' | 'metaDescription' | 'publishedAt' | 'updatedAt'
>

export type PageQueryData = { page: PageContent | null }
export type PageQueryVars = { slug: string }

export const PAGE_QUERY = gql`
  query Page($slug: String!) {
    page(slug: $slug) {
      slug
      title
      body
      metaDescription
      publishedAt
      updatedAt
    }
  }
`

export type Health = {
  __typename?: 'Health'
  status: string
  service: string
  environment: string
  time: string
  timeZone: string
  database: string
}

export type HealthQueryData = { health: Health }

export const HEALTH_QUERY = gql`
  query Health {
    health {
      status
      service
      environment
      time
      timeZone
      database
    }
  }
`

export type User = {
  __typename?: 'User'
  id: string
  email: string
  name: string
  role: string
}

export type MeQueryData = { me: User | null }

export const ME_QUERY = gql`
  query Me {
    me {
      id
      email
      name
      role
    }
  }
`

export type LoginData = { login: { token: string; user: User } | null }
export type LoginVars = { email: string; password: string }

export const LOGIN_MUTATION = gql`
  mutation Login($email: String!, $password: String!) {
    login(input: { email: $email, password: $password }) {
      token
      user {
        id
        email
        name
        role
      }
    }
  }
`

export type LogoutData = { logout: { success: boolean } | null }

export const LOGOUT_MUTATION = gql`
  mutation Logout {
    logout(input: {}) {
      success
    }
  }
`

export type FieldError = { field: string; messages: string[] }

export type AdminPagesData = { admin: { pages: Page[] } }

export const ADMIN_PAGES_QUERY = gql`
  query AdminPages {
    admin {
      pages {
        slug
        title
        published
        publishedAt
        updatedAt
      }
    }
  }
`

export type AdminPageData = { admin: { page: Page | null } }
export type AdminPageVars = { slug: string }

export const ADMIN_PAGE_QUERY = gql`
  query AdminPage($slug: String!) {
    admin {
      page(slug: $slug) {
        slug
        title
        body
        metaDescription
        published
        publishedAt
        updatedAt
      }
    }
  }
`

export type UpdatePageData = {
  updatePage: { page: Page | null; errors: FieldError[] } | null
}

export type UpdatePageVars = {
  slug: string
  title?: string
  body?: string
  metaDescription?: string | null
  published?: boolean
}

export const UPDATE_PAGE_MUTATION = gql`
  mutation UpdatePage(
    $slug: String!
    $title: String
    $body: String
    $metaDescription: String
    $published: Boolean
  ) {
    updatePage(
      input: {
        slug: $slug
        title: $title
        body: $body
        metaDescription: $metaDescription
        published: $published
      }
    ) {
      page {
        slug
        title
        body
        metaDescription
        published
        publishedAt
        updatedAt
      }
      errors {
        field
        messages
      }
    }
  }
`

export type EventType = {
  __typename?: 'EventType'
  id: string
  name: string
  slug: string
  color: string
  description: string | null
}

export type Venue = {
  __typename?: 'Venue'
  id: string
  name: string
  address: string | null
  url: string | null
}

export type EventOccurrence = {
  __typename?: 'EventOccurrence'
  id: string
  eventId: string
  title: string
  description: string | null
  startsAt: string
  endsAt: string
  allDay: boolean
  bookable: boolean
  capacity: number | null
  priceNote: string | null
  recurring: boolean
  moved: boolean
  originalDate: string
  spotsRemaining: number | null
  timeBlock: Pick<
    TimeBlock,
    'id' | 'status' | 'capacity' | 'spotsRemaining' | 'priceNote'
  > | null
  eventType: EventType
  venue: Venue | null
}

export type EventsQueryData = { events: EventOccurrence[] }
export type EventsQueryVars = { from: string; to: string }

export const EVENTS_QUERY = gql`
  query Events($from: ISO8601DateTime!, $to: ISO8601DateTime!) {
    events(from: $from, to: $to) {
      id
      eventId
      title
      description
      startsAt
      endsAt
      allDay
      bookable
      capacity
      priceNote
      recurring
      moved
      originalDate
      spotsRemaining
      timeBlock {
        id
        status
        capacity
        spotsRemaining
        priceNote
      }
      eventType {
        id
        name
        slug
        color
      }
      venue {
        id
        name
        address
        url
      }
    }
  }
`

export type EventTypesQueryData = { eventTypes: EventType[] }

export const EVENT_TYPES_QUERY = gql`
  query EventTypes {
    eventTypes {
      id
      name
      slug
      color
      description
    }
  }
`

// --- Admin: events ---------------------------------------------------------

export type EventException = {
  __typename?: 'EventException'
  id: string
  originalDate: string
  action: 'skip' | 'move'
  startsAt: string | null
  endsAt: string | null
}

export type AdminOccurrence = {
  __typename?: 'EventOccurrence'
  id: string
  originalDate: string
  startsAt: string
  endsAt: string
  skipped: boolean
  moved: boolean
}

export type AdminEvent = {
  __typename?: 'AdminEvent'
  id: string
  title: string
  description: string | null
  startsAt: string
  endsAt: string
  allDay: boolean
  recurrenceRule: string | null
  recurrenceUntil: string | null
  status: string
  bookable: boolean
  capacity: number | null
  priceNote: string | null
  recurring: boolean
  eventType: EventType
  venue: Venue | null
}

const ADMIN_EVENT_FIELDS = `
  id
  title
  description
  startsAt
  endsAt
  allDay
  recurrenceRule
  recurrenceUntil
  status
  bookable
  capacity
  priceNote
  recurring
  eventType { id name slug color }
  venue { id name address url }
`

export type AdminEventsData = { admin: { events: AdminEvent[] } }

export const ADMIN_EVENTS_QUERY = gql`
  query AdminEvents {
    admin {
      events {
        ${ADMIN_EVENT_FIELDS}
      }
    }
  }
`

export type AdminEventData = {
  admin: {
    event: (AdminEvent & { exceptions: EventException[]; occurrences: AdminOccurrence[] }) | null
  }
}
export type AdminEventVars = { id: string; from: string; to: string }

export const ADMIN_EVENT_QUERY = gql`
  query AdminEvent($id: ID!, $from: ISO8601DateTime!, $to: ISO8601DateTime!) {
    admin {
      event(id: $id) {
        ${ADMIN_EVENT_FIELDS}
        exceptions { id originalDate action startsAt endsAt }
        occurrences(from: $from, to: $to) {
          id
          originalDate
          startsAt
          endsAt
          skipped
          moved
        }
      }
    }
  }
`

export type EventInput = {
  eventTypeId: string
  venueId?: string | null
  title: string
  description?: string | null
  startsAt: string
  endsAt: string
  recurrenceRule?: string | null
  recurrenceUntil?: string | null
  bookable?: boolean
  capacity?: number | null
  priceNote?: string | null
}

export type CreateEventData = {
  createEvent: { event: AdminEvent | null; errors: FieldError[] } | null
}

export const CREATE_EVENT_MUTATION = gql`
  mutation CreateEvent(
    $eventTypeId: ID!
    $venueId: ID
    $title: String!
    $description: String
    $startsAt: ISO8601DateTime!
    $endsAt: ISO8601DateTime!
    $recurrenceRule: String
    $recurrenceUntil: ISO8601DateTime
    $bookable: Boolean
    $capacity: Int
    $priceNote: String
  ) {
    createEvent(
      input: {
        eventTypeId: $eventTypeId
        venueId: $venueId
        title: $title
        description: $description
        startsAt: $startsAt
        endsAt: $endsAt
        recurrenceRule: $recurrenceRule
        recurrenceUntil: $recurrenceUntil
        bookable: $bookable
        capacity: $capacity
        priceNote: $priceNote
      }
    ) {
      event {
        ${ADMIN_EVENT_FIELDS}
      }
      errors { field messages }
    }
  }
`

export type UpdateEventVars = Partial<EventInput> & {
  id: string
  status?: string
  clearVenue?: boolean
  clearRecurrence?: boolean
}

export type UpdateEventData = {
  updateEvent: { event: AdminEvent | null; errors: FieldError[] } | null
}

export const UPDATE_EVENT_MUTATION = gql`
  mutation UpdateEvent(
    $id: ID!
    $eventTypeId: ID
    $venueId: ID
    $title: String
    $description: String
    $startsAt: ISO8601DateTime
    $endsAt: ISO8601DateTime
    $recurrenceRule: String
    $recurrenceUntil: ISO8601DateTime
    $status: String
    $bookable: Boolean
    $capacity: Int
    $priceNote: String
    $clearVenue: Boolean
    $clearRecurrence: Boolean
  ) {
    updateEvent(
      input: {
        id: $id
        eventTypeId: $eventTypeId
        venueId: $venueId
        title: $title
        description: $description
        startsAt: $startsAt
        endsAt: $endsAt
        recurrenceRule: $recurrenceRule
        recurrenceUntil: $recurrenceUntil
        status: $status
        bookable: $bookable
        capacity: $capacity
        priceNote: $priceNote
        clearVenue: $clearVenue
        clearRecurrence: $clearRecurrence
      }
    ) {
      event {
        ${ADMIN_EVENT_FIELDS}
      }
      errors { field messages }
    }
  }
`

export type DeleteEventData = { deleteEvent: { deletedId: string | null } | null }

export const DELETE_EVENT_MUTATION = gql`
  mutation DeleteEvent($id: ID!) {
    deleteEvent(input: { id: $id }) {
      deletedId
      errors { field messages }
    }
  }
`

export type ExceptionVars = {
  eventId: string
  originalDate: string
  action: 'skip' | 'move'
  startsAt?: string | null
  endsAt?: string | null
}

export type CreateExceptionData = {
  createEventException: { exception: EventException | null; errors: FieldError[] } | null
}

export const CREATE_EXCEPTION_MUTATION = gql`
  mutation CreateEventException(
    $eventId: ID!
    $originalDate: ISO8601Date!
    $action: String!
    $startsAt: ISO8601DateTime
    $endsAt: ISO8601DateTime
  ) {
    createEventException(
      input: {
        eventId: $eventId
        originalDate: $originalDate
        action: $action
        startsAt: $startsAt
        endsAt: $endsAt
      }
    ) {
      exception { id originalDate action startsAt endsAt }
      errors { field messages }
    }
  }
`

export type DeleteExceptionData = {
  deleteEventException: { deletedId: string | null } | null
}

export const DELETE_EXCEPTION_MUTATION = gql`
  mutation DeleteEventException($id: ID!) {
    deleteEventException(input: { id: $id }) {
      deletedId
      errors { field messages }
    }
  }
`

// --- Admin: venues ---------------------------------------------------------

export type AdminVenuesData = { admin: { venues: Venue[] } }

export const ADMIN_VENUES_QUERY = gql`
  query AdminVenues {
    admin {
      venues { id name address url }
    }
  }
`

export type VenueMutationData = {
  createVenue?: { venue: Venue | null; errors: FieldError[] } | null
  updateVenue?: { venue: Venue | null; errors: FieldError[] } | null
}

export const CREATE_VENUE_MUTATION = gql`
  mutation CreateVenue($name: String!, $address: String, $url: String, $notes: String) {
    createVenue(input: { name: $name, address: $address, url: $url, notes: $notes }) {
      venue { id name address url }
      errors { field messages }
    }
  }
`

export const UPDATE_VENUE_MUTATION = gql`
  mutation UpdateVenue($id: ID!, $name: String, $address: String, $url: String, $notes: String) {
    updateVenue(input: { id: $id, name: $name, address: $address, url: $url, notes: $notes }) {
      venue { id name address url }
      errors { field messages }
    }
  }
`

// --- Time blocks -----------------------------------------------------------

export type TimeBlock = {
  __typename?: 'TimeBlock'
  id: string
  startsAt: string
  endsAt: string
  status: 'open' | 'closed' | 'full'
  capacity: number | null
  spotsRemaining: number | null
  priceNote: string | null
  standalone: boolean
  eventType: EventType
  venue: Venue | null
}

export type TimeBlocksQueryData = { timeBlocks: TimeBlock[] }

export const TIME_BLOCKS_QUERY = gql`
  query TimeBlocks($from: ISO8601DateTime!, $to: ISO8601DateTime!) {
    timeBlocks(from: $from, to: $to) {
      id
      startsAt
      endsAt
      status
      capacity
      spotsRemaining
      priceNote
      standalone
      eventType { id name slug color }
      venue { id name address url }
    }
  }
`

// --- Admin: availability patterns ------------------------------------------

export type AvailabilityPattern = {
  __typename?: 'AvailabilityPattern'
  id: string
  weekday: number
  startTime: string
  endTime: string
  slotMinutes: number
  capacity: number
  priceNote: string | null
  effectiveFrom: string
  effectiveTo: string | null
  active: boolean
  slotCount: number
  eventType: EventType
  venue: Venue | null
}

const PATTERN_FIELDS = `
  id weekday startTime endTime slotMinutes capacity priceNote
  effectiveFrom effectiveTo active slotCount
  eventType { id name slug color }
  venue { id name }
`

export type AdminPatternsData = { admin: { availabilityPatterns: AvailabilityPattern[] } }

export const ADMIN_PATTERNS_QUERY = gql`
  query AdminPatterns {
    admin {
      availabilityPatterns {
        ${PATTERN_FIELDS}
      }
    }
  }
`

export type PatternMutationData = {
  createAvailabilityPattern?: { availabilityPattern: AvailabilityPattern | null; errors: FieldError[] } | null
  updateAvailabilityPattern?: { availabilityPattern: AvailabilityPattern | null; errors: FieldError[] } | null
}

export const CREATE_PATTERN_MUTATION = gql`
  mutation CreatePattern(
    $eventTypeId: ID!, $venueId: ID, $weekday: Int!, $startTime: String!, $endTime: String!,
    $slotMinutes: Int!, $capacity: Int!, $priceNote: String,
    $effectiveFrom: ISO8601Date!, $effectiveTo: ISO8601Date
  ) {
    createAvailabilityPattern(input: {
      eventTypeId: $eventTypeId, venueId: $venueId, weekday: $weekday,
      startTime: $startTime, endTime: $endTime, slotMinutes: $slotMinutes,
      capacity: $capacity, priceNote: $priceNote,
      effectiveFrom: $effectiveFrom, effectiveTo: $effectiveTo
    }) {
      availabilityPattern { ${PATTERN_FIELDS} }
      errors { field messages }
    }
  }
`

export const UPDATE_PATTERN_MUTATION = gql`
  mutation UpdatePattern(
    $id: ID!, $eventTypeId: ID, $venueId: ID, $weekday: Int, $startTime: String, $endTime: String,
    $slotMinutes: Int, $capacity: Int, $priceNote: String,
    $effectiveFrom: ISO8601Date, $effectiveTo: ISO8601Date, $active: Boolean,
    $clearEffectiveTo: Boolean
  ) {
    updateAvailabilityPattern(input: {
      id: $id, eventTypeId: $eventTypeId, venueId: $venueId, weekday: $weekday,
      startTime: $startTime, endTime: $endTime, slotMinutes: $slotMinutes,
      capacity: $capacity, priceNote: $priceNote,
      effectiveFrom: $effectiveFrom, effectiveTo: $effectiveTo, active: $active,
      clearEffectiveTo: $clearEffectiveTo
    }) {
      availabilityPattern { ${PATTERN_FIELDS} }
      errors { field messages }
    }
  }
`

export const DELETE_PATTERN_MUTATION = gql`
  mutation DeletePattern($id: ID!) {
    deleteAvailabilityPattern(input: { id: $id }) {
      deletedId
      errors { field messages }
    }
  }
`

// --- Admin: slots ----------------------------------------------------------

export type AdminTimeBlock = {
  __typename?: 'AdminTimeBlock'
  id: string
  startsAt: string
  endsAt: string
  status: 'open' | 'closed' | 'full'
  notes: string | null
  capacityOverride: number | null
  priceNoteOverride: string | null
  effectiveCapacity: number | null
  effectivePriceNote: string | null
  inheritedCapacity: number | null
  inheritedPriceNote: string | null
  overridden: boolean
  spotsRemaining: number | null
  approvedCount: number
  needsReview: boolean
  reviewReason: string | null
  eventType: EventType
  venue: Venue | null
  sourceKind: 'event' | 'pattern' | 'manual'
  sourceTitle: string | null
}

const ADMIN_BLOCK_FIELDS = `
  id startsAt endsAt status notes
  capacityOverride priceNoteOverride
  effectiveCapacity effectivePriceNote
  inheritedCapacity inheritedPriceNote
  overridden spotsRemaining approvedCount
  needsReview reviewReason
  sourceKind sourceTitle
  eventType { id name slug color }
  venue { id name }
`

export type AdminBlocksData = {
  admin: { timeBlocks: AdminTimeBlock[]; blocksNeedingReview: AdminTimeBlock[] }
}
export type AdminBlocksVars = { from: string; to: string }

export const ADMIN_BLOCKS_QUERY = gql`
  query AdminBlocks($from: ISO8601DateTime!, $to: ISO8601DateTime!) {
    admin {
      timeBlocks(from: $from, to: $to) {
        ${ADMIN_BLOCK_FIELDS}
      }
      blocksNeedingReview {
        ${ADMIN_BLOCK_FIELDS}
      }
    }
  }
`

export type UpdateBlockData = {
  updateTimeBlock: { timeBlock: AdminTimeBlock | null; errors: FieldError[] } | null
}

export const UPDATE_BLOCK_MUTATION = gql`
  mutation UpdateTimeBlock(
    $id: ID!, $status: String, $capacity: Int, $priceNote: String,
    $resetCapacity: Boolean, $resetPriceNote: Boolean, $clearReview: Boolean
  ) {
    updateTimeBlock(input: {
      id: $id, status: $status, capacity: $capacity, priceNote: $priceNote,
      resetCapacity: $resetCapacity, resetPriceNote: $resetPriceNote, clearReview: $clearReview
    }) {
      timeBlock { ${ADMIN_BLOCK_FIELDS} }
      errors { field messages }
    }
  }
`

export type MaterializeData = {
  materializeTimeBlocks: {
    created: number
    updated: number
    removed: number
    flagged: number
  } | null
}

export const MATERIALIZE_MUTATION = gql`
  mutation Materialize {
    materializeTimeBlocks(input: {}) {
      created
      updated
      removed
      flagged
    }
  }
`
