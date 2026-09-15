// Web push service worker for a DartWay app.
//
// Copy this file to your app's `web/firebase-messaging-sw.js` and fill in the
// config from Firebase console -> Project settings -> Your apps -> Web app.
// Those values identify the project and authorize nothing; they are public.
//
// ORDER IS LOAD-BEARING (#78). The Firebase messaging SDK registers a
// `notificationclick` listener of its own and calls
// `stopImmediatePropagation()` in it, so a listener registered after the SDK
// never runs — on every browser, looking exactly like an event that does not
// arrive. This listener is registered first, before the SDK is even loaded,
// and stops the SDK's instead: the SDK always opens a new tab, this one
// focuses a tab of the app that is already open.
//
// The server sends the link twice: in the data (`dw_link`, read here) and as
// `webpush.fcm_options.link`, which the browser follows by itself where no
// worker handles the click.

self.addEventListener('notificationclick', (event) => {
  event.stopImmediatePropagation();
  event.notification.close();

  const message = (event.notification.data || {}).FCM_MSG || {};
  const data = message.data || {};
  const link = data.dw_link || (message.fcmOptions || {}).link || '/';
  const target = new URL(link, self.location.origin);

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((windows) => {
        for (const client of windows) {
          if (new URL(client.url).origin !== self.location.origin) continue;
          // The app is open: its router navigates, no second copy starts.
          client.postMessage({ type: 'dw-push-open', link: target.pathname + target.search + target.hash, data: data });
          return client.focus();
        }
        return self.clients.openWindow(target.href);
      }),
  );
});

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

// FCM shows notification messages in the background by itself; a
// showNotification call here would show each one twice.
firebase.messaging();
