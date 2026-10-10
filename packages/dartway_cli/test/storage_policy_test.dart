// ignore_for_file: invalid_use_of_internal_member

import 'dart:convert';

import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:dartway_cli/src/deploy/storage_policy.dart';
import 'package:dartway_core_server/src/files/dw_storage_buckets.dart';
import 'package:dartway_core_shared/src/files/dw_storage_cors.dart';
import 'package:test/test.dart';

void main() {
  test('CLI CORS and visibility contracts equal server provisioning', () {
    const origins = ['https://app.example', 'https://stage.example:8443'];
    expect(
      jsonDecode(dwStorageCorsJson(origins)),
      jsonDecode(DwStorageCorsRule(origins).json),
    );
    expect(DwStack.visibilityProbeKey, DwBucketCheck.probeKey);
    expect(DwStack.visibilityProbeText, utf8.decode(DwBucketCheck.probeBody));
  });
}
