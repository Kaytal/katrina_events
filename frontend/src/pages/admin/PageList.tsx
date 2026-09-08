import { useQuery } from '@apollo/client'
import { Link } from 'react-router-dom'
import { ADMIN_PAGES_QUERY, type AdminPagesData } from '../../lib/queries'
import { useDocumentMeta } from '../../lib/useDocumentMeta'

function formatWhen(iso: string): string {
  return new Date(iso).toLocaleString(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  })
}

export default function PageList() {
  const { data, loading, error } = useQuery<AdminPagesData>(ADMIN_PAGES_QUERY)

  useDocumentMeta('Pages', null)

  if (loading) {
    return <p className="notice" role="status">Loading…</p>
  }

  if (error) {
    return (
      <div className="notice notice--bad" role="alert">
        <h1>Couldn&rsquo;t load your pages</h1>
        <p>{error.message}</p>
      </div>
    )
  }

  return (
    <div className="admin">
      <h1>Pages</h1>
      <p className="muted">Edit the copy on the three public pages.</p>

      <ul className="record-list">
        {(data?.admin.pages ?? []).map((page) => (
          <li key={page.slug}>
            <div>
              <Link to={`/admin/pages/${page.slug}`} className="record-title">
                {page.title}
              </Link>
              <p className="record-meta">
                /{page.slug === 'home' ? '' : page.slug} · edited {formatWhen(page.updatedAt)}
              </p>
            </div>
            <span className={page.published ? 'badge badge--live' : 'badge'}>
              {page.published ? 'Published' : 'Draft'}
            </span>
          </li>
        ))}
      </ul>
    </div>
  )
}
