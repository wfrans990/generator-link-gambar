const CACHE="tvtoto-image-tool-v1";
const CORE=["./","./manifest.webmanifest"];
self.addEventListener("install",e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(CORE)).then(()=>self.skipWaiting())));
self.addEventListener("activate",e=>e.waitUntil(self.clients.claim()));
self.addEventListener("fetch",e=>{
  if(e.request.method!=="GET")return;
  const u=new URL(e.request.url);
  if(u.origin===location.origin){
    e.respondWith(caches.match(e.request).then(c=>c||fetch(e.request).then(r=>{
      const copy=r.clone();caches.open(CACHE).then(x=>x.put(e.request,copy));return r;
    }).catch(()=>c)));
  }
});