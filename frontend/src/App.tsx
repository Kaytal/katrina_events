import { useEffect, useState } from 'react'
import { fetchHealth, type Health } from './api'

type State =
  | { phase: 'loading' }
  | { phase: 'ok'; health: Health }
  | { phase: 'error'; message: string }

export default function App() {
  const [state, setState] = useState<State>({ phase: 'loading' })

  useEffect(() => {
    let active = true

    fetchHealth()
      .then((health) => {
        if (active) setState({ phase: 'ok', health })
      })
      .catch((error: unknown) => {
        if (active) {
          setState({
            phase: 'error',
            message: error instanceof Error ? error.message : 'Unknown error',
          })
        }
      })

    return () => {
      active = false
    }
  }, [])

  return (
    <main className="shell">
      <h1>Katrina Events</h1>
      <p className="lede">
        Phase 1 skeleton. This page asks the API for its health so the whole
        path — browser, Rails, Postgres — is proven before any features exist.
      </p>

      {state.phase === 'loading' && <p className="status">Checking the API…</p>}

      {state.phase === 'error' && (
        <div className="status status--bad">
          <strong>API unreachable.</strong> {state.message}
        </div>
      )}

      {state.phase === 'ok' && (
        <div className={state.health.database === 'connected' ? 'status status--good' : 'status status--bad'}>
          <strong>API {state.health.status}</strong>
          <dl>
            <dt>Service</dt>
            <dd>{state.health.service}</dd>
            <dt>Environment</dt>
            <dd>{state.health.environment}</dd>
            <dt>Database</dt>
            <dd>{state.health.database}</dd>
            <dt>Time zone</dt>
            <dd>{state.health.time_zone}</dd>
            <dt>Server time</dt>
            <dd>{state.health.time}</dd>
          </dl>
        </div>
      )}
    </main>
  )
}
