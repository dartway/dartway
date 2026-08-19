import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

import 'dw_push_http.dart';
import 'dw_push_provider.dart';
import 'dw_push_provider_utils.dart';

const _fcmScope = 'https://www.googleapis.com/auth/firebase.messaging';
const _fcmHost = 'fcm.googleapis.com';

typedef DwFcmAccessTokenProvider = Future<String?> Function();

/// Credentials for [DwFcmPushProvider], from a password key and a file.
///
/// The two halves of an FCM credential are not the same kind of thing, and
/// keeping them in one place made a mess of both. The project id is a short
/// identifier — a password, in the sense `passwords.yaml` means. The service
/// account is a JSON document a couple of thousand characters long, and a
/// document in a passwords file is a document in the master copy of every
/// environment's secrets, with a trap attached: it starts with `{`, so
/// unquoted YAML reads it as a flow mapping rather than a string and the value
/// silently is not what was written.
///
/// So the document travels as a file — `dartway deploy secret put-file`, named
/// under `requires.files` in `deploy/config.yaml`, mounted read-only into the
/// container. [defaultServiceAccountFile] is a relative path on purpose: the
/// server works from its own package directory locally and from `/app` in the
/// image, and `config/<name>` is the same file in both.
final class DwFcmPushProviderConfig {
  DwFcmPushProviderConfig({
    required String? projectId,
    required String? serviceAccountJson,
    String? webpushIcon,
    String? androidIcon,
    String? androidColor,
    this.requestTimeout = const Duration(seconds: 10),
  }) : projectId = _trimToNull(projectId),
       serviceAccountJson = _trimToNull(serviceAccountJson),
       webpushIcon = _trimToNull(webpushIcon),
       androidIcon = _trimToNull(androidIcon),
       androidColor = _trimToNull(androidColor) {
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(
        requestTimeout,
        'requestTimeout',
        'Must be positive',
      );
    }
    _assertWholeOrAbsent();
  }

  /// Where the service-account document is read from by default.
  ///
  /// Relative, and that is the whole point: it resolves to the same file in a
  /// local run and inside the container, where the deploy mounts every entry
  /// of `requires.files` at `/app/config/<name>` beside `passwords.yaml`.
  static const String defaultServiceAccountFile =
      'config/fcm-service-account.json';

  /// The shape an app writes: the project id out of `passwords.yaml`, the
  /// service account out of a file.
  ///
  /// The project id doubles as the declaration. An environment that names it
  /// wants push, and a missing credential is then a fault rather than a
  /// preference — see [DwPushProviderConfigurationException].
  factory DwFcmPushProviderConfig.fromPasswords(
    Map<String, String> passwords, {
    String projectIdKey = 'fcmProjectId',
    String serviceAccountFile = defaultServiceAccountFile,
    String? webpushIcon,
    String? androidIcon,
    String? androidColor,
    Duration requestTimeout = const Duration(seconds: 10),
  }) {
    final file = File(serviceAccountFile);
    final projectId = _trimToNull(passwords[projectIdKey]);
    if (projectId != null && !file.existsSync()) {
      throw DwPushProviderConfigurationException(
        'FCM',
        'the service account was not found at "$serviceAccountFile" (the '
            'project id came from the "$projectIdKey" password key). Send the '
            'JSON to the server with "dartway deploy secret put-file", name it '
            'under requires.files in deploy/config.yaml so the deploy mounts '
            'it into the container, and keep it out of passwords.yaml — a '
            'document there is a document in the master copy of every '
            'environment, and unquoted YAML reads a leading "{" as a mapping '
            'rather than as text',
      );
    }
    return DwFcmPushProviderConfig(
      projectId: projectId,
      serviceAccountJson: file.existsSync() ? file.readAsStringSync() : null,
      webpushIcon: webpushIcon,
      androidIcon: androidIcon,
      androidColor: androidColor,
      requestTimeout: requestTimeout,
    );
  }

  final String? projectId;
  final String? serviceAccountJson;
  final String? webpushIcon;
  final String? androidIcon;
  final String? androidColor;
  final Duration requestTimeout;

  /// Whether this provider has everything it needs.
  ///
  /// After construction there is no third state left: a config either has both
  /// halves or neither, because anything between the two throws.
  bool get isConfigured => projectId != null && serviceAccountJson != null;

  /// Nothing, or everything — never the half that fails at the first send.
  void _assertWholeOrAbsent() {
    if (projectId == null && serviceAccountJson == null) {
      return;
    }
    if (projectId == null) {
      throw const DwPushProviderConfigurationException(
        'FCM',
        'no project id was given. It is the key that declares an environment '
            'wants FCM at all, so a service account without one configures '
            'nothing',
      );
    }
    if (serviceAccountJson == null) {
      throw const DwPushProviderConfigurationException(
        'FCM',
        'no service account was given. Read it from a file — the default is '
            '"$defaultServiceAccountFile", delivered by '
            '"dartway deploy secret put-file"',
      );
    }
    final Object? document;
    try {
      document = jsonDecode(serviceAccountJson!);
    } on FormatException catch (error) {
      throw DwPushProviderConfigurationException(
        'FCM',
        'the service account is not JSON (${error.message}). A truncated '
            'upload and a YAML value that lost its quotes both look like this',
      );
    }
    if (document is! Map) {
      throw const DwPushProviderConfigurationException(
        'FCM',
        'the service account is valid JSON but not an object. Google issues '
            'it as a file; send that file through unchanged',
      );
    }
  }
}

