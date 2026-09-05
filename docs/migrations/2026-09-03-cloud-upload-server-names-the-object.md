---
title: "Uploads: the server names the object, and the caller passes a folder and an extension"
affects:
  dartway_serverpod_core_server: "0.12.0"
  dartway_serverpod_core_flutter: "0.12.0"
---

## Who is affected

Any project that uploads files — through `DwFileUploadHandler`, or by calling the upload endpoints
itself.

The caller used to hand the server the whole object key and the server signed a policy for exactly
it. `requireLogin` was the entire check: nothing tested that the key was free or that it belonged
to the caller, so a signed-in user who knew somebody else's key overwrote the object behind it, and
object storage reports an overwrite on neither side. `verifyUpload` completed the picture — it
accepted any path and recorded the caller as the owner, so an object could be claimed without
uploading a byte.

The caller now names neither. It passes the folder, the extension of the bytes actually being sent
and optionally a readable file name; the server builds `<folder>/u<userId>/<stamp>_<name><ext>`,
records the reservation, and afterwards accepts only the reservation it issued.

## What to change

**1. Call sites of `uploadBytesToServer` / `uploadBytesToServerUrl`.** `path` was the whole key and
is now three parameters:

    - DwFileUploadHandler.uploadBytesToServer(bytes: bytes, path: 'avatars/$name.jpg');
    + DwFileUploadHandler.uploadBytesToServer(
    +   bytes: bytes,
    +   folder: 'avatars',
    +   fileExtension: '.jpg',
    +   fileName: name,      // optional, only so the object downloads readably
    + );

`fileExtension` is separate from `fileName` because the two disagree: an image picked as HEIC is
uploaded as JPEG, and the server reads the recorded mime type off the key it builds.

**2. `defaultUploadNameTemplate` and `defaultPlatformUploadNameTemplate` are gone.** A project that
overrode either was naming the object, which is what moved to the server. What survives of that
intent is `fileName`.

**3. `pickAndUploadImage` / `pickAndUploadImageUrl` take an optional `path`.** Nothing breaks
without it, but until now every picked image landed in the bucket root — if the project worked
around that by not using these calls, it can stop.

**4. A project with its own `DwServerTransport` implementation** must follow the interface:
`getUploadDescription({folder, fileExtension, fileName})` now answers a `DwUploadTicket`
(`fileId` + `uploadDescription`), and `verifyUpload({fileId})` replaces `verifyUpload({path})`.

**5. The schema moved with it** — see the migrations note dated the same day; `DwCloudFile` gains
`fileName` and a unique index, and applying it needs a check first.

## What does not change

Objects already in the bucket do not move, and `publicUrl` values already stored keep resolving.
What changed is how new keys are built.

## How to check

`dart analyze` catches every call site — all four items above are compile errors, not silent
drift. Then upload one file of each kind the app handles (a picked photo, a picked document) and
confirm it lands under `<folder>/u<userId>/…` and comes back with a working `publicUrl`.
