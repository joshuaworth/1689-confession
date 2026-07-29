const CACHE = 'c1689-e39a778a93';
const ASSETS = ["/", "/verses.json?v=2", "/confession.json", "/manifest.webmanifest", "/icons/icon-192.png", "/icons/icon-512.png", "/fonts/EBGaramond-400.woff2", "/fonts/EBGaramond-400i.woff2", "/fonts/EBGaramond-500.woff2", "/fonts/EBGaramond-600.woff2", "/fonts/InstrumentSans-400.woff2", "/fonts/InstrumentSans-500.woff2", "/fonts/InstrumentSans-600.woff2", "/fonts/InstrumentSans-700.woff2"];
self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((keys) =>
    Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
  ).then(() => self.clients.claim()));
});
self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;
  e.respondWith(
    caches.match(req).then((hit) => {
      const net = fetch(req).then((res) => {
        if (res && res.ok) {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy));
        }
        return res;
      }).catch(() => hit || (req.mode === 'navigate' ? caches.match('/') : undefined));
      return hit || net;
    })
  );
});
