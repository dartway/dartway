// Executes the service worker template in a worker-like scope with the
// Firebase SDK stubbed as it behaves: `firebase.messaging()` registers a
// `notificationclick` listener that stops propagation and opens a new tab.
// Dispatches one click and prints what happened as JSON.
//
// usage: node run_service_worker.js <sw.js> <scenario: open-tab|no-tab|no-data>
const fs = require('fs');
const vm = require('vm');

const [swPath, scenario] = process.argv.slice(2);
const origin = 'https://app.example.com';
const listeners = [];
const report = { order: [], posted: [], focused: 0, opened: [], sdkRan: false, closed: false };

const windows = scenario === 'open-tab'
  ? [
      { url: 'https://other.example.com/', postMessage: () => report.posted.push('foreign'), focus: async () => {} },
      { url: `${origin}/schedule`, postMessage: (m) => report.posted.push(m), focus: async () => { report.focused++; } },
    ]
  : [];

const self = {
  location: new URL(`${origin}/firebase-messaging-sw.js`),
  addEventListener: (type, listener) => {
    listeners.push({ type, listener, owner: sdkLoading ? 'sdk' : 'app' });
    report.order.push(`${sdkLoading ? 'sdk' : 'app'}:${type}`);
  },
  clients: {
    matchAll: async () => windows,
    openWindow: async (url) => { report.opened.push(url); },
  },
};

let sdkLoading = false;
const firebase = {
  initializeApp: () => {},
  messaging: () => {
    sdkLoading = true;
    self.addEventListener('notificationclick', (event) => {
      event.stopImmediatePropagation();
      report.sdkRan = true;
    });
    sdkLoading = false;
  },
};

const context = vm.createContext({
  self,
  URL,
  firebase,
  importScripts: () => {},
  console,
});
vm.runInContext(fs.readFileSync(swPath, 'utf8'), context, { filename: swPath });

const data = scenario === 'no-data'
  ? {}
  : { FCM_MSG: { data: { dw_link: '/news/12?from=push', dw_type: 'NewsAlert', dw_payload: '{"id":12}' }, fcmOptions: { link: `${origin}/news/12` } } };

let stopped = false;
const waits = [];
const event = {
  notification: { data, close: () => { report.closed = true; } },
  stopImmediatePropagation: () => { stopped = true; },
  waitUntil: (promise) => waits.push(promise),
};
for (const { type, listener } of listeners) {
  if (type !== 'notificationclick') continue;
  listener(event);
  if (stopped) break;
}
Promise.all(waits).then(() => {
  console.log(JSON.stringify(report));
});
