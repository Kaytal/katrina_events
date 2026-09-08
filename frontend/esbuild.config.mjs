import * as esbuild from 'esbuild'
import { writeFile, mkdir } from 'node:fs/promises'
import path from 'node:path'

const watch = process.argv.includes('--watch')
const production = process.env.NODE_ENV === 'production'
const outdir = 'dist'

// Same-origin in production, where nginx proxies /api to Rails. In development
// esbuild serves on :3001 and Rails answers on :3000, so the origin is explicit
// and rack-cors allows it.
const apiBaseUrl = process.env.API_BASE_URL ?? (production ? '' : 'http://localhost:3000')

/**
 * esbuild emits hashed filenames in production but will not touch our HTML, so
 * we read the build's metafile and write index.html from a template ourselves.
 */
function renderIndexHtml({ scripts, stylesheets }) {
  const tags = [
    ...stylesheets.map((href) => `    <link rel="stylesheet" href="/${href}">`),
    ...scripts.map((src) => `    <script type="module" src="/${src}"></script>`),
  ].join('\n')

  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Katrina Events</title>
${tags}
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
`
}

async function writeIndexHtml(metafile) {
  const entries = Object.entries(metafile.outputs).filter(([, meta]) => meta.entryPoint)
  const scripts = []
  const stylesheets = []

  for (const [outputPath, meta] of entries) {
    const file = path.relative(outdir, outputPath)
    if (file.endsWith('.js')) {
      scripts.push(file)
      if (meta.cssBundle) stylesheets.push(path.relative(outdir, meta.cssBundle))
    }
  }

  await mkdir(outdir, { recursive: true })
  await writeFile(path.join(outdir, 'index.html'), renderIndexHtml({ scripts, stylesheets }))
}

const options = {
  entryPoints: ['src/main.tsx'],
  bundle: true,
  outdir,
  format: 'esm',
  target: ['es2020'],
  splitting: true,
  sourcemap: true,
  metafile: true,
  minify: production,
  entryNames: production ? '[name]-[hash]' : '[name]',
  assetNames: production ? '[name]-[hash]' : '[name]',
  // Shared chunks are always hashed, in development too: code splitting emits
  // several anonymous chunks that would all claim the name 'chunk'.
  chunkNames: '[name]-[hash]',
  loader: { '.png': 'file', '.jpg': 'file', '.svg': 'file', '.woff2': 'file' },
  define: {
    'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV ?? 'development'),
    'process.env.API_BASE_URL': JSON.stringify(apiBaseUrl),
  },
}

if (watch) {
  // Rewrite index.html after every rebuild, so a changed entry name is picked up.
  const ctx = await esbuild.context({
    ...options,
    plugins: [
      {
        name: 'write-index-html',
        setup(build) {
          build.onEnd(async (result) => {
            if (result.metafile) await writeIndexHtml(result.metafile)
            const count = result.errors.length
            console.log(count ? `build failed with ${count} error(s)` : 'build ok')
          })
        },
      },
    ],
  })

  await ctx.watch()
  const server = await ctx.serve({
    servedir: outdir,
    host: '0.0.0.0',
    port: 3001,
    fallback: path.join(outdir, 'index.html'),
  })
  console.log(`serving http://localhost:${server.port} (api at ${apiBaseUrl || 'same origin'})`)
} else {
  const result = await esbuild.build(options)
  await writeIndexHtml(result.metafile)
  console.log('built dist/')
}
