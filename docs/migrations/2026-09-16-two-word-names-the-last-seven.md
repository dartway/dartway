---
title: "Seven one-word framework names are gone: DwConfig, DwFlutter, DwPlugin, DwPlugins, DwFeature, DwRoute, DwRouter"
affects:
  dartway_core_flutter: "0.20.0-dev.1"
  dartway_core_server: "0.20.0-dev.1"
  dartway_router: "1.1.2"
---

## Who is affected

Every project that builds a Flutter app, declares an HTTP route or configures the router — which
is every project. The names are the ones an app writes on its first day, so the edit is shallow
and wide: many files, one line each, and the compiler names all of them.

## What changed

Rule 8 of `docs/DESIGN.md` — a public name is two or more words, and `Dw` is not one — held
everywhere except seven names that predated it. They were the rule's declared debt; this closes it.

| Was | Is | Where |
|---|---|---|
| `DwConfig` | `DwFlutterConfig` | `dartway_core_flutter` |
| `DwFlutter` | `DwFlutterToolbox` | `dartway_core_flutter` |
| `DwPlugin` | `DwFlutterPlugin` | `dartway_core_flutter` |
| `DwPlugins` | `DwPluginRegistry` | `dartway_core_flutter` |
| `DwFeature` | `DwFeatureWidget` | `dartway_core_flutter` |
| `DwRoute` | `DwHttpRoute` | `dartway_core_server` |
| `DwRouter` | `DwAppRouter` | `dartway_router` |

Nothing but the names changed: no signature, no behaviour, no wire format. `DwFlutterCore`,
`DwRouteHandler`, `DwRouteAuth`, `DwFeatureSpec`, `DwNavigationRoute` and the rest already had
two words and are untouched.

## What to change

Rename at every use. The compiler finds all of them, but a whole-word search is faster:

```sh
rg -w 'DwConfig|DwFlutter|DwPlugin|DwPlugins|DwFeature|DwRoute|DwRouter'
```

Three shapes are worth naming, because they are the ones that read as something other than a type:

```dart
// the app's entry point
final dw = DwFlutterCore(config: DwFlutterConfig(...), plugins: [...]);

// an integration package's accessor
extension TelegramPlugin on DwPluginRegistry { ... }   // was: on DwPlugins

// a widget that declares itself a product feature (Studio passports, error reports)
class SessionList extends ConsumerWidget implements DwFeatureWidget { ... }
```

A plugin's `init` takes the toolbox, so its signature moves too:

```dart
Future<void> init(DwFlutterToolbox core) async { ... }   // was: DwFlutter core
```

And an HTTP door:

```dart
DwHttpRoute.post('/webhooks/github', handle, auth: DwRouteAuth.none)   // was: DwRoute.post
```

Search-and-replace on whole words is safe: none of the old names is a prefix of anything that
survives — `DwFlutterCore`, `DwFlutterStat` and `DwRouteHandler` do not match `\bDwFlutter\b` or
`\bDwRoute\b`.
