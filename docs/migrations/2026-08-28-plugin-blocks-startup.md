---
title: "A class that implements DwPlugin must declare blocksStartup"
affects:
  dartway_flutter: "0.8.0"
---

## Who is affected

Only a project with a plugin of its own that **`implements DwPlugin`** rather than extending it.
The new member has a default body, so `extends DwPlugin` inherits it and nothing changes;
`implements` has to declare it.

Everything else in this change is behaviour a project gets for free: one plugin's failed `init` no
longer aborts `dw.init()` and takes the whole app start with it, and the failure travels as
`DwPluginInitException`, naming the plugin.

## What to change

Either declare the member:

    class MyIntegrationPlugin implements DwPlugin {
    +   @override
    +   bool get blocksStartup => true;

or — better — extend instead of implement:

    - class MyIntegrationPlugin implements DwPlugin {
    + class MyIntegrationPlugin extends DwPlugin {

which is what a plugin base is for, and what stops the next member with a default from breaking it
again.

## What the value means

`true` (the default, and what an app that says nothing keeps): a failing `init` stops the app start
— the plugin was declared, so it is expected to be there.

`false`: the failure is reported once through the error pipeline and the app starts without it.
Reach for it when the integration is genuinely optional — analytics, a chat widget — and reaching
for that plugin afterwards through `maybeOf<T>()` answers that nobody holds the role.

## How to check

`dart analyze` in the Flutter package. A missing member on an `implements` is a compile error;
there is nothing silent here.
