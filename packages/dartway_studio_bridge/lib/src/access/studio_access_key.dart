import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The one hashing scheme both sides of the bridge agree on for access keys:
/// hex-encoded SHA-256 of the UTF-8 secret. Studio shows this hash in project
/// settings; the app bakes it into its build and compares against it, so the
/// raw secret never lives in the app's public bundle — only its hash does.
String studioAccessKeyHash(String secret) =>
    sha256.convert(utf8.encode(secret)).toString();

/// Ready-made access-key validator for the common case: accept the connection
/// iff `studioAccessKeyHash(key) == expectedHash`.
///
/// An empty [expectedHash] accepts any key — the zero-config local-dev mode
/// (a build with no `STUDIO_KEY_HASH` define connects to a local Studio
/// without ceremony). A real build bakes the hash and enforces it.
Future<bool> Function(String accessKey) studioHashAccessValidator(
  String expectedHash,
) =>
    (accessKey) async =>
        expectedHash.isEmpty || studioAccessKeyHash(accessKey) == expectedHash;
