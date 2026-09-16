const CACHE = "tvtoto-image-tool-v2026-09-16-01";

const CORE = [
  "./",
  "./index.html",
  "./manifest.webmanifest"
];

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE)
      .then(cache => cache.addAll(CORE))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(keys =>
        Promise.all(
          keys
            .filter(key => key !== CACHE)
            .map(key => caches.delete(key))
        )
      )
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", event => {

  const request = event.request;

  if (request.method !== "GET") return;

  const url = new URL(request.url);

  if (url.origin !== self.location.origin) return;


  /* HTML → selalu cek versi terbaru */
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
            .then(cache => cache.put(request, copy));

        }

        return response;

      })

      .catch(() =>
        caches.match(request)
          .then(cached =>
            cached ||
            caches.match("./index.html") ||
            caches.match("./")
          )
      )

    );

    return;
  }


  /* JS / CSS / manifest → network first */
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
            .then(cache => cache.put(request, copy));

        }

        return response;

      })

      .catch(() =>
        caches.match(request)
      )

    );

    return;
  }


  /* Asset lain → cache first */
  event.respondWith(

    caches.match(request)
      .then(cached => {

        if (cached) return cached;

        return fetch(request);

      })

  );

});
