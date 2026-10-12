#!/usr/bin/env node
// Mes Km — porte de régression HORS LIGNE (UX-008D).
//
// Qualifie le BUILD GÉNÉRÉ dans un vrai Chrome (CDP, sans dépendance) :
//   1. chargement EN LIGNE → première frame Flutter ;
//   2. service worker actif + précache complet + page contrôlée ;
//   3. serveur TUÉ (hors ligne same-origin réel) + DNS cross-origin bloqué
//      → navigation puis PREMIÈRE FRAME FLUTTER hors ligne, deux fois.
// Toute requête échouée est capturée et affichée (diagnostic).
// Limite honnête : Chrome n'est pas iOS — l'autorité reste l'iPhone.
import { spawn, execSync } from 'node:child_process';
import { mkdtempSync, rmSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const ROOT = new URL('..', import.meta.url).pathname;
const PORT = 8123, CDP = 9333;
const URL_APP = `http://127.0.0.1:${PORT}/`;
const CHROME = process.env.CHROME_EXECUTABLE ??
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const sw = readFileSync(join(ROOT, 'build/web/sw.js'), 'utf8');
const precacheCount =
  JSON.parse(sw.match(/const PRECACHE = (\[[\s\S]*?\]);/)[1]).length;

const failures = [];
let id = 0, ws, session;
const pending = new Map();

function send(method, params = {}) {
  return new Promise((resolve, reject) => {
    const msg = { id: ++id, method, params, sessionId: session };
    pending.set(msg.id, { resolve, reject });
    ws.send(JSON.stringify(msg));
  });
}
async function evalJs(expression) {
  const r = await send('Runtime.evaluate',
    { expression, awaitPromise: true, returnByValue: true });
  if (r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails));
  return r.result.value;
}
async function pollUntil(label, expression, timeoutMs) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    if (await evalJs(expression)) return true;
    await new Promise((r) => setTimeout(r, 400));
  }
  throw new Error(`TIMEOUT: ${label}`);
}

const serve = () => spawn('python3',
  ['-m', 'http.server', String(PORT), '--directory', 'build/web'],
  { cwd: ROOT, stdio: 'ignore' });

let server = serve();
const profile = mkdtempSync(join(tmpdir(), 'meskm-gate-'));
const chrome = spawn(CHROME, [
  '--headless=new', `--user-data-dir=${profile}`,
  `--remote-debugging-port=${CDP}`, '--no-first-run', '--mute-audio',
  // Bloque TOUTE résolution hors 127.0.0.1 : une dépendance CDN au boot
  // ferait échouer la porte dès la phase en ligne.
  '--host-resolver-rules=MAP * ~NOTFOUND , EXCLUDE 127.0.0.1',
  'about:blank',
], { stdio: 'ignore' });

const cleanup = (code) => {
  try { chrome.kill(); } catch {}
  try { server.kill(); } catch {}
  try { rmSync(profile, { recursive: true, force: true }); } catch {}
  process.exit(code);
};

try {
  await new Promise((r) => setTimeout(r, 1500));
  const list = await (await fetch(`http://127.0.0.1:${CDP}/json/version`)).json();
  ws = new WebSocket(list.webSocketDebuggerUrl);
  await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
  ws.onmessage = (e) => {
    const m = JSON.parse(e.data);
    if (m.id && pending.has(m.id)) {
      const p = pending.get(m.id); pending.delete(m.id);
      m.error ? p.reject(new Error(m.error.message)) : p.resolve(m.result);
    } else if (m.method === 'Network.loadingFailed') {
      failures.push(`${m.params.errorText} ${m.params.canceled ? '(annulé)' : ''}`);
    } else if (m.method === 'Network.requestWillBeSent') {
      lastUrls.set(m.params.requestId, m.params.request.url);
    }
  };
  const lastUrls = new Map();
  const origOnMsg = ws.onmessage;
  ws.onmessage = (e) => {
    const m = JSON.parse(e.data);
    if (m.method === 'Network.requestWillBeSent') {
      lastUrls.set(m.params.requestId, m.params.request.url);
    } else if (m.method === 'Network.loadingFailed') {
      failures.push(`${lastUrls.get(m.params.requestId) ?? '?'} → ${m.params.errorText}`);
    }
    origOnMsg(e);
  };

  const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
  session = (await send('Target.attachToTarget', { targetId, flatten: true })).sessionId;
  await send('Page.enable'); await send('Network.enable'); await send('Runtime.enable');

  // 1) EN LIGNE → première frame.
  await send('Page.navigate', { url: URL_APP });
  await pollUntil('première frame EN LIGNE',
    `!document.getElementById('splash') && !!document.querySelector('flutter-view')`,
    30000);
  console.log('ONLINE_FIRST_FRAME = YES');

  // 2) SW actif + précache COMPLET.
  await pollUntil('service worker actif',
    `navigator.serviceWorker.getRegistration().then(r=>!!(r&&r.active))`, 20000);
  await pollUntil('précache complet',
    `caches.keys().then(async ks=>{const k=ks.find(x=>x.startsWith('meskm-shell-'));` +
    `if(!k)return false;const c=await caches.open(k);` +
    `return (await c.keys()).length>=${precacheCount};})`, 30000);
  await send('Page.reload');
  await pollUntil('page contrôlée par le SW',
    `!!navigator.serviceWorker.controller`, 15000);
  await pollUntil('première frame (rechargement contrôlé)',
    `!document.getElementById('splash') && !!document.querySelector('flutter-view')`,
    30000);
  console.log('SW_CONTROLS_PAGE = YES');

  // 3) HORS LIGNE RÉEL : serveur tué + navigation à froid, deux fois.
  server.kill();
  await new Promise((r) => setTimeout(r, 500));
  for (const run of [1, 2]) {
    await send('Page.navigate', { url: URL_APP });
    await pollUntil(`navigation hors ligne #${run}`,
      `document.title === 'Mes Km'`, 15000);
    if (run === 1) console.log('OFFLINE_NAVIGATION = YES');
    await pollUntil(`première frame HORS LIGNE #${run}`,
      `!document.getElementById('splash') && !!document.querySelector('flutter-view')`,
      30000);
    console.log(`OFFLINE_FLUTTER_FIRST_FRAME (#${run}) = YES`);
  }
  console.log('OFFLINE_GATE = PASS');
  cleanup(0);
} catch (err) {
  console.error('OFFLINE_GATE = FAIL —', err.message);
  if (failures.length) {
    console.error('Requêtes échouées :');
    for (const f of [...new Set(failures)].slice(0, 20)) console.error('  ' + f);
  }
  cleanup(1);
}
