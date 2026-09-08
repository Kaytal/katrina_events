import { Suspense, lazy } from 'react'
import { Route, Routes } from 'react-router-dom'
import Layout from './components/Layout'
import PageView from './components/PageView'
import RequireAdmin from './components/RequireAdmin'
import NotFound from './pages/NotFound'

// Route-level code splitting: the admin screens are in the same bundle graph but
// a separate chunk, so a visitor reading the About page never downloads them.
const Login = lazy(() => import('./pages/admin/Login'))
const Dashboard = lazy(() => import('./pages/admin/Dashboard'))

function Loading() {
  return (
    <p className="notice" role="status">
      Loading…
    </p>
  )
}

// Public slugs are hardcoded rather than taken from the URL: these three pages
// are the site's structure, not user-generated content, and a catch-all would
// turn every typo into an API call.
export default function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<PageView slug="home" />} />
        <Route path="about" element={<PageView slug="about" />} />
        <Route path="contact" element={<PageView slug="contact" />} />

        <Route
          path="admin/login"
          element={
            <Suspense fallback={<Loading />}>
              <Login />
            </Suspense>
          }
        />
        <Route element={<RequireAdmin />}>
          <Route
            path="admin"
            element={
              <Suspense fallback={<Loading />}>
                <Dashboard />
              </Suspense>
            }
          />
        </Route>

        <Route path="*" element={<NotFound />} />
      </Route>
    </Routes>
  )
}
