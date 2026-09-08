import { useState } from 'react'
import { useMutation, useQuery } from '@apollo/client'
import {
  ADMIN_VENUES_QUERY,
  CREATE_VENUE_MUTATION,
  UPDATE_VENUE_MUTATION,
  type AdminVenuesData,
  type FieldError,
  type VenueMutationData,
} from '../../lib/queries'
import { useDocumentMeta } from '../../lib/useDocumentMeta'

type Draft = { id: string | null; name: string; address: string; url: string }

const BLANK: Draft = { id: null, name: '', address: '', url: '' }

/**
 * Minimal on purpose: a place is a name and an address. It exists so announcing
 * a festival at a venue that is not already on file does not need a developer.
 */
export default function VenueList() {
  const [draft, setDraft] = useState<Draft | null>(null)
  const { data, loading, error } = useQuery<AdminVenuesData>(ADMIN_VENUES_QUERY, {
    fetchPolicy: 'cache-and-network',
  })

  useDocumentMeta('Places', null)

  const [createVenue, createState] = useMutation<VenueMutationData>(CREATE_VENUE_MUTATION, {
    refetchQueries: [ADMIN_VENUES_QUERY],
    onError: () => undefined,
  })
  const [updateVenue, updateState] = useMutation<VenueMutationData>(UPDATE_VENUE_MUTATION, {
    onError: () => undefined,
  })

  const busy = createState.loading || updateState.loading
  const errors: FieldError[] =
    createState.data?.createVenue?.errors ?? updateState.data?.updateVenue?.errors ?? []

  const save = async () => {
    if (!draft) return

    const variables = {
      name: draft.name,
      address: draft.address.trim() === '' ? null : draft.address,
      url: draft.url.trim() === '' ? null : draft.url,
    }

    const result = draft.id
      ? await updateVenue({ variables: { id: draft.id, ...variables } })
      : await createVenue({ variables })

    const payload = result.data?.createVenue ?? result.data?.updateVenue
    if ((payload?.errors ?? []).length === 0 && payload?.venue) setDraft(null)
  }

  if (loading && !data) return <p className="notice" role="status">Loading…</p>

  if (error) {
    return (
      <div className="notice notice--bad" role="alert">
        <h1>Couldn&rsquo;t load your places</h1>
        <p>{error.message}</p>
      </div>
    )
  }

  return (
    <div className="admin">
      <div className="admin-head">
        <div>
          <h1>Places</h1>
          <p className="muted">Where events happen. Pick one of these on an event.</p>
        </div>
        <button type="button" onClick={() => setDraft(BLANK)} disabled={draft !== null}>
          Add a place
        </button>
      </div>

      {draft && (
        <div className="panel">
          <h2>{draft.id ? 'Edit place' : 'New place'}</h2>

          {errors.map((fieldError) => (
            <p className="field-error" key={fieldError.field}>
              {fieldError.field}: {fieldError.messages.join(', ')}
            </p>
          ))}

          <div className="editor-fields">
            <label htmlFor="venue-name">Name</label>
            <input
              id="venue-name"
              value={draft.name}
              onChange={(event) => setDraft({ ...draft, name: event.target.value })}
            />

            <label htmlFor="venue-address">Address</label>
            <input
              id="venue-address"
              value={draft.address}
              onChange={(event) => setDraft({ ...draft, address: event.target.value })}
            />

            <label htmlFor="venue-url">
              Website <span className="hint">optional, must start with https://</span>
            </label>
            <input
              id="venue-url"
              value={draft.url}
              onChange={(event) => setDraft({ ...draft, url: event.target.value })}
            />
          </div>

          <div className="editor-actions">
            <button type="button" disabled={busy || draft.name.trim() === ''} onClick={() => void save()}>
              {busy ? 'Saving…' : 'Save place'}
            </button>
            <button type="button" className="link" onClick={() => setDraft(null)}>
              Cancel
            </button>
          </div>
        </div>
      )}

      <ul className="record-list">
        {(data?.admin.venues ?? []).map((venue) => (
          <li key={venue.id}>
            <div>
              <span className="record-title">{venue.name}</span>
              {venue.address && <p className="record-meta">{venue.address}</p>}
            </div>
            <button
              type="button"
              className="link"
              onClick={() =>
                setDraft({
                  id: venue.id,
                  name: venue.name,
                  address: venue.address ?? '',
                  url: venue.url ?? '',
                })
              }
            >
              Edit
            </button>
          </li>
        ))}
      </ul>
    </div>
  )
}
