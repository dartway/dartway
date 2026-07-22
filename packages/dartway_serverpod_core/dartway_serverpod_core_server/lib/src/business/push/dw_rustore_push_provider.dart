import 'dart:async';
import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import 'dw_push_http.dart';
import 'dw_push_provider.dart';
import 'dw_push_provider_utils.dart';

const _ruStoreHost = 'vkpns.rustore.ru';
const _pushTitleDataKey = 'push_title';
const _pushBodyDataKey = 'push_body';

final class DwRuStorePushProviderConfig {
  DwRuStorePushProviderConfig({
    required String? projectId,
    required String? serviceToken,
    String? androidIcon,
    String? androidColor,
    this.requestTimeout = const Duration(seconds: 10),
  }) : projectId = _trimToNull(projectId),
       serviceToken = _trimToNull(serviceToken),
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

  factory DwRuStorePushProviderConfig.fromPasswords(
    Map<String, String> passwords, {
    String projectIdKey = 'rustorePushProjectId',
    String serviceTokenKey = 'rustorePushServiceToken',
    String? androidIcon,
    String? androidColor,
    Duration requestTimeout = const Duration(seconds: 10),
  }) => DwRuStorePushProviderConfig(
    projectId: passwords[projectIdKey],
    serviceToken: passwords[serviceTokenKey],
    androidIcon: androidIcon,
    androidColor: androidColor,
    requestTimeout: requestTimeout,
  );

  final String? projectId;
  final String? serviceToken;
  final String? androidIcon;
  final String? androidColor;
  final Duration requestTimeout;

  bool get isConfigured => projectId != null && serviceToken != null;

  static String? _trimToNull(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

/// RuStore Push API provider using an application-supplied service token.
final class DwRuStorePushProvider implements DwPushProvider {
  DwRuStorePushProvider({
    required this.config,
    DwPushHttpClient? httpClient,
    DateTime Function()? clock,
  }) : _httpClient = httpClient ?? DwPushDefaultHttpClient(),
       _clock = clock ?? _utcNow;

  final DwRuStorePushProviderConfig config;
  final DwPushHttpClient _httpClient;
  final DateTime Function() _clock;
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
          'DwPush RuStore credentials are not configured',
          level: LogLevel.warning,
        );
      }
      return const DwPushProviderOutcome.permanentFailure(
        errorCode: 'rustore_not_configured',
      );
    }

    final encodedPayload = jsonEncode(_buildPayload(request));
    if (!dwPushProviderRequestFits(encodedPayload)) {
      return const DwPushProviderOutcome.permanentFailure(
        errorCode: 'rustore_payload_too_large',
      );
    }

    try {
      final response = await _httpClient
          .send(
            DwPushHttpRequest(
              method: 'POST',
              uri: Uri.https(
                _ruStoreHost,
                '/v1/projects/${config.projectId}/messages:send',
              ),
              headers: {
                'authorization': 'Bearer ${config.serviceToken}',
                'content-type': 'application/json',
              },
              body: encodedPayload,
            ),
          )
          .timeout(config.requestTimeout);
      return _classifyResponse(session, request.target, response);
    } on TimeoutException {
      session.log('DwPush RuStore request timed out', level: LogLevel.warning);
      return const DwPushProviderOutcome.retryableFailure(
        errorCode: 'rustore_timeout',
      );
    } catch (error, stackTrace) {
      session.log(
        'DwPush RuStore request failed (${dwPushSafeExceptionCode(error)})',
        level: LogLevel.warning,
        stackTrace: stackTrace,
      );
      return const DwPushProviderOutcome.retryableFailure(
        errorCode: 'rustore_exception',
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
    if (imageUrl != null) {
      providerData[_pushTitleDataKey] = payload.title;
      providerData[_pushBodyDataKey] = body;
      providerData[dwPushImageUrlDataKey] = imageUrl;
    }

    final message = <String, Object?>{
      'token': request.target,
      'data': providerData,
    };
    if (imageUrl == null) {
      message.addAll({
        'notification': {'title': payload.title, 'body': body},
        'android': {
          'notification': {
            'title': payload.title,
            'body': body,
            if (config.androidIcon != null) 'icon': config.androidIcon,
            if (config.androidColor != null) 'color': config.androidColor,
          },
        },
      });
    }
    return {'message': message};
  }

  DwPushProviderOutcome _classifyResponse(
    Session session,
    String target,
    DwPushHttpResponse response,
  ) {
    final error = _RuStoreError.tryParse(response.body);
    final code = dwPushProviderErrorCode(response.body);
    if (response.statusCode == 200) {
      return const DwPushProviderOutcome.accepted();
    }
    final invalidTarget =
        response.statusCode == 410 ||
        (response.statusCode == 404 && error?.status == 'NOT_FOUND') ||
        (response.statusCode == 400 &&
            error?.isInvalidRegistrationToken == true) ||
        error?.status == 'UNREGISTERED';
    if (invalidTarget) {
      session.log(
        'DwPush RuStore target is invalid: '
        '${dwPushTargetFingerprint(target)}',
        level: LogLevel.warning,
      );
      return const DwPushProviderOutcome.invalidTarget(
        errorCode: 'rustore_unregistered',
      );
    }
    if (response.statusCode == 408 ||
        response.statusCode == 429 ||
        response.statusCode >= 500) {
      final retryAfter = dwPushPositiveDuration(
        dwPushParseRetryAfter(
          _header(response.headers, 'retry-after'),
          _clock(),
        ),
      );
      return DwPushProviderOutcome.retryableFailure(
        errorCode: 'rustore_$code',
        retryAfter: retryAfter,
      );
    }
    return DwPushProviderOutcome.permanentFailure(errorCode: 'rustore_$code');
  }

  static DateTime _utcNow() => DateTime.now().toUtc();
}

final class _RuStoreError {
  const _RuStoreError({this.status, this.message});

  final String? status;
  final String? message;

  bool get isInvalidRegistrationToken {
    if (status != 'INVALID_ARGUMENT') return false;
    final normalized = message?.toLowerCase() ?? '';
    return normalized.contains('registration token') &&
        (normalized.contains('not a valid') || normalized.contains('invalid'));
  }

  static _RuStoreError? tryParse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map) return null;
      final error = decoded['error'];
      if (error is! Map) return null;
      return _RuStoreError(
        status: error['status']?.toString(),
        message: error['message']?.toString(),
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
