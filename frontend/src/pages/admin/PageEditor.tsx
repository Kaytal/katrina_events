import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery } from '@apollo/client'
import { Link, useParams } from 'react-router-dom'
import Markdown from '../../components/Markdown'
import {
  ADMIN_PAGE_QUERY,
  UPDATE_PAGE_MUTATION,
  type AdminPageData,
  type AdminPageVars,
  type FieldError,
  type UpdatePageData,
  type UpdatePageVars,
} from '../../lib/queries'
import { useDocumentMeta } from '../../lib/useDocumentMeta'

type Draft = {
  title: string
  body: string
  metaDescription: string
  published: boolean
}

const EMPTY: Draft = { title: '', body: '', metaDescription: '', published: false }

function messagesFor(errors: FieldError[], field: string): string[] {
  return errors.find((error) => error.field === field)?.messages ?? []
}

export default function PageEditor() {
  const { slug = '' } = useParams()
  const [draft, setDraft] = useState<Draft>(EMPTY)
  const [loadedSlug, setLoadedSlug] = useState<string | null>(null)
  const [saved, setSaved] = useState(false)

  const { data, loading, error } = useQuery<AdminPageData, AdminPageVars>(ADMIN_PAGE_QUERY, {
    variables: { slug },
    // The editor must always show what is actually stored, never a cached copy
    // from a previous visit that a later save may have superseded.
    fetchPolicy: 'network-only',
  })

  const page = data?.admin.page ?? null

  // Seed the form once per page, not on every render: re-seeding from the query
  // would throw away whatever she is in the middle of typing.
  useEffect(() => {
    if (!page || loadedSlug === page.slug) return

    setDraft({
      title: page.title,
      body: page.body,
      metaDescription: page.metaDescription ?? '',
      published: page.published,
    })
    setLoadedSlug(page.slug)
  }, [page, loadedSlug])

  const [save, { loading: saving, data: saveData, error: saveError }] = useMutation<
    UpdatePageData,
    UpdatePageVars
  >(UPDATE_PAGE_MUTATION, { onError: () => undefined })

  const fieldErrors = saveData?.updatePage?.errors ?? []

  const dirty = useMemo(() => {
    if (!page) return false

    return (
      draft.title !== page.title ||
      draft.body !== page.body ||
      draft.metaDescription !== (page.metaDescription ?? '') ||
      draft.published !== page.published
    )
  }, [draft, page])

  // Closing the tab mid-edit is the one way to lose work that the app cannot
  // otherwise catch.
  useEffect(() => {
    if (!dirty) return

    const warn = (event: BeforeUnloadEvent) => event.preventDefault()
    window.addEventListener('beforeunload', warn)
    return () => window.removeEventListener('beforeunload', warn)
  }, [dirty])

  useDocumentMeta(page ? `Editing ${page.title}` : 'Editing', null)

  if (loading && !page) {
    return <p className="notice" role="status">Loading…</p>
  }

  if (error) {
    return (
      <div className="notice notice--bad" role="alert">
        <h1>Couldn&rsquo;t load that page</h1>
        <p>{error.message}</p>
        <p>
          <Link to="/admin/pages">Back to pages</Link>
        </p>
      </div>
    )
  }

  const titleErrors = messagesFor(fieldErrors, 'title')
  const metaErrors = messagesFor(fieldErrors, 'metaDescription')

  return (
    <div className="admin admin--wide">
      <div className="admin-head">
        <div>
          <h1>{page?.title}</h1>
          <p className="muted">
            <Link to="/admin/pages">← Pages</Link> · /{slug === 'home' ? '' : slug}
          </p>
        </div>
        <span className={draft.published ? 'badge badge--live' : 'badge'}>
          {draft.published ? 'Published' : 'Draft'}
        </span>
      </div>

      <form
        className="editor"
        onSubmit={(event) => {
          event.preventDefault()
          setSaved(false)

          void save({
            variables: {
              slug,
              title: draft.title,
              body: draft.body,
              // An empty box means "no description", which is null, not "".
              metaDescription: draft.metaDescription.trim() === '' ? null : draft.metaDescription,
              published: draft.published,
            },
          }).then((result) => {
            const ok = (result.data?.updatePage?.errors ?? []).length === 0
            if (ok) {
              setSaved(true)
              setLoadedSlug(null) // Re-seed from the saved record.
            }
          })
        }}
      >
        {saveError && (
          <p className="form-error" role="alert">
            {saveError.graphQLErrors[0]?.message ?? 'Could not save. Please try again.'}
          </p>
        )}

        {saved && !dirty && (
          <p className="form-ok" role="status">
            Saved.
          </p>
        )}

        <div className="editor-fields">
          <label htmlFor="title">Title</label>
          <input
            id="title"
            value={draft.title}
            aria-invalid={titleErrors.length > 0}
            onChange={(event) => setDraft({ ...draft, title: event.target.value })}
          />
          {titleErrors.map((message) => (
            <p className="field-error" key={message}>
              Title {message}
            </p>
          ))}

          <label htmlFor="metaDescription">
            Search-result description <span className="hint">shown by Google, ~160 characters</span>
          </label>
          <input
            id="metaDescription"
            value={draft.metaDescription}
            aria-invalid={metaErrors.length > 0}
            onChange={(event) => setDraft({ ...draft, metaDescription: event.target.value })}
          />
          {metaErrors.map((message) => (
            <p className="field-error" key={message}>
              Description {message}
            </p>
          ))}

          <label className="checkbox">
            <input
              type="checkbox"
              checked={draft.published}
              onChange={(event) => setDraft({ ...draft, published: event.target.checked })}
            />
            Published — visible to visitors
          </label>
        </div>

        <div className="editor-split">
          <div className="editor-pane">
            <label htmlFor="body">Content</label>
            <p className="hint">
              Markdown: <code>## Heading</code>, <code>**bold**</code>,{' '}
              <code>- list item</code>, <code>[link](/contact)</code>
            </p>
            <textarea
              id="body"
              value={draft.body}
              spellCheck
              onChange={(event) => setDraft({ ...draft, body: event.target.value })}
            />
          </div>

          <div className="editor-pane">
            <span className="pane-label">Preview</span>
            {/*
              The same renderer and the same sanitizer as the public page, so
              what she sees here is exactly what a visitor gets — a preview that
              rendered Markdown differently would be worse than none.
            */}
            <div className="preview">
              <h2>{draft.title || 'Untitled'}</h2>
              <Markdown source={draft.body} />
            </div>
          </div>
        </div>

        <div className="editor-actions">
          <button type="submit" disabled={saving || !dirty}>
            {saving ? 'Saving…' : 'Save changes'}
          </button>
          {dirty && <span className="muted">Unsaved changes</span>}
        </div>
      </form>
    </div>
  )
}
