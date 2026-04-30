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
  console.log('[SW DIAG] push event received hasData=' + !!(event.data));
  event.waitUntil(handlePush(event));
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  event.waitUntil(handleNotificationClick(event));
});

function isCallNotification(data) {
  var kind = String(
    data.notificationKind || data.type || (data.data && data.data.notificationKind) || ''
  ).toUpperCase();
  var attention = String(
    data.attention || (data.data && data.data.attention) || ''
  ).toUpperCase();
  var isCallKind = kind === 'LIVE' || kind === 'CALL' || kind === 'REALTIME' ||
    kind === 'CALL_RINGING' || kind === 'LIVE_RINGING';
  return isCallKind && attention === 'INTERRUPT';
}

// Resolve the deeplink from whichever field the backend sent.
// Backend sends lowercase "deeplink"; the old sw expected "deepLink" (camelCase).
function resolveDeeplink(data) {
  return data.deeplink ||
    data.deepLink ||
    data.route ||
    (data.data && (data.data.deeplink || data.data.route)) ||
    null;
}

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
  // Use sessionId/communicationId as tag so duplicate pushes collapse.
  var tag = data.collapseKey ||
    (data.data && data.data.sessionId) ||
    data.communicationId ||
    data.tag ||
    'aura-push';

  var deeplink = resolveDeeplink(data);
  var isCall = isCallNotification(data);
  console.log('[SW DIAG] handlePush: title=' + title + ' isCall=' + isCall +
    ' kind=' + (data.notificationKind || data.type || '') +
    ' attention=' + (data.attention || (data.data && data.data.attention) || '') +
    ' deeplink=' + deeplink +
    ' tag=' + tag);

  // Store the full data blob so handleNotificationClick can route correctly.
  var notificationData = {
    deeplink: deeplink,
    notificationKind: data.notificationKind || (data.data && data.data.notificationKind) || data.type || '',
    attention: data.attention || (data.data && data.data.attention) || '',
    sessionId: (data.data && data.data.sessionId) || (data.data && data.data.realtimeSessionId) || '',
    communicationId: data.communicationId || '',
    type: data.type || '',
  };

  console.log('[SW DIAG] showNotification requireInteraction=' + isCall);
  return self.registration.showNotification(title, {
    body: body,
    icon: icon,
    badge: badge,
    tag: tag,
    data: notificationData,
    // Keep call notifications on screen until the user interacts with them.
    requireInteraction: isCall,
    // Vibrate for calls: long-short-long pattern.
    vibrate: isCall ? [400, 200, 400, 200, 400] : [200],
  });
}

async function handleNotificationClick(event) {
  var nd = event.notification.data || {};
  console.log('[SW DIAG] notificationclick kind=' + nd.notificationKind + ' deeplink=' + nd.deeplink);
  // Prefer the stored deeplink; fall back to origin root.
  var deeplink = nd.deeplink || '/';

  // Normalise: relative path → absolute URL on same origin.
  if (deeplink && !deeplink.startsWith('http')) {
    deeplink = self.location.origin + deeplink;
  }

  var clientList = await self.clients.matchAll({
    type: 'window',
    includeUncontrolled: true,
  });

  // Prefer to reuse an existing Aura tab.
  for (var i = 0; i < clientList.length; i++) {
    var client = clientList[i];
    if (!client.url.startsWith(self.location.origin)) continue;

    if ('focus' in client) {
      try {
        // client.navigate() is Chrome-only; use postMessage as a universal fallback.
        if (deeplink && deeplink !== self.location.origin + '/') {
          if (typeof client.navigate === 'function') {
            await client.navigate(deeplink);
          } else {
            // Ask the Flutter app to navigate via the message channel.
            client.postMessage({ type: 'AURA_NAVIGATE', deeplink: deeplink });
          }
        }
        return client.focus();
      } catch (_) {}
    }
  }

  // No existing tab — open a new window at the target route.
  if (self.clients.openWindow) {
    return self.clients.openWindow(deeplink || self.location.origin);
  }
}
