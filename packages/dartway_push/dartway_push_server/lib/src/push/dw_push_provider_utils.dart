import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const dwPushMaximumProviderBodyLength = 200;
const dwPushMaximumProviderRequestBytes = 4096;

/// Data keys a provider falls back to when it cannot carry a notification of
/// its own — RuStore with an image, which has to arrive as data and be drawn by
/// the device.
///
/// This is the wire contract between the two halves of the module: the same
/// three literals appear in `dartway_push_flutter`, and a device reading a key
/// the server stopped writing shows nothing at all, silently. Both sides pin
/// them with a test against the literal strings rather than against each
/// other's constant.
const dwPushImageUrlDataKey = 'image_url';
const dwPushTitleDataKey = 'push_title';
const dwPushBodyDataKey = 'push_body';

/// Where a ready-made in-app path is carried, for the one client that cannot
/// build its own: on the web a service worker handles the click outside
/// Flutter, with no router in reach.
///
/// Part of the same wire contract — `dartway_push_flutter` declares the literal
/// too, and both sides pin it against the string.
///
/// FCM reads this value a **second** time, out of `webpush.fcm_options.link`,
/// where `DwFcmPushProvider` copies it. That is deliberate: it gives web
/// click-through two independent paths to the same destination, because the
/// `notificationclick` event a service worker relies on does not arrive in
/// every browser and OS combination — and no test shows it, since delivery is
/// green either way.
const dwPushLinkDataKey = 'link';

String dwPushTruncateProviderBody(String body) =>
    body.length > dwPushMaximumProviderBodyLength
    ? '${body.substring(0, dwPushMaximumProviderBodyLength)}...'
    : body;

bool dwPushProviderRequestFits(String encodedRequest) =>
    utf8.encode(encodedRequest).length <= dwPushMaximumProviderRequestBytes;

String? dwPushValidProviderImageUrl(String? imageUrl) {
  final normalized = imageUrl?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      uri.scheme != 'https' ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      _isNonPublicHost(uri.host)) {
    return null;
  }
  final path = uri.path.toLowerCase();
  if (!const ['.jpg', '.jpeg', '.png'].any(path.endsWith)) return null;
  return normalized;
}

Duration? dwPushParseRetryAfter(String? value, DateTime now) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  final seconds = int.tryParse(normalized);
  if (seconds != null) {
    return Duration(seconds: seconds < 0 ? 0 : seconds);
  }
  try {
    final delay = HttpDate.parse(normalized).toUtc().difference(now.toUtc());
    return delay.isNegative ? Duration.zero : delay;
  } catch (_) {
    return null;
  }
}

Duration? dwPushLongerDuration(Duration? left, Duration? right) {
  if (left == null) return right;
  if (right == null) return left;
  return left >= right ? left : right;
}

Duration? dwPushPositiveDuration(Duration? duration) =>
    duration != null && duration > Duration.zero ? duration : null;

String dwPushTargetFingerprint(String target) {
  final digest = sha256.convert(utf8.encode(target)).toString();
  return 'targetLength=${target.length}, targetHash=${digest.substring(0, 16)}';
}

String dwPushProviderErrorCode(String responseBody) {
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is Map) {
        final status = error['status']?.toString();
        if (status != null && status.isNotEmpty) {
          return _boundedCode(status);
        }
      }
    }
  } catch (_) {
    // Provider response bodies are untrusted and are never logged verbatim.
  }
  return 'unknown';
}

/// Stable diagnostic for an unexpected exception without serializing its
/// message. Exception messages may contain request bodies, credentials or
/// provider targets and therefore must not cross the push logging boundary.
String dwPushSafeExceptionCode(Object error) {
  final type = error.runtimeType.toString().replaceAll(
    RegExp('[^A-Za-z0-9_]'),
    '_',
  );
  final bounded = type.length <= 80 ? type : type.substring(0, 80);
  return 'exception_$bounded';
}

String _boundedCode(String value) {
  final normalized = value.toLowerCase().replaceAll(RegExp('[^a-z0-9_-]'), '_');
  return normalized.length <= 80 ? normalized : normalized.substring(0, 80);
}

bool _isNonPublicHost(String host) {
  var normalized = host.toLowerCase();
  if (normalized.endsWith('.')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (!normalized.contains('.') ||
      normalized.contains(':') ||
      RegExp(r'^[0-9.]+$').hasMatch(normalized)) {
    return true;
  }
  const privateSuffixes = {
    'localhost',
    'local',
    'internal',
    'intranet',
    'lan',
    'home',
    'home.arpa',
    'test',
    'invalid',
  };
  if (privateSuffixes.any(
    (suffix) => normalized == suffix || normalized.endsWith('.$suffix'),
  )) {
    return true;
  }
  if (normalized.length > 253) return true;
  final validLabel = RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$');
  return normalized
      .split('.')
      .any((label) => label.length > 63 || !validLabel.hasMatch(label));
}
