import type { ApolloError } from '@apollo/client'

/**
 * The API tags deliberate failures with a machine-readable code in
 * `extensions.code`, so the UI can tell "no such page" from "the API is down"
 * without matching on message text.
 */
export function hasErrorCode(error: ApolloError | undefined, code: string): boolean {
  return (error?.graphQLErrors ?? []).some((graphQLError) => graphQLError.extensions?.['code'] === code)
}
