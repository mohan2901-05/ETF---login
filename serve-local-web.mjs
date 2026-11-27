import { createReadStream } from 'node:fs';
import { readFile, stat } from 'node:fs/promises';
import { createServer, request } from 'node:http';
import { extname, resolve, sep } from 'node:path';

const root = resolve(process.argv[2] ?? 'etf-loans-flutter/build/web');
const origin = 'http://127.0.0.1:7360';
const types = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.css': 'text/css',
  '.svg': 'image/svg+xml', '.png': 'image/png', '.ttf': 'font/ttf',
  '.otf': 'font/otf', '.woff2': 'font/woff2',
};

async function requireFile(path) {
  const info = await stat(resolve(root, path)).catch(() => null);
  if (!info?.isFile() || info.size === 0) {
    throw new Error(`Missing or empty ${path}. Build the Flutter web bundle again.`);
  }
  return info;
}

for (const path of ['index.html', 'flutter_bootstrap.js', 'main.dart.js', 'assets/AssetManifest.bin',
  'assets/assets/logos/logo.png', 'assets/assets/illustrations/login_art.svg']) {
  await requireFile(path);
}
const manifest = 'assets/AssetManifest.bin.json';
await requireFile(manifest);
const encoded = JSON.parse(await readFile(resolve(root, manifest), 'utf8'));
if (typeof encoded !== 'string' || Buffer.from(encoded, 'base64').length === 0) {
  throw new Error('Invalid Flutter web asset manifest.');
}
const fonts = JSON.parse(await readFile(resolve(root, 'assets/FontManifest.json'), 'utf8'));
for (const family of ['MaterialIcons', 'Plus Jakarta Sans', 'DM Sans', 'JetBrains Mono']) {
  if (!fonts.some(entry => entry.family === family && entry.fonts.length > 0)) {
    throw new Error(`Missing Flutter font family ${family}.`);
  }
}
for (const { fonts: faces } of fonts) {
  for (const { asset } of faces) await requireFile(`assets/${asset}`);
}

createServer(async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  try {
    const url = new URL(req.url, origin);
    if (url.pathname.startsWith('/api/')) {
      const synthetic = await fetch('http://127.0.0.1:8080/api/health', {
        redirect: 'error', signal: AbortSignal.timeout(2000),
      }).then(async response => response.ok && (await response.json()).mode === 'local-synthetic')
        .catch(() => false);
      if (!synthetic) { res.writeHead(503); res.end(); return; }
      const upstream = request({
        hostname: '127.0.0.1', port: 8080, method: req.method,
        path: url.pathname + url.search, headers: req.headers,
      }, response => {
        res.writeHead(response.statusCode, { ...response.headers, 'cache-control': 'no-store' });
        response.pipe(res);
      });
      upstream.on('error', () => { res.writeHead(502); res.end(); });
      req.pipe(upstream);
      return;
    }
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      res.writeHead(405, { Allow: 'GET, HEAD' }); res.end(); return;
    }
    const pathname = decodeURIComponent(url.pathname);
    const file = resolve(root, `.${pathname === '/' ? '/index.html' : pathname}`);
    if (!file.startsWith(root + sep)) { res.writeHead(403); res.end(); return; }
    const info = await stat(file).catch(() => null);
    if (!info?.isFile()) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, {
      'Content-Type': types[extname(file)] ?? 'application/octet-stream',
      'Content-Length': info.size,
    });
    if (req.method === 'HEAD') res.end();
    else createReadStream(file).on('error', () => res.destroy()).pipe(res);
  } catch {
    res.writeHead(400);
    res.end();
  }
}).listen(7360, '127.0.0.1', () => console.log(`ETF Loans ready at ${origin}`));
