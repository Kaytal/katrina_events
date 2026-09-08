import { NavLink, Outlet } from 'react-router-dom'
import { useAuth } from '../lib/useAuth'

const NAV = [
  { to: '/', label: 'Home' },
  { to: '/about', label: 'About' },
  { to: '/contact', label: 'Contact' },
]

export default function Layout() {
  const { signedIn } = useAuth()

  return (
    <div className="site">
      <a className="skip-link" href="#content">
        Skip to content
      </a>

      <header className="site-header">
        <NavLink to="/" className="wordmark">
          Katrina&nbsp;Events
        </NavLink>
        <nav aria-label="Main">
          <ul>
            {NAV.map(({ to, label }) => (
              <li key={to}>
                {/* `end` so Home is not marked current on every route. */}
                <NavLink to={to} end={to === '/'}>
                  {label}
                </NavLink>
              </li>
            ))}
            {signedIn && (
              <li>
                <NavLink to="/admin">Admin</NavLink>
              </li>
            )}
          </ul>
        </nav>
      </header>

      <main id="content" className="site-main">
        <Outlet />
      </main>

      <footer className="site-footer">
        <p>
          Requests are confirmed by email. Payment is handled off-site — nothing
          here collects money.
        </p>
      </footer>
    </div>
  )
}
