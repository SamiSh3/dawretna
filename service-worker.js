// دوريتنا - Service Worker
const ICON = 'https://samish3.github.io/dawretna/icon.png';
const APP_URL = 'https://samish3.github.io/dawretna/';

self.addEventListener('push', function(e) {
  if (!e.data) return;
  let data = {};
  try { data = e.data.json(); } catch(err) { data = {title: 'دوريتنا', body: e.data.text()}; }

  const opts = {
    body: data.body || '',
    icon: ICON,
    badge: ICON,
    tag: data.tag || 'dawretna-notif',
    data: { url: APP_URL, slotId: data.slotId || null },
    requireInteraction: false,
    vibrate: [200, 100, 200],
    silent: false
  };

  e.waitUntil(
    self.registration.showNotification(data.title || 'دوريتنا 🏕️', opts)
  );
});

self.addEventListener('notificationclick', function(e) {
  e.notification.close();
  const slotId = e.notification.data?.slotId;

  e.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then(cls => {
        const match = cls.find(c => c.url.includes('dawretna'));
        if (match) {
          match.focus();
          if (slotId) match.postMessage({ type: 'notif-click', slotId });
        } else {
          clients.openWindow(APP_URL + (slotId ? '#slot=' + slotId : ''));
        }
      })
  );
});

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', () => self.clients.claim());
