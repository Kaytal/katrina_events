import { Route, Routes } from 'react-router-dom'
import Layout from './components/Layout'
import PageView from './components/PageView'
import NotFound from './pages/NotFound'

// Slugs are hardcoded rather than taken from the URL: these three pages are the
// site's structure, not user-generated content, and a catch-all would turn every
// typo into an API call.
export default function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<PageView slug="home" />} />
        <Route path="about" element={<PageView slug="about" />} />
        <Route path="contact" element={<PageView slug="contact" />} />
        <Route path="*" element={<NotFound />} />
      </Route>
    </Routes>
  )
}
