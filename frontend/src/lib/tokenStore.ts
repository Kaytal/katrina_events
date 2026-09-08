/**
 * The token lives in a module variable, mirrored to localStorage so a refresh
 * does not sign her out.
 *
 * This is an XSS-vs-CSRF tradeoff taken knowingly (plan §4): localStorage is
 * readable by injected script. The mitigation is that the one place this app
 * injects HTML — page bodies — is sanitized with DOMPurify before it reaches
 * the DOM, and there is exactly one trusted author. The alternative is
 * httpOnly cookies plus CSRF protection.
 *
 * Apollo links cannot read React context, so the store is plain and the React
 * layer subscribes to it.
 */
const STORAGE_KEY = 'katrina.auth.token'

let token: string | null = null
const listeners = new Set<() => void>()

// localStorage throws in some contexts (Safari private mode, blocked site
// data), and a sign-in flow must not be one of the things that breaks there.
function readStored(): string | null {
  try {
    return window.localStorage.getItem(STORAGE_KEY)
  } catch {
    return null
  }
}

function writeStored(value: string | null) {
  try {
    if (value === null) {
      window.localStorage.removeItem(STORAGE_KEY)
    } else {
      window.localStorage.setItem(STORAGE_KEY, value)
    }
  } catch {
    // In-memory only for this session. Better than failing the login.
  }
}

/** Call once on boot, before the first render, to rehydrate from storage. */
export function hydrateToken(): void {
  token = readStored()
}

export function getToken(): string | null {
  return token
}

export function setToken(next: string | null): void {
  if (token === next) return

  token = next
  writeStored(next)
  listeners.forEach((listener) => listener())
}

export function clearToken(): void {
  setToken(null)
}

export function subscribeToToken(listener: () => void): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}
