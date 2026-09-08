const BASE_URL = process.env.API_BASE_URL

export type Health = {
  status: string
  service: string
  environment: string
  time: string
  time_zone: string
  database: string
}

export async function fetchHealth(): Promise<Health> {
  const response = await fetch(`${BASE_URL}/api/v1/health`, {
    headers: { Accept: 'application/json' },
  })

  if (!response.ok) {
    throw new Error(`API responded ${response.status} ${response.statusText}`)
  }

  return (await response.json()) as Health
}
