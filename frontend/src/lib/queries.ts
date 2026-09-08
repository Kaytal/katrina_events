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
