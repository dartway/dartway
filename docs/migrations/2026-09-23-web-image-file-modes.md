---
title: The web image grants everyone read on the files it serves
affects:
  dartway_cli: "0.11.1"
---

## Who is affected

Every project created before `dartway_cli` 0.11.1: its `<project>_flutter/Dockerfile` copies the
web build into nginx with the modes the files had in the server's checkout. Those come from the
deploy user's umask, and under `077` the assets a commit adds are served as 403 — while the deploy,
its checks and every page look fine. `dart run dartway_cli:dartway deploy check` now warns about it (`web-file-modes`).

## What to change

`<project>_flutter/Dockerfile`, in the build stage, right after `flutter build web`:

    RUN flutter build web --release \
        --dart-define="DW_BACKEND_URL=${DW_BACKEND_URL}"
    + RUN chmod -R a+rX build/web

If you already normalise the modes in the runtime stage (`RUN chmod -R a+rX /usr/share/nginx/html`),
move it here: in the build stage no layer holds a second copy of the site.

## How to check

`dart run dartway_cli:dartway deploy check --env <environment> --local`: `web-file-modes` passes. On a running stack,
`docker exec <web container> find /usr/share/nginx/html -type f ! -perm -o+r` prints nothing.
