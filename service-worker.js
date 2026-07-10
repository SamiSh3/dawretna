// دوريتنا - Service Worker للتنبيهات
self.addEventListener('push', function(e) {
  if (!e.data) return;
  const data = e.data.json();
  const opts = {
    body: data.body || '',
    icon: '/favicon.ico',
    badge: '/favicon.ico',
    tag: data.tag || 'dawretna',
    data: { url: data.url || '/', slotId: data.slotId },
    requireInteraction: data.requireInteraction || false,
    vibrate: [200, 100, 200]
  };
  e.waitUntil(self.registration.showNotification(data.title || 'دوريتنا 🏕️', opts));
});

self.addEventListener('notificationclick', function(e) {
  e.notification.close();
  const url = e.notification.data?.url || '/';
  e.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(cls => {
      const match = cls.find(c => c.url.includes('dawretna'));
      if (match) { match.focus(); match.postMessage({ type: 'notif-click', slotId: e.notification.data?.slotId }); }
      else clients.openWindow(url);
    })
  );
});

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', () => self.clients.claim());
