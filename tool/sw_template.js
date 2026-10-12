'use strict';
// Service worker Mes Km (UX-008C) — précache du shell applicatif.
//
// POURQUOI IL EXISTE : depuis Flutter 3.35+, le build web ne génère PLUS de
// service worker de cache (flutter_service_worker.js est un simple
// désinstalleur). Sans ce fichier, une PWA installée ne peut pas démarrer
// hors ligne. Généré à chaque build par tool/build_web.sh (liste complète
// des ressources + identifiant de build) — ne pas éditer build/web/sw.js.
//
// Stratégie, volontairement minimale et déterministe :
// - install  : précache atomique de TOUT le shell (cache versionné) ;
//              pas de skipWaiting — la mise à jour s'active au lancement
//              suivant (modèle « fermer puis rouvrir » validé) ;
// - activate : purge des caches des builds précédents + claim ;
// - fetch    : navigation = réseau d'abord (index frais => détection de
//              mise à jour), repli sur le shell précaché (hors ligne) ;
//              ressources même-origine = cache d'abord, repli réseau.
// IndexedDB n'est jamais touché : les données utilisateur survivent à
// toutes les mises à jour.

const BUILD_ID = '__BUILD_ID__';
const CACHE_NAME = 'meskm-shell-' + BUILD_ID;
const PRECACHE = __PRECACHE__;

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) =>
      cache.addAll(PRECACHE.map((u) => new Request(u, { cache: 'reload' })))
    )
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(
        names
          .filter((n) => n.startsWith('meskm-shell-') && n !== CACHE_NAME)
          .map((n) => caches.delete(n))
      );
      await self.clients.claim();
    })()
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req).catch(() => caches.match('/', { cacheName: CACHE_NAME }))
    );
    return;
  }

  event.respondWith(
    caches
      .match(req, { cacheName: CACHE_NAME, ignoreSearch: true })
      .then((hit) => hit || fetch(req))
  );
});
