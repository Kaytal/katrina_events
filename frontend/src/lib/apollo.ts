import { ApolloClient, HttpLink, InMemoryCache } from '@apollo/client'

const BASE_URL = process.env.API_BASE_URL

export const GRAPHQL_ENDPOINT = `${BASE_URL}/graphql`

const link = new HttpLink({
  uri: GRAPHQL_ENDPOINT,
  // Queries go out as GET so they stay HTTP-cacheable: the API answers them
  // with an ETag and `max-age=0, must-revalidate`, so a repeat visit costs a
  // 304 rather than a re-render of the whole body. Mutations still POST — the
  // API rejects a mutation sent over GET with a 405.
  useGETForQueries: true,
})

export const apolloClient = new ApolloClient({
  link,
  cache: new InMemoryCache({
    typePolicies: {
      // Pages have no `id` field in the schema, so tell the cache that a Page is
      // identified by its slug. Without this every query result is a separate
      // cache entry and navigating back refetches.
      Page: { keyFields: ['slug'] },
      Query: {
        fields: {
          page: {
            // Distinct slugs are distinct entries rather than one overwriting
            // the next.
            keyArgs: ['slug'],
          },
        },
      },
    },
  }),
})
