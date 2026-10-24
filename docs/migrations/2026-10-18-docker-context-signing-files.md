---
title: Exclude native signing files from Docker contexts
affects:
  dartway_cli: "0.25.0"
---

## Who is affected

Projects created from a template whose root `.dockerignore` does not exclude native app signing
files. Admitting the Flutter package also admits its local signing files, even when Git ignores
them. Server and web images do not need these files.

## What to change

Append these exclusions after the package allow-list in the project's root `.dockerignore`:

```dockerignore
**/key.properties
**/*.jks
**/*.keystore
**/*.p8
```

## How to check

In a temporary directory, copy the updated `.dockerignore`, create a synthetic
`probe_flutter/android/key.properties` and a normal `probe_flutter/lib/main.dart`, and use a
Dockerfile containing `FROM scratch` followed by `COPY . /`. Run
`docker build --output type=local,dest=../context-output .`. The exported files must include
`probe_flutter/lib/main.dart` and omit the synthetic signing file. Repeat for `.jks`, `.keystore`
and `.p8` files, including nested paths. Use only artificial files for this check.
