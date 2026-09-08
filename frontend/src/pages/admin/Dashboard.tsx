import { useAuth } from '../../lib/useAuth'
import { useDocumentMeta } from '../../lib/useDocumentMeta'

/**
 * A landing page, not a feature. Phase 4 replaces this with the page editor,
 * which is the core ask — the point of Phase 3 is that she can get here at all.
 */
export default function Dashboard() {
  const { user, signOut } = useAuth()

  useDocumentMeta('Admin', null)

  return (
    <div className="panel">
      <h1>Admin</h1>
      <p>
        Signed in as <strong>{user?.name}</strong> ({user?.email}).
      </p>

      <p className="muted">
        Page editing arrives in Phase 4, the calendar in Phases 5–7, and the
        request queue in Phase 8.
      </p>

      <button type="button" onClick={() => void signOut()}>
        Sign out
      </button>
    </div>
  )
}