/// A blank string is an absent one everywhere in this file: an empty icon, an
/// empty project id or an empty link are all "not set", and none of them may
/// reach the payload as `""`.
String? _trimToNull(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

/// Firebase Cloud Messaging HTTP v1 provider.
final class DwFcmPushProvider implements DwPushProvider {
  DwFcmPushProvider({
    required this.config,
    DwPushHttpClient? httpClient,
    DwFcmAccessTokenProvider? accessTokenProvider,
    DateTime Function()? clock,
  }) : _httpClient = httpClient ?? DwPushDefaultHttpClient(),
       _accessTokenProvider = accessTokenProvider,
       _clock = clock ?? _utcNow;

  final DwFcmPushProviderConfig config;
  final DwPushHttpClient _httpClient;
  final DwFcmAccessTokenProvider? _accessTokenProvider;
  final DateTime Function() _clock;

  _CachedFcmAccessToken? _cachedAccessToken;
  _FcmAccessTokenRefresh? _refreshingAccessToken;
  bool _loggedMissingCredentials = false;

  @override
  Future<DwPushProviderOutcome> send(
    Session session,
    DwPushProviderRequest request,
  ) async {
    if (!config.isConfigured) {
      if (!_loggedMissingCredentials) {
        _loggedMissingCredentials = true;
        session.log(
          'DwPush FCM credentials are not configured',
          level: LogLevel.warning,
        );
      }
      return const DwPushProviderOutcome.permanentFailure(
        errorCode: 'fcm_not_configured',
      );
    }

    final encodedPayload = jsonEncode(_buildPayload(request));
    if (!dwPushProviderRequestFits(encodedPayload)) {
      return const DwPushProviderOutcome.permanentFailure(
        errorCode: 'fcm_payload_too_large',
      );
    }

    final requestTimer = Stopwatch()..start();
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        return const DwPushProviderOutcome.retryableFailure(
          errorCode: 'fcm_oauth_unavailable',
        );
      }
      final remainingTimeout = config.requestTimeout - requestTimer.elapsed;
      if (remainingTimeout <= Duration.zero) {
        throw TimeoutException('FCM request timeout exhausted during OAuth');
      }
      final response = await _httpClient
          .send(
            DwPushHttpRequest(
              method: 'POST',
              uri: Uri.https(
                _fcmHost,
                '/v1/projects/${config.projectId}/messages:send',
              ),
              headers: {
                'authorization': 'Bearer $accessToken',
                'content-type': 'application/json',
              },
              body: encodedPayload,
            ),
          )
          .timeout(remainingTimeout);
      return _classifyResponse(session, request.target, response);
    } on TimeoutException {
      session.log('DwPush FCM request timed out', level: LogLevel.warning);
      return const DwPushProviderOutcome.retryableFailure(
        errorCode: 'fcm_timeout',
      );
    } catch (error, stackTrace) {
      session.log(
        'DwPush FCM request failed (${dwPushSafeExceptionCode(error)})',
        level: LogLevel.warning,
        stackTrace: stackTrace,
      );
      return const DwPushProviderOutcome.retryableFailure(
        errorCode: 'fcm_exception',
      );
    }
  }

  Map<String, Object?> _buildPayload(DwPushProviderRequest request) {
    final payload = request.payload;
    final body = dwPushTruncateProviderBody(payload.body ?? '');
    final imageUrl = dwPushValidProviderImageUrl(
      payload.imageUrl ?? request.data[dwPushImageUrlDataKey],
    );
    final providerData = <String, String>{...request.data}
      ..remove(dwPushImageUrlDataKey);
    if (imageUrl != null) providerData[dwPushImageUrlDataKey] = imageUrl;
    final androidIcon = config.androidIcon;
    final androidColor = config.androidColor;
    final webpushIcon = config.webpushIcon;
    // The same path the app half reads out of `data`, handed to FCM a second
    // time. On the web this is what makes the browser navigate on its own, so
    // that click-through no longer depends solely on a `notificationclick`
    // handler in the service worker — an event that does not arrive in every
    // browser and OS combination.
    final link = _trimToNull(request.data[dwPushLinkDataKey]);

    return {
      'message': {
        'token': request.target,
        'notification': {
          'title': payload.title,
          'body': body,
          'image': ?imageUrl,
        },
        'data': providerData,
        if (imageUrl != null || androidIcon != null || androidColor != null)
          'android': {
            'notification': {
              'image': ?imageUrl,
              'icon': ?androidIcon,
              'color': ?androidColor,
            },
          },
        'apns': {
          'payload': {
            'aps': {
              'sound': 'default',
              if (imageUrl != null) 'mutable-content': 1,
            },
          },
          if (imageUrl != null) 'fcm_options': {'image': imageUrl},
        },
        if (imageUrl != null || webpushIcon != null || link != null)
          'webpush': {
            if (imageUrl != null || webpushIcon != null)
              'notification': {
                'image': ?imageUrl,
                'icon': ?webpushIcon,
              },
            if (link != null) 'fcm_options': {'link': link},
          },
      },
    };
  }

  DwPushProviderOutcome _classifyResponse(
    Session session,
    String target,
    DwPushHttpResponse response,
  ) {
    final error = _FcmError.tryParse(response.body);
    final providerCode = dwPushProviderErrorCode(response.body);
    if (response.statusCode == 200) {
      return const DwPushProviderOutcome.accepted();
    }
    if (error?.fcmErrorCode == 'UNREGISTERED' ||
        error?.status == 'UNREGISTERED') {
      session.log(
        'DwPush FCM target is unregistered: '
        '${dwPushTargetFingerprint(target)}',
        level: LogLevel.warning,
      );
      return const DwPushProviderOutcome.invalidTarget(
        errorCode: 'fcm_unregistered',
      );
    }
    if (response.statusCode == 400 &&
        error?.isInvalidRegistrationToken == true) {
      return const DwPushProviderOutcome.targetNotSupported(
        errorCode: 'fcm_target_not_supported',
      );
    }
    if (response.statusCode == 408 ||
        response.statusCode == 429 ||
        response.statusCode >= 500) {
      final parsedRetryAfter = dwPushParseRetryAfter(
        _header(response.headers, 'retry-after'),
        _clock(),
      );
      final retryAfter = response.statusCode == 429
          ? dwPushLongerDuration(parsedRetryAfter, const Duration(minutes: 1))
          : parsedRetryAfter;
      return DwPushProviderOutcome.retryableFailure(
        errorCode: 'fcm_$providerCode',
        retryAfter: dwPushPositiveDuration(retryAfter),
      );
    }
    return DwPushProviderOutcome.permanentFailure(
      errorCode: 'fcm_$providerCode',
    );
  }

  Future<String?> _getAccessToken() async {
    final now = _clock().toUtc();
    final cached = _cachedAccessToken;
    if (cached != null &&
        now.isBefore(cached.expiresAt.subtract(const Duration(minutes: 5)))) {
      return cached.value;
    }

    final refresh = _refreshingAccessToken ??= _FcmAccessTokenRefresh(
      _loadAccessToken().timeout(config.requestTimeout),
    );
    try {
      final loaded = await refresh.future;
      if (!identical(_refreshingAccessToken, refresh)) {
        final current = _cachedAccessToken;
        return current != null &&
                now.isBefore(
                  current.expiresAt.subtract(const Duration(minutes: 5)),
                )
            ? current.value
            : null;
      }
      if (loaded != null) {
        _cachedAccessToken = loaded;
      }
      return loaded?.value;
    } finally {
      if (identical(_refreshingAccessToken, refresh)) {
        _refreshingAccessToken = null;
      }
    }
  }

  Future<_CachedFcmAccessToken?> _loadAccessToken() async {
    final customProvider = _accessTokenProvider;
    if (customProvider != null) {
      final value = await customProvider();
      return value == null
          ? null
          : _CachedFcmAccessToken(
              value,
              _clock().toUtc().add(const Duration(hours: 1)),
            );
    }

    final baseClient = http.Client();
    try {
      final credentials = ServiceAccountCredentials.fromJson(
        config.serviceAccountJson!,
      );
      final authClient = await clientViaServiceAccount(credentials, const [
        _fcmScope,
      ], baseClient: baseClient);
      try {
        final token = authClient.credentials.accessToken;
        return _CachedFcmAccessToken(token.data, token.expiry.toUtc());
      } finally {
        authClient.close();
      }
    } finally {
      baseClient.close();
    }
  }

  static DateTime _utcNow() => DateTime.now().toUtc();
}

