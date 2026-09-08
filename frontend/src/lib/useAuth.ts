import { useCallback, useSyncExternalStore } from 'react'
import { useApolloClient, useQuery } from '@apollo/client'
import { getToken, setToken, subscribeToToken } from './tokenStore'
import { LOGOUT_MUTATION, ME_QUERY, type LogoutData, type MeQueryData } from './queries'

export function useToken(): string | null {
  return useSyncExternalStore(subscribeToToken, getToken, () => null)
}

/**
 * The server is the authority on whether a token is still good — it alone knows
 * about expiry and the denylist — so the signed-in user comes from `me` rather
 * than from anything decoded on the client.
 */
export function useAuth() {
  const token = useToken()
  const client = useApolloClient()

  const { data, loading } = useQuery<MeQueryData>(ME_QUERY, {
    // No point asking who we are with no credential to ask with.
    skip: token === null,
    fetchPolicy: 'cache-and-network',
  })

  const signOut = useCallback(async () => {
    try {
      await client.mutate<LogoutData>({ mutation: LOGOUT_MUTATION })
    } catch {
      // The token may already be expired or revoked, in which case the server
      // has nothing to do. Either way the client must forget it.
    } finally {
      setToken(null)
      // Drop every cached authenticated response along with the token.
      await client.clearStore()
    }
  }, [client])

  return {
    user: token === null ? null : (data?.me ?? null),
    // Only "loading" while there is a token worth checking.
    loading: token !== null && loading && data === undefined,
    signedIn: token !== null && Boolean(data?.me),
    signOut,
  }
}
