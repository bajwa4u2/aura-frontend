// Aura Push Notification Service Worker
// Scope: /push/  — separate from Flutter's root service worker to avoid conflicts.
// Push events are delivered here regardless of which page is open.

'use strict';

self.addEventListener('install', function (event) {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', function (event) {
  event.waitUntil(handlePush(event));
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  event.waitUntil(handleNotificationClick(event));
});

async function handlePush(event) {
  var data = {};
  try {
    if (event.data) {
      data = event.data.json();
    }
  } catch (_) {
    try {
      var text = event.data ? event.data.text() : '';
      data = { title: 'Aura', body: text };
    } catch (_) {}
  }

  var title = data.title || 'Aura';
  var body = data.body || '';
  var icon = data.icon || '/icons/Icon-192.png';
  var badge = data.badge || '/icons/Icon-192.png';
  var tag = data.tag || 'aura-push';
  var deepLink = data.deepLink || data.url || null;

  var notificationData = { deepLink: deepLink };

  return self.registration.showNotification(title, {
    body: body,
    icon: icon,
    badge: badge,
    tag: tag,
    data: notificationData,
    requireInteraction: false,
  });
}

async function handleNotificationClick(event) {
  var deepLink = (event.notification.data && event.notification.data.deepLink)
    ? event.notification.data.deepLink
    : '/';

  // Normalise: relative path → absolute URL on same origin
  if (deepLink && !deepLink.startsWith('http')) {
    deepLink = self.location.origin + deepLink;
  }

  var clientList = await self.clients.matchAll({
    type: 'window',
    includeUncontrolled: true,
  });

  // Focus an existing Aura tab if possible
  for (var i = 0; i < clientList.length; i++) {
    var client = clientList[i];
    if (client.url.startsWith(self.location.origin) && 'focus' in client) {
      try {
        if (deepLink && deepLink !== self.location.origin + '/') {
          await client.navigate(deepLink);
        }
        return client.focus();
      } catch (_) {}
    }
  }

  // No existing tab — open a new window
  if (self.clients.openWindow) {
    return self.clients.openWindow(deepLink);
  }
}
