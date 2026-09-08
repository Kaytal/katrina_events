import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { ApolloProvider } from '@apollo/client'
import { BrowserRouter } from 'react-router-dom'
import App from './App'
import { apolloClient } from './lib/apollo'
import { hydrateToken } from './lib/tokenStore'
import './styles.css'

// Before the first render, so a refresh does not flash the signed-out state.
hydrateToken()

const container = document.getElementById('root')
if (!container) throw new Error('#root is missing from index.html')

createRoot(container).render(
  <StrictMode>
    <ApolloProvider client={apolloClient}>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </ApolloProvider>
  </StrictMode>,
)
