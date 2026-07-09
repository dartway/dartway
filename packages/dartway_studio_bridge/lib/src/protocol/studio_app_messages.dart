part of 'studio_bridge_message.dart';

/// App → Studio: announced on host attach (page load, hot restart).
class AppReadyMessage extends StudioBridgeMessage {
  const AppReadyMessage();

  @override
  String get type => StudioBridgeProtocol.appReady;
}

/// App → Studio: the handshake response — the full manifest plus the current
/// route, session and locale so Studio renders correctly right away.
class ManifestMessage extends StudioBridgeMessage {
  const ManifestMessage({
    required this.manifest,
    required this.currentPath,
    required this.session,
    this.features = const [],
    this.currentLocale = '',
  });

  final StudioProjectManifest manifest;
  final String currentPath;
  final StudioSessionState session;

  /// Features mounted on the current screen at connect time.
  final List<StudioFeatureInfo> features;

  /// Active UI locale, empty when the app is not localized.
  final String currentLocale;

  @override
  String get type => StudioBridgeProtocol.manifest;

  @override
  Map<String, dynamic> payloadToJson() => {
        'manifest': manifest.toJson(),
        'currentPath': currentPath,
        'session': session.toJson(),
        'features': [for (final f in features) f.toJson()],
        'currentLocale': currentLocale,
      };

  factory ManifestMessage.fromPayload(Map<String, dynamic> payload) =>
      ManifestMessage(
        manifest: StudioProjectManifest.fromJson(
          payload['manifest'] as Map<String, dynamic>? ?? const {},
        ),
        currentPath: payload['currentPath'] as String? ?? '/',
        session: StudioSessionState.fromJson(
          payload['session'] as Map<String, dynamic>? ?? const {},
        ),
        features: StudioFeatureInfo.listFromJson(payload['features']),
        currentLocale: payload['currentLocale'] as String? ?? '',
      );
}

/// App → Studio: the app's router moved to a new location.
class RouteChangedMessage extends StudioBridgeMessage {
  const RouteChangedMessage(this.path);

  final String path;

  @override
  String get type => StudioBridgeProtocol.routeChanged;

  @override
  Map<String, dynamic> payloadToJson() => {'path': path};

  factory RouteChangedMessage.fromPayload(Map<String, dynamic> payload) =>
      RouteChangedMessage(payload['path'] as String? ?? '/');
}

/// App → Studio: the features mounted on the current screen changed
/// (discovered from `DwFeature` widgets after the route settles).
class FeaturesChangedMessage extends StudioBridgeMessage {
  const FeaturesChangedMessage({required this.path, required this.features});

  final String path;
  final List<StudioFeatureInfo> features;

  @override
  String get type => StudioBridgeProtocol.featuresChanged;

  @override
  Map<String, dynamic> payloadToJson() => {
        'path': path,
        'features': [for (final f in features) f.toJson()],
      };

  factory FeaturesChangedMessage.fromPayload(Map<String, dynamic> payload) =>
      FeaturesChangedMessage(
        path: payload['path'] as String? ?? '/',
        features: StudioFeatureInfo.listFromJson(payload['features']),
      );
}

/// App → Studio: the app's UI locale changed.
class LocaleChangedMessage extends StudioBridgeMessage {
  const LocaleChangedMessage(this.locale);

  final String locale;

  @override
  String get type => StudioBridgeProtocol.localeChanged;

  @override
  Map<String, dynamic> payloadToJson() => {'locale': locale};

  factory LocaleChangedMessage.fromPayload(Map<String, dynamic> payload) =>
      LocaleChangedMessage(payload['locale'] as String? ?? '');
}

/// App → Studio: the session changed (sign-in, sign-out, switch progress).
class SessionChangedMessage extends StudioBridgeMessage {
  const SessionChangedMessage(this.session);

  final StudioSessionState session;

  @override
  String get type => StudioBridgeProtocol.sessionChanged;

  @override
  Map<String, dynamic> payloadToJson() => {'session': session.toJson()};

  factory SessionChangedMessage.fromPayload(Map<String, dynamic> payload) =>
      SessionChangedMessage(
        StudioSessionState.fromJson(
          payload['session'] as Map<String, dynamic>? ?? const {},
        ),
      );
}
