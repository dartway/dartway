// Web push service worker for a DartWay app.
//
// Copy this file to your app's `web/firebase-messaging-sw.js` and fill in the
// config from Firebase Console -> Project Settings -> Your apps -> Web app.
// Those values are public (they identify the project, they do not authorize
// anything) — the web API key is not a secret.
//
// Without this file the browser shows nothing while the tab is closed. Without
// its `notificationclick` handler it shows the notification and then opens the
// app at its root, whatever the notification was about.

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'REPLACE_ME',
  authDomain: 'REPLACE_ME',
  projectId: 'REPLACE_ME',
  storageBucket: 'REPLACE_ME',
  messagingSenderId: 'REPLACE_ME',
  appId: 'REPLACE_ME',
});

// FCM displays notification payloads in the background by itself. Adding a
// `showNotification` call here would produce a second, duplicate notification.
firebase.messaging();

self.addEventListener('notificationclick', (event) => {
  // The path was built by the server and travels in the message data under
  // `link` — the one client that cannot build its own route, because this code
  // runs outside Flutter with no router in reach.
  const notificationData = event.notification && event.notification.data;
  const messageData =
    notificationData && notificationData.FCM_MSG && notificationData.FCM_MSG.data;
  const link = (messageData && messageData.link) || '/';
  const targetUrl = new URL(link, self.location.origin).href;

  event.notification.close();
  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((windowClients) => {
        // The app is already open: focus that tab and let its router navigate,
        // rather than opening a second copy of the app.
        for (const client of windowClients) {
          if (new URL(client.url).origin !== self.location.origin) continue;
          client.postMessage({ type: 'dw-push-open', link: link });
          return client.focus();
        }
        return self.clients.openWindow(targetUrl);
      }),
  );
});
