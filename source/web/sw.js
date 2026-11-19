// Seagull Strike service worker: fetch the newest game when online, fall back to the saved copy offline.
// The cache name is stamped by build-web.mjs on every build, so each release gets a fresh cache.
const C = 'seagull-strike-__VERSION__';
const FILES = ['./', 'index.html', 'manifest.webmanifest', 'icon-192.png', 'icon-512.png', 'apple-touch-icon.png', 'game.js', 'love.js', 'love.wasm', 'game.data'];
self.addEventListener('install', (e) => { self.skipWaiting(); e.waitUntil(caches.open(C).then((c) => c.addAll(FILES)).catch(() => {})); });
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((k) => Promise.all(k.filter((x) => x !== C).map((x) => caches.delete(x)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', (e) => {
  const r = e.request; if (r.method !== 'GET') return;
  const url = new URL(r.url);
  if (url.origin !== location.origin) return;  // the owner script goes straight to the network
  // network first, saved copy when offline
  e.respondWith(fetch(r).then((res) => {
    if (res && res.ok) { const cp = res.clone(); caches.open(C).then((c) => c.put(r.mode === 'navigate' ? 'index.html' : r, cp)); }
    return res;
  }).catch(() => caches.match(r.mode === 'navigate' ? 'index.html' : r)));
});
