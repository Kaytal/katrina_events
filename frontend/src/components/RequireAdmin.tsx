import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '../lib/useAuth'

/**
 * Client-side gating is a convenience, not the security boundary. Every field
 * that exposes her data calls require_admin! on the server; this only avoids
 * rendering an admin screen that would fail every query.
 */
export default function RequireAdmin() {
  const { signedIn, loading } = useAuth()
  const location = useLocation()

  if (loading) {
    return <p className="notice" role="status">Checking your session…</p>
  }

  if (!signedIn) {
    return <Navigate to="/admin/login" replace state={{ from: location.pathname }} />
  }

  return <Outlet />
}
