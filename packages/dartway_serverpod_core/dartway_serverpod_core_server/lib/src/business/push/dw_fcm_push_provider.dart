import 'dart:async';
import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

import 'dw_push_http.dart';
import 'dw_push_provider.dart';
import 'dw_push_provider_utils.dart';

const _fcmScope = 'https://www.googleapis.com/auth/firebase.messaging';
const _fcmHost = 'fcm.googleapis.com';

typedef DwFcmAccessTokenProvider = Future<String?> Function();

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
  }

  factory DwFcmPushProviderConfig.fromPasswords(
    Map<String, String> passwords, {
    String projectIdKey = 'fcmProjectId',
    String serviceAccountJsonKey = 'fcmServiceAccountJson',
    String? webpushIcon,
    String? androidIcon,
    String? androidColor,
    Duration requestTimeout = const Duration(seconds: 10),
  }) => DwFcmPushProviderConfig(
    projectId: passwords[projectIdKey],
    serviceAccountJson: passwords[serviceAccountJsonKey],
    webpushIcon: webpushIcon,
    androidIcon: androidIcon,
    androidColor: androidColor,
    requestTimeout: requestTimeout,
  );

  final String? projectId;
  final String? serviceAccountJson;
  final String? webpushIcon;
  final String? androidIcon;
  final String? androidColor;
  final Duration requestTimeout;

  bool get isConfigured => projectId != null && serviceAccountJson != null;

  static String? _trimToNull(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
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

    return {
      'message': {
        'token': request.target,
        'notification': {
          'title': payload.title,
          'body': body,
          if (imageUrl != null) 'image': imageUrl,
        },
        'data': providerData,
        if (imageUrl != null || androidIcon != null || androidColor != null)
          'android': {
            'notification': {
              if (imageUrl != null) 'image': imageUrl,
              if (androidIcon != null) 'icon': androidIcon,
              if (androidColor != null) 'color': androidColor,
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
        if (imageUrl != null || webpushIcon != null)
          'webpush': {
            'notification': {
              if (imageUrl != null) 'image': imageUrl,
              if (webpushIcon != null) 'icon': webpushIcon,
            },
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
