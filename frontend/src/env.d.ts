// esbuild replaces these at build time via `define`; there is no Node runtime
// in the browser bundle, so declare only what we actually substitute.
declare const process: {
  env: {
    NODE_ENV: 'development' | 'production'
    API_BASE_URL: string
  }
}
