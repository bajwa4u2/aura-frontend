import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const sitemap = await readFile(join(root, '..', 'web', 'sitemap.xml'), 'utf8');
const key = (await readFile(join(root, '..', 'web', 'indexnow-key.txt'), 'utf8')).trim();
const urls = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
if (!urls.length) throw new Error('Discovery sitemap has no canonical URLs.');
const hash = createHash('sha256').update(sitemap).digest('hex');
const statePath = join(root, '..', '.indexnow-state.json');
let previous;
try { previous = JSON.parse(await readFile(statePath, 'utf8')); } catch {}
if (previous?.hash === hash) {
  console.log('IndexNow: no meaningful public discovery change; no notification sent.');
  process.exit(0);
}
const response = await fetch('https://api.indexnow.org/indexnow', {
  method: 'POST',
  headers: { 'content-type': 'application/json; charset=utf-8' },
  body: JSON.stringify({ host: 'auraplatform.org', key, keyLocation: `https://auraplatform.org/indexnow-key.txt`, urlList: urls }),
});
console.log(`IndexNow: ${response.status} for ${urls.length} canonical URLs.`);
if (!response.ok) throw new Error(`IndexNow notification failed: ${response.status} ${await response.text()}`);
await writeFile(statePath, `${JSON.stringify({ hash, urls, notifiedAt: new Date().toISOString() }, null, 2)}\n`);