final class _CachedFcmAccessToken {
  const _CachedFcmAccessToken(this.value, this.expiresAt);

  final String value;
  final DateTime expiresAt;
}

/// Identity of this object is the refresh generation used for compare-and-set
/// cleanup after completion or timeout.
final class _FcmAccessTokenRefresh {
  const _FcmAccessTokenRefresh(this.future);

  final Future<_CachedFcmAccessToken?> future;
}

final class _FcmError {
  const _FcmError({this.status, this.fcmErrorCode});

  final String? status;
  final String? fcmErrorCode;

  /// FCM uses the provider-specific details entry to distinguish an invalid
  /// target from unrelated INVALID_ARGUMENT payload errors.
  bool get isInvalidRegistrationToken => fcmErrorCode == 'INVALID_ARGUMENT';

  static _FcmError? tryParse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map) return null;
      final error = decoded['error'];
      if (error is! Map) return null;
      String? fcmCode;
      final details = error['details'];
      if (details is List) {
        for (final detail in details) {
          if (detail is Map &&
              detail['@type'] ==
                  'type.googleapis.com/google.firebase.fcm.v1.FcmError') {
            fcmCode = detail['errorCode']?.toString();
            break;
          }
        }
      }
      return _FcmError(
        status: error['status']?.toString(),
        fcmErrorCode: fcmCode,
      );
    } catch (_) {
      return null;
    }
  }
}

String? _header(Map<String, String> headers, String name) {
  final normalized = name.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == normalized) return entry.value;
  }
  return null;
}
