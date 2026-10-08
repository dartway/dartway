---
title: Bundle CanvasKit into the web image
affects:
  dartway_cli: "0.24.0"
---

## Who is affected

A project whose Flutter `Dockerfile` builds web without `--no-web-resources-cdn`.

## What to change

In `<project>_flutter/Dockerfile`:

```diff
-RUN flutter build web --release \
+RUN flutter build web --release --no-web-resources-cdn \
     --dart-define="DW_BACKEND_URL=${DW_BACKEND_URL}"
```

## How to check

Deploy the image, then run `dartway deploy check --env <environment>`:
`web-resources-local` passes, and the outside compression probe passes.
