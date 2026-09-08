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
