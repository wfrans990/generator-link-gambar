const CACHE = "tvtoto-image-tool-v2026-09-16-01";

const CORE = [
  "./",
  "./index.html",
  "./manifest.webmanifest"
];

/* =========================
   INSTALL
========================= */
self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE)
      .then(cache => cache.addAll(CORE))
      .then(() => self.skipWaiting())
  );
});


/* =========================
   ACTIVATE
========================= */
self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(keys => {
        return Promise.all(
          keys
            .filter(key => key !== CACHE)
            .map(key => caches.delete(key))
        );
      })
      .then(() => self.clients.claim())
  );
});


/* =========================
   FETCH
========================= */
self.addEventListener("fetch", event => {

  const request = event.request;

  if (request.method !== "GET") return;

  const url = new URL(request.url);

  /* Jangan intercept file dari domain lain */
  if (url.origin !== self.location.origin) return;


  /*
    HTML / navigation:
    NETWORK FIRST

    Jadi ketika online:
    selalu ambil versi terbaru dari GitHub Pages.
  */
  if (
    request.mode === "navigate" ||
    request.destination === "document"
  ) {

    event.respondWith(

      fetch(request, {
        cache: "no-store"
      })

      .then(response => {

        if (response && response.ok) {

          const copy = response.clone();

          caches.open(CACHE)
            .then(cache => {
              cache.put(request, copy);
            });

        }

        return response;

      })

      .catch(() => {

        return caches.match(request)
          .then(cached => {

            return cached ||
              caches.match("./index.html") ||
              caches.match("./");

          });

      })

    );

    return;
  }


  /*
    JS / CSS / manifest:
    NETWORK FIRST

    Ini penting supaya update kode langsung terbaca.
  */
  if (
    request.destination === "script" ||
    request.destination === "style" ||
    request.destination === "manifest"
  ) {

    event.respondWith(

      fetch(request, {
        cache: "no-store"
      })

      .then(response => {

        if (response && response.ok) {

          const copy = response.clone();

          caches.open(CACHE)
            .then(cache => {
              cache.put(request, copy);
            });

        }

        return response;

      })

      .catch(() => {

        return caches.match(request);

      })

    );

    return;
  }


  /*
    Asset lain:
    CACHE FIRST

    Misalnya gambar/icon lokal.
  */
  event.respondWith(

    caches.match(request)
      .then(cached => {

        if (cached) {
          return cached;
        }

        return fetch(request)
          .then(response => {

            if (response && response.ok) {

              const copy = response.clone();

              caches.open(CACHE)
                .then(cache => {
                  cache.put(request, copy);
                });

            }

            return response;

          });

      })

  );

});
