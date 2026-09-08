import { useMemo } from 'react'
import { renderMarkdown } from '../lib/markdown'

/**
 * The one place in the app that calls dangerouslySetInnerHTML. Keeping it to a
 * single component means the sanitizer can never be bypassed by accident.
 */
export default function Markdown({ source }: { source: string }) {
  const html = useMemo(() => renderMarkdown(source), [source])

  return <div className="prose" dangerouslySetInnerHTML={{ __html: html }} />
}
