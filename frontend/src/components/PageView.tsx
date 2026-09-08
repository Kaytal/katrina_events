import { useQuery } from '@apollo/client'
import { hasErrorCode } from '../lib/graphqlErrors'
import { PAGE_QUERY, type PageQueryData, type PageQueryVars } from '../lib/queries'
import { useDocumentMeta } from '../lib/useDocumentMeta'
import Markdown from './Markdown'

/**
 * Every public page is the same shape: fetch one row by slug, render its
 * Markdown. Phase 4 gives Katrina an editor for the same rows.
 */
export default function PageView({ slug }: { slug: string }) {
  const { data, loading, error } = useQuery<PageQueryData, PageQueryVars>(PAGE_QUERY, {
    variables: { slug },
  })

  const page = data?.page ?? null
  const missing = hasErrorCode(error, 'NOT_FOUND')

  useDocumentMeta(page?.title ?? null, page?.metaDescription ?? null)

  if (loading) {
    return (
      <p className="notice" role="status">
        Loading…
      </p>
    )
  }

  if (missing) {
    return (
      <div className="notice">
        <h1>Page not found</h1>
        <p>That page isn&rsquo;t published yet.</p>
      </div>
    )
  }

  if (error || !page) {
    return (
      <div className="notice notice--bad" role="alert">
        <h1>Something went wrong</h1>
        <p>The site couldn&rsquo;t load this page. {error?.message}</p>
      </div>
    )
  }

  return (
    <article>
      <h1>{page.title}</h1>
      <Markdown source={page.body} />
    </article>
  )
}
