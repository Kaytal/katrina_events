import { useMemo, useState } from 'react'
import { useMutation, useQuery } from '@apollo/client'
import {
  ADMIN_BLOCKS_QUERY,
  MATERIALIZE_MUTATION,
  UPDATE_BLOCK_MUTATION,
  type AdminBlocksData,
  type AdminBlocksVars,
  type AdminTimeBlock,
  type MaterializeData,
  type UpdateBlockData,
} from '../../lib/queries'
import { ZONE_LABEL, formatMountain } from '../../lib/mountainTime'
import { useDocumentMeta } from '../../lib/useDocumentMeta'

// Slots are materialized over a rolling 90 days, so there is nothing further
// out to show.
function window90() {
  const from = new Date()
  from.setHours(0, 0, 0, 0)
  const to = new Date(from)
  to.setDate(to.getDate() + 90)

  return { from: from.toISOString(), to: to.toISOString() }
}

function OverrideField({
  label,
  inherited,
  override,
  busy,
  onSet,
  onReset,
}: {
  label: string
  inherited: string
  override: string | null
  busy: boolean
  onSet: (value: string) => void
  onReset: () => void
}) {
  const [value, setValue] = useState(override ?? '')

  const commit = () => {
    if (value.trim() === '' || value === (override ?? '')) return
    onSet(value)
  }

  return (
    <div className="override">
      <label>
        {label}
        <input
          value={value}
          // The inherited value as placeholder is the whole point: an empty box
          // means "whatever the class says", and she can see what that is.
          placeholder={`${inherited} (inherited)`}
          onChange={(event) => setValue(event.target.value)}
          onBlur={commit}
          // Blur alone would mean pressing Enter silently does nothing, which
          // reads as the field being broken.
          onKeyDown={(event) => {
            if (event.key !== 'Enter') return
            event.preventDefault()
            commit()
          }}
        />
      </label>
      {override !== null && (
        // Without this the first override she sets can never be undone, and
        // "12 because I said so" becomes indistinguishable from "12 because the
        // class says so".
        <button type="button" className="link" disabled={busy} onClick={onReset}>
          Reset to inherited
        </button>
      )}
    </div>
  )
}

function SlotRow({
  block,
  busy,
  onUpdate,
}: {
  block: AdminTimeBlock
  busy: boolean
  onUpdate: (variables: Record<string, unknown>) => void
}) {
  const [open, setOpen] = useState(false)

  return (
    <li className={block.needsReview ? 'slot needs-review' : 'slot'}>
      <div className="slot-head">
        <div>
          <span className="slot-when">{formatMountain(block.startsAt)}</span>
          <p className="record-meta">
            {block.sourceTitle ?? block.eventType.name}
            {' · '}
            {block.sourceKind === 'pattern' ? 'open availability' : block.sourceKind}
            {' · '}
            {block.effectiveCapacity ?? '—'} place{block.effectiveCapacity === 1 ? '' : 's'}
            {block.overridden && ' (overridden)'}
          </p>
        </div>

        <div className="record-badges">
          <span className={block.status === 'open' ? 'badge badge--live' : 'badge'}>
            {block.status}
          </span>
          <button type="button" className="link" onClick={() => setOpen(!open)}>
            {open ? 'Done' : 'Edit'}
          </button>
        </div>
      </div>

      {block.needsReview && (
        <div className="review" role="alert">
          <p>{block.reviewReason}</p>
          <button
            type="button"
            className="link"
            disabled={busy}
            onClick={() => onUpdate({ id: block.id, clearReview: true })}
          >
            I&rsquo;ve dealt with this
          </button>
        </div>
      )}

      {open && (
        <div className="slot-editor">
          <div className="occurrence-actions">
            {block.status === 'open' ? (
              <button
                type="button"
                className="link danger"
                disabled={busy}
                onClick={() => onUpdate({ id: block.id, status: 'closed' })}
              >
                Close this slot
              </button>
            ) : (
              <button
                type="button"
                className="link"
                disabled={busy}
                onClick={() => onUpdate({ id: block.id, status: 'open' })}
              >
                Open this slot
              </button>
            )}
          </div>

          <OverrideField
            label="Places"
            inherited={String(block.inheritedCapacity ?? '—')}
            override={block.capacityOverride === null ? null : String(block.capacityOverride)}
            busy={busy}
            onSet={(value) => onUpdate({ id: block.id, capacity: Number(value) })}
            onReset={() => onUpdate({ id: block.id, resetCapacity: true })}
          />

          <OverrideField
            label="Cost note"
            inherited={block.inheritedPriceNote ?? '—'}
            override={block.priceNoteOverride}
            busy={busy}
            onSet={(value) => onUpdate({ id: block.id, priceNote: value })}
            onReset={() => onUpdate({ id: block.id, resetPriceNote: true })}
          />
        </div>
      )}
    </li>
  )
}

