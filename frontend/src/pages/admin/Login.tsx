import { useState } from 'react'
import { useMutation } from '@apollo/client'
import { Navigate, useLocation, useNavigate } from 'react-router-dom'
import { LOGIN_MUTATION, type LoginData, type LoginVars } from '../../lib/queries'
import { setToken } from '../../lib/tokenStore'
import { useAuth } from '../../lib/useAuth'
import { useDocumentMeta } from '../../lib/useDocumentMeta'

type LocationState = { from?: string }

export default function Login() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const navigate = useNavigate()
  const location = useLocation()
  const { signedIn, loading: checkingSession } = useAuth()

  useDocumentMeta('Sign in', null)

  const [login, { loading, error }] = useMutation<LoginData, LoginVars>(LOGIN_MUTATION, {
    onCompleted: (data) => {
      if (!data.login) return

      setToken(data.login.token)
      const from = (location.state as LocationState | null)?.from
      navigate(from ?? '/admin', { replace: true })
    },
    // Errors are rendered below, not thrown past the form.
    onError: () => undefined,
  })

  if (checkingSession) {
    return <p className="notice" role="status">Checking your session…</p>
  }

  if (signedIn) {
    return <Navigate to="/admin" replace />
  }

  return (
    <div className="panel">
      <h1>Sign in</h1>

      <form
        className="form"
        onSubmit={(event) => {
          event.preventDefault()
          void login({ variables: { email, password } })
        }}
      >
        {error && (
          <p className="form-error" role="alert">
            {error.graphQLErrors[0]?.message ?? 'Sign-in failed. Please try again.'}
          </p>
        )}

        <label htmlFor="email">Email</label>
        <input
          id="email"
          name="email"
          type="email"
          autoComplete="username"
          required
          value={email}
          onChange={(event) => setEmail(event.target.value)}
        />

        <label htmlFor="password">Password</label>
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          value={password}
          onChange={(event) => setPassword(event.target.value)}
        />

        <button type="submit" disabled={loading}>
          {loading ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </div>
  )
}
