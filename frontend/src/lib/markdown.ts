import { marked } from 'marked'
import DOMPurify from 'dompurify'

marked.setOptions({ gfm: true, breaks: false })

/**
 * Page bodies are authored by Katrina, but "trusted author" is not a security
 * model — a compromised admin session would otherwise be stored XSS on every
 * visitor. Everything is sanitized before it reaches the DOM.
 */
export function renderMarkdown(source: string): string {
  const html = marked.parse(source, { async: false })

  return DOMPurify.sanitize(html, { USE_PROFILES: { html: true } })
}
