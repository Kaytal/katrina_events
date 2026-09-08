import { ApolloClient, HttpLink, InMemoryCache, from } from '@apollo/client'
import { setContext } from '@apollo/client/link/context'
import { onError } from '@apollo/client/link/error'
import { clearToken, getToken } from './tokenStore'

const BASE_URL = process.env.API_BASE_URL

export const GRAPHQL_ENDPOINT = `${BASE_URL}/graphql`

const httpLink = new HttpLink({
  uri: GRAPHQL_ENDPOINT,
  // Queries go out as GET so they stay HTTP-cacheable: the API answers them
  // with an ETag and `max-age=0, must-revalidate`, so a repeat visit costs a
  // 304 rather than a re-render of the whole body. Mutations still POST — the
  // API rejects a mutation sent over GET with a 405.
  useGETForQueries: true,
})

// The token rides in a header, never in the URL, so it stays out of browser
// history, referrers, and server access logs even on GET queries.
const authLink = setContext((_operation, { headers }) => {
  const token = getToken()

  return {
    headers: token ? { ...headers, Authorization: `Bearer ${token}` } : headers,
  }
})

// A token that the server has expired or revoked is worthless: drop it rather
// than let every subsequent request fail with it still attached.
const DEAD_TOKEN_CODES = new Set(['TOKEN_EXPIRED', 'TOKEN_REVOKED'])

const authErrorLink = onError(({ graphQLErrors }) => {
  const dead = (graphQLErrors ?? []).some((error) =>
    DEAD_TOKEN_CODES.has(String(error.extensions?.['code'] ?? '')),
  )

  if (dead) clearToken()
})

export const apolloClient = new ApolloClient({
  link: from([authErrorLink, authLink, httpLink]),
  cache: new InMemoryCache({
    typePolicies: {
      // Pages have no `id` field in the schema, so tell the cache that a Page is
      // identified by its slug. Without this every query result is a separate
      // cache entry and navigating back refetches.
      Page: { keyFields: ['slug'] },
      // An occurrence's id is "<eventId>:<originalDate>", already unique and
      // stable, so the default id-based normalization is what we want. Event
      // types and venues are ordinary records.
      EventOccurrence: { keyFields: ['id'] },
      Query: {
        fields: {
          page: {
            // Distinct slugs are distinct entries rather than one overwriting
            // the next.
            keyArgs: ['slug'],
          },
          // Each window is its own cache entry. Without this, paging from
          // September to October would overwrite September's list and going
          // back would show the wrong month until the refetch landed.
          events: { keyArgs: ['from', 'to'] },
        },
      },
    },
  }),
})