export default function SlotList() {
  const variables = useMemo(window90, [])
  const { data, loading, error, refetch } = useQuery<AdminBlocksData, AdminBlocksVars>(
    ADMIN_BLOCKS_QUERY,
    { variables, fetchPolicy: 'cache-and-network' },
  )

  useDocumentMeta('Slots', null)

  const [updateBlock, updateState] = useMutation<UpdateBlockData>(UPDATE_BLOCK_MUTATION, {
    onError: () => undefined,
  })
  const [materialize, materializeState] = useMutation<MaterializeData>(MATERIALIZE_MUTATION, {
    onError: () => undefined,
  })

  const busy = updateState.loading || materializeState.loading
  const fieldErrors = updateState.data?.updateTimeBlock?.errors ?? []

  const onUpdate = (vars: Record<string, unknown>) => {
    void updateBlock({ variables: vars }).then(() => refetch())
  }

  if (loading && !data) return <p className="notice" role="status">Loading…</p>

  if (error) {
    return (
      <div className="notice notice--bad" role="alert">
        <h1>Couldn&rsquo;t load your slots</h1>
        <p>{error.message}</p>
      </div>
    )
  }

  const blocks = data?.admin.timeBlocks ?? []
  const review = data?.admin.blocksNeedingReview ?? []
  const summary = materializeState.data?.materializeTimeBlocks

  return (
    <div className="admin">
      <div className="admin-head">
        <div>
          <h1>Slots</h1>
          <p className="muted">
            The next 90 days, generated from your classes and your open
            availability. All times {ZONE_LABEL}.
          </p>
        </div>
        <button
          type="button"
          disabled={busy}
          onClick={() => void materialize().then(() => refetch())}
        >
          {materializeState.loading ? 'Regenerating…' : 'Regenerate now'}
        </button>
      </div>

      {summary && (
        <p className="form-ok" role="status">
          Regenerated: {summary.created} added, {summary.updated} updated,{' '}
          {summary.removed} removed, {summary.flagged} needing a look.
        </p>
      )}

      {fieldErrors.map((fieldError) => (
        <p className="form-error" role="alert" key={fieldError.field}>
          {fieldError.messages.join(', ')}
        </p>
      ))}

      {review.length > 0 && (
        <section className="review-summary">
          <h2>{review.length} slot{review.length === 1 ? '' : 's'} need a decision</h2>
          <p className="muted">
            Regenerating wanted to change or remove these, but people had already
            asked for them, so they were left exactly as they were.
          </p>
        </section>
      )}

      {blocks.length === 0 ? (
        <p className="muted">
          No slots yet. Add a bookable class or some open availability, then
          regenerate.
        </p>
      ) : (
        <ul className="slots">
          {blocks.map((block) => (
            <SlotRow key={block.id} block={block} busy={busy} onUpdate={onUpdate} />
          ))}
        </ul>
      )}
    </div>
  )
}
