# @dartway/studio-bridge

The app side of the [DartWay Studio](https://dartway.dev) bridge for JavaScript
apps. Your app describes itself — navigation zones, screen passports, the
features on the current screen — and Studio shows a live preview of the running
build with that description attached to it: your client opens a screen, taps a
block, and reads what it is meant to do.

One package, three entry points: the core (`@dartway/studio-bridge`) and two
thin bindings (`/react`, `/vue`). The protocol, the handshake and the access
check live in the core, so the bindings cannot drift apart from each other — or
from the Dart implementation of the same protocol that DartWay's Flutter apps
use.

```bash
npm install @dartway/studio-bridge
```

## Connect

One call, in your entry point. Outside a Studio frame it returns `null` and does
nothing at all — there is nothing to guard with an environment check.

```ts
// main.ts
import { attachStudioBridge } from '@dartway/studio-bridge';
import { router } from './router';

attachStudioBridge({
  manifest: {
    projectName: 'Fitness club',
    zones: [
      {
        label: 'Client app',
        rootPath: '/schedule',
        access: 'signedIn',
        screens: [
          {
            path: '/schedule',
            title: 'Schedule',
            purpose: 'The week ahead, so a client can find a class and book it',
            discussionQuestions: ['Should a full session still be shown?'],
          },
        ],
      },
    ],
    supportedLocales: ['en', 'ru'],
  },

  // Where this build answers. Studio is let in only with a token signed for
  // exactly this origin. Left out, the app accepts any connection — which is
  // what makes previewing your dev server zero-config.
  appOrigin: import.meta.env.VITE_STUDIO_APP_ORIGIN,

  onNavigate: (path) => router.push(path),
  onSignIn: (identifier, secret) => auth.signIn(identifier, secret),
  onSignOut: () => auth.signOut(),
  onLocale: (locale) => i18n.use(locale),

  currentSession: () => ({
    isSignedIn: auth.isSignedIn,
    userIdentifier: auth.phone,
    displayLabel: auth.name,
  }),
});
```

Route changes are picked up from `history` and `popstate`, so any router works
without wiring. Have your router call `host.reportRoute(path, routeName)`
instead if your routes carry names worth sending; session and locale changes are
reported with `reportSession` / `reportLocale` from wherever they happen.

Studio's test credentials go through your **regular** sign-in — the app ships no
test users and no special path for them.

## Declare features

This is the part that earns the integration. A feature says what it is next to
its own code, and the app reports the ones on screen right now — so what your
client reads is what the running build actually does, with nothing stored on
Studio's side that could drift away from the code.

```tsx
// React
import { StudioFeature } from '@dartway/studio-bridge/react';

<StudioFeature
  id="schedule/session-list"
  title="Session list"
  purpose="Lets a client find a class and book it"
  behaviors={['Shows the coming week', 'A full session is marked as such']}
  knownIssues={['A cancelled session still takes up its slot']}
>
  <SessionList />
</StudioFeature>;
```

```vue
<!-- Vue -->
<script setup lang="ts">
import { StudioFeature } from '@dartway/studio-bridge/vue'
</script>

<template>
  <StudioFeature
    id="schedule/session-list"
    title="Session list"
    purpose="Lets a client find a class and book it"
    :behaviors="['Shows the coming week', 'A full session is marked as such']"
  >
    <SessionList />
  </StudioFeature>
</template>
```

Both bindings also come as a composable — `useStudioFeature(feature)` returns a
ref to put on an element you already render, when you would rather not add a
wrapper. Outside Studio a declaration costs one map entry and nothing else, so
declare freely; a feature nobody declared is a feature nobody can point at.

- `title`, `purpose`, `behaviors` — what a client reads.
- `requirements`, `implementationNotes`, `knownIssues` — written for the team;
  Studio shows them apart and flags every feature that carries an open issue.
- `id` is a contract: it is what feedback and tracker items refer to, so give it
  a stable name and never rename it in place.

Binding the element also makes the feature reachable by **tapping** it in the
preview: Studio asks what is at a point, and the innermost declaration around
what is painted there answers.

## Let Studio embed you

The preview is an iframe, so the deployment has to allow being framed. On the
preview deployment only:

```text
Content-Security-Policy: frame-ancestors https://<studio-origin>
```

and **no** `X-Frame-Options: DENY | SAMEORIGIN` — it is the older header, it
takes precedence in some browsers, and it does not understand an allowed origin.

If your auth rides on cookies, they have to survive a third-party frame:
`SameSite=None; Secure` (which also means the preview must be served over
https). Session storage in `localStorage` needs nothing.

## Ship a branch

Deploy the branch the way you normally deploy previews (Vercel, Netlify, a
static bucket — the bridge does not care), then:

1. give the build its own address —
   `VITE_STUDIO_APP_ORIGIN=https://feature-x.preview.example.com`;
2. add the header above to that deployment;
3. paste the preview URL into Studio.

The token Studio presents is short-lived, signed with its Ed25519 key and issued
for that one origin, so a token taken off the wire is worthless anywhere else.
**Your build holds no secret**: the public half of the pair ships inside this
package, a public key can only check signatures and never make them, and it is
the same for every project. There is nothing to copy out of Studio, store, or
rotate.

A token that parses as a signed Studio token and then fails the check gets a
`connectRefused` back, so Studio can say "the signature was refused" instead of
"not connected". Anything that is not a token — nothing presented, a guess,
noise — is met with silence as before: a stranger who guessed the preview's URL
does not learn that there is a bridge on this page.

A build that names no origin (`appOrigin` left out) accepts any connection.
That is deliberate — it is what makes `npm run dev` previewable with no keys at
all — and it is why a deployed build should always name its address.

Signature checking uses Ed25519 in WebCrypto (Chrome 137+, Safari 17+, Firefox
130+) in a secure context. Where it is unavailable the app refuses the
connection rather than trusting an unchecked token — and writes one line to the
console saying which of the two is missing. Without it the preview would just
sit at "not connected" with nothing anywhere pointing at the reason, since a
refusal is silence by design. The local-dev mode above is unaffected: it
verifies nothing and needs neither.

## When the preview stays empty

The host ignores anything on `window` that is not a bridge message, silently —
most of what crosses a page's `window` belongs to somebody else. One case hides
in that silence and is a real fault: **this package and the Studio you are
connecting to speak different protocol versions.** Both are talking, neither
hears the other, and it looks exactly like a stranger's message.

`studioBridgeEnvelopeVersion(data)` separates them:

```ts
import { studioBridgeEnvelopeVersion, studioBridgeProtocol } from '@dartway/studio-bridge';

window.addEventListener('message', (event) => {
  const version = studioBridgeEnvelopeVersion(event.data);
  if (version === null) return;                      // not ours — ignore
  if (version !== studioBridgeProtocol.version) {
    console.warn(`Studio speaks v${version}, this build speaks v${studioBridgeProtocol.version}`);
  }
});
```

`decodeStudioBridgeMessage` cannot tell you this — it returns null for a foreign
message and for our own envelope at the wrong version alike. Upgrading this
package is what closes a mismatch; the version is checked strictly on decode, in
both directions.

## Licence

Apache-2.0, as the rest of the [DartWay](https://github.com/dartway/dartway)
framework.
