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
  publishedAt: string | null
  updatedAt: string
}

export type PageQueryData = { page: Page | null }
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
