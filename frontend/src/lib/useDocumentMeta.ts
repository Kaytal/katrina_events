import { useEffect } from 'react'

const DEFAULT_TITLE = 'Katrina Events'

/**
 * Client-side routing means the document title and description have to be set
 * per route. The full SEO pass (OG images, sitemap) comes in Phase 10; this is
 * the part that is free once the page data is already in hand.
 */
export function useDocumentMeta(title: string | null, description: string | null) {
  useEffect(() => {
    // The home page's own title is the site name, so suffixing it would read
    // "Katrina Events — Katrina Events".
    document.title =
      !title || title === DEFAULT_TITLE ? DEFAULT_TITLE : `${title} — ${DEFAULT_TITLE}`
  }, [title])

  useEffect(() => {
    if (description === null) return

    let tag = document.querySelector<HTMLMetaElement>('meta[name="description"]')
    if (!tag) {
      tag = document.createElement('meta')
      tag.name = 'description'
      document.head.appendChild(tag)
    }
    tag.content = description
  }, [description])
}
