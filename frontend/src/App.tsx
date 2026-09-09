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
const PageList = lazy(() => import('./pages/admin/PageList'))
const PageEditor = lazy(() => import('./pages/admin/PageEditor'))
const EventList = lazy(() => import('./pages/admin/EventList'))
const EventEditor = lazy(() => import('./pages/admin/EventEditor'))
const VenueList = lazy(() => import('./pages/admin/VenueList'))
const PatternList = lazy(() => import('./pages/admin/PatternList'))
const SlotList = lazy(() => import('./pages/admin/SlotList'))

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
          <Route
            path="admin/pages"
            element={
              <Suspense fallback={<Loading />}>
                <PageList />
              </Suspense>
            }
          />
          <Route
            path="admin/pages/:slug"
            element={
              <Suspense fallback={<Loading />}>
                <PageEditor />
              </Suspense>
            }
          />
          <Route
            path="admin/events"
            element={
              <Suspense fallback={<Loading />}>
                <EventList />
              </Suspense>
            }
          />
          <Route
            path="admin/events/new"
            element={
              <Suspense fallback={<Loading />}>
                <EventEditor />
              </Suspense>
            }
          />
          <Route
            path="admin/events/:id"
            element={
              <Suspense fallback={<Loading />}>
                <EventEditor />
              </Suspense>
            }
          />
          <Route
            path="admin/venues"
            element={
              <Suspense fallback={<Loading />}>
                <VenueList />
              </Suspense>
            }
          />
          <Route
            path="admin/availability"
            element={
              <Suspense fallback={<Loading />}>
                <PatternList />
              </Suspense>
            }
          />
          <Route
            path="admin/slots"
            element={
              <Suspense fallback={<Loading />}>
                <SlotList />
              </Suspense>
            }
          />
        </Route>

        <Route path="*" element={<NotFound />} />
      </Route>
    </Routes>
  )
}
