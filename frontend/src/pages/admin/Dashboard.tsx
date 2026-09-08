import { Link } from 'react-router-dom'
import { useAuth } from '../../lib/useAuth'
import { useDocumentMeta } from '../../lib/useDocumentMeta'

export default function Dashboard() {
  const { user, signOut } = useAuth()

  useDocumentMeta('Admin', null)

  return (
    <div className="admin">
      <h1>Admin</h1>
      <p>
        Signed in as <strong>{user?.name}</strong> ({user?.email}).
      </p>

      <ul className="record-list">
        <li>
          <div>
            <Link to="/admin/pages" className="record-title">
              Pages
            </Link>
            <p className="record-meta">Edit the copy on Home, About, and Contact.</p>
          </div>
        </li>
      </ul>

      <p className="muted">
        The calendar arrives in Phases 5–7 and the request queue in Phase 8.
      </p>

      <button type="button" onClick={() => void signOut()}>
        Sign out
      </button>
    </div>
  )
}
