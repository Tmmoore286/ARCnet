// Playwright-based downloader for ARCnet manifests
import { chromium } from 'playwright'
import fs from 'fs'
import path from 'path'
import readline from 'readline'

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..')

const MANIFESTS = [
  { file: path.join(ROOT, 'manifests', 'core_doctrine_manifest.csv'), outDir: path.join(ROOT, 'downloads', 'core') },
  { file: path.join(ROOT, 'manifests', 'modernization_manifest.csv'), outDir: path.join(ROOT, 'downloads', 'modernization') },
  { file: path.join(ROOT, 'manifests', 'support_manifest.csv'), outDir: path.join(ROOT, 'downloads', 'support') }
]

function safeName(s) {
  return s.replace(/[\s\/:\t]+/g, '_').replace(/[^\w\-\.\(\)\[\]–—]+/g, '_')
}

function guessExt(url, headers) {
  const ct = headers['content-type'] || headers['Content-Type'] || ''
  if (ct.includes('pdf')) return 'pdf'
  if (ct.includes('html') || ct.includes('text/')) return 'html'
  const m = url.match(/\.([a-zA-Z0-9]+)(?:\?|#|$)/)
  return m ? m[1] : 'bin'
}

async function downloadWithContext(context, url) {
  const page = await context.newPage()
  const host = new URL(url).host
  // Warm up host to satisfy anti-bot cookies
  const warm = `https://${host.split('.').slice(-2).join('.')}/`
  try { await page.goto(warm, { waitUntil: 'domcontentloaded', timeout: 15000 }) } catch {}
  // Try direct request with context cookies
  const resp = await context.request.get(url)
  if (!resp.ok()) throw new Error(`HTTP ${resp.status()}`)
  const headers = resp.headers() || {}
  const body = await resp.body()
  await page.close()
  return { headers, body }
}

async function ensureDir(dir) {
  await fs.promises.mkdir(dir, { recursive: true })
}

async function processCsv(file, outDir, browser) {
  if (!fs.existsSync(file)) { console.log(`(skip) Missing manifest: ${file}`); return }
  await ensureDir(outDir)
  console.log(`Reading manifest: ${file}`)
  const context = await browser.newContext({ userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15', acceptDownloads: true })
  const rl = readline.createInterface({ input: fs.createReadStream(file), crlfDelay: Infinity })
  let i = 0
  for await (const line of rl) {
    if (i++ === 0) continue // header
    if (!line.trim()) continue
    const parts = []
    // Simple CSV split (fields do not contain raw commas except within first col in our manifests)
    // Safer: split by last comma as URL; then first col as name before first comma
    const lastComma = line.lastIndexOf(',')
    if (lastComma <= 0) continue
    const url = line.slice(lastComma + 1).trim()
    const cols = line.slice(0, lastComma).split(',')
    const pub = cols[0]?.trim() || 'document'
    const base = safeName(pub)
    try {
      process.stdout.write(`→ ${base} ... `)
      const { headers, body } = await downloadWithContext(context, url)
      const ext = guessExt(url, headers)
      const outPath = path.join(outDir, `${base}.${ext}`)
      await fs.promises.writeFile(outPath, body)
      console.log(`ok (${ext}, ${(body.length/1024).toFixed(0)} KB) => ${outPath}`)
    } catch (e) {
      console.log(`FAILED (${e.message}) url=${url}`)
    }
  }
  await context.close()
}

;(async () => {
  const browser = await chromium.launch({ headless: true })
  try {
    for (const m of MANIFESTS) {
      await processCsv(m.file, m.outDir, browser)
    }
  } finally {
    await browser.close()
  }
  console.log('Done.')
})().catch(e => { console.error(e); process.exit(1) })
