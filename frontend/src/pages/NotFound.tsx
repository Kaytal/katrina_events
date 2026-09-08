import { Link } from 'react-router-dom'
import { useDocumentMeta } from '../lib/useDocumentMeta'

export default function NotFound() {
  useDocumentMeta('Not found', null)

  return (
    <div className="notice">
      <h1>Not found</h1>
      <p>
        There&rsquo;s nothing at this address. Try the <Link to="/">home page</Link>.
      </p>
    </div>
  )
}
