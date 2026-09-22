---
title: The first administrator is a startup step, not code called after start()
affects:
  dartway_core_server: "0.20.0-dev.2"
---

## Who is affected

A project that brings its first administrator into existence itself — the shape the skeleton used
to ship: an `AppBootstrap` with `parseAdminIdentifier` and `ensureAdministrator`, parsed in
`bin/server.dart` before the server is built and called after `await server.start()`.

Nothing breaks if you keep it: `server.accounts` and `server.db` are unchanged. Move anyway — the
old shape runs **after** the port is open, so between `start()` and your call the server answers
without an administrator, and a mistyped identifier is found there rather than before anything
opens.

## What to change

**1. Keep only the half that is yours.** The framework goes as far as the account; the role is the
project's. Delete `parseAdminIdentifier` and the ensure-plus-promote body, and leave this:

```dart
// lib/src/bootstrap.dart
abstract final class AppBootstrap {
  static Future<void> grantAdmin(DwCallContext ctx, int accountId) async {
    final profile = (await ctx.db.userProfiles.findFirst(
      where: (t) => t.accountId.equals(accountId),
    ))!;
    if (profile.role == UserRole.admin) return;
    await ctx.db.userProfiles.update(
      profile.copyWith(
        role: UserRole.admin,
        firstName: profile.firstName.isEmpty ? 'Admin' : null,
      ),
    );
  }
}
```

Use `ctx.db` and `ctx.accounts`, not `server.db` and `server.accounts`: the step runs in a
transaction of its own and the context is bound to it.

**2. Declare the step** where the server is built:

```dart
  DwAppServer(
    …
+   startup: [DwFirstAdministrator(grant: AppBootstrap.grantAdmin)],
  );
```

**3. Strip `bin/server.dart`** of the admin entirely — the parsing before the build, the call after
`start()`, and the warning when the identifier is unset (the step warns itself):

```dart
- final adminIdentifier = env[AppBootstrap.adminVariable]?.trim() ?? '';
- if (adminIdentifier.isNotEmpty) AppBootstrap.parseAdminIdentifier(adminIdentifier);
  …
  await server.start();
- if (adminIdentifier.isEmpty) {
-   server.logger.warning('No administrator is declared: …');
- } else if (await AppBootstrap.ensureAdministrator(server, adminIdentifier)) { … }
```

**4. Rename the variable to `DW_ADMIN_IDENTIFIER`** in every environment — the step reads that name
unless you pass `variable:`. See `2026-09-22-local-environment.md` for the order to do it in, which
matters.

**5. A test that called `ensureAdministrator` directly** runs the step instead:

```dart
final step = DwFirstAdministrator(
  grant: AppBootstrap.grantAdmin,
  environment: {DwFirstAdministrator.defaultVariable: 'admin@example.com'},
);
await server.runInContext(step.run);
expect(step.problems(AppAuth.config()), isEmpty);
```

## While you are there

`startup:` takes any `DwStartupStep`, and the lifecycle is what makes it the right place for more
than the administrator: **at every start, in every environment, idempotent, before the port opens.**
Rows that must keep agreeing with your code — notification templates, the reasons you refuse
something — belong there rather than in a migration, which cannot be edited once applied and whose
`down` would delete rows somebody has since corrected. Rows the operators own from the moment they
exist stay a migration. See `docs/4-server/migrations.md`.

## How to check

Start the server with `DW_ADMIN_IDENTIFIER` set. Before `DartWay server listening on port …` there
is now:

    INFO [startup:first administrator] administrator: you@example.com (account 1, created)

Start it with a value that is neither a phone nor an e-mail: the server refuses to start and names
the variable. Sign in with that identifier and open the admin panel.
