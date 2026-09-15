import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../providers/dw_fcm_provider.dart';
import '../providers/dw_rustore_provider.dart';

/// An RSA key generated for tests: it signs the assertions of the service
/// account [DwFakePushService.serviceAccountJson] makes, which only the fake's
/// token endpoint accepts. It authorizes nothing anywhere else.
const String dwFakePushPrivateKey = '''
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC5PDH3OBaqeOCz
mILwvMOa4DgkeM1nITYgbKKB/yUdHbVdEmKwrooDgbC4kkldAG5JRReDFEmKBOEH
ESUbtI+3UfF5wA1XlgkZz79gSGVGDG53hVvgCOQtPXla/XrizbbZfT3cksFXDkr/
gKuxctoRwvtMV+B6GAv8MtMiUFGtetQSTiexKMuKS2rTHitELBbVmsy/y10Ju4Je
/9lWHsomCg0RjQZw96VeAvMAEWdv9c4kRSCYizl1d1bwA3TIQquRDHCf//aq9LhI
a6yx0khdCB4T9XZWb5Gawz4baoVGbMl6qfH18f2BW+U4QlNWNHlwvkzjGKR9lEiP
pwlqlsXnAgMBAAECggEAQaUhCf1RHwnmjA80/E7RPV5P1zEOjglZjsUhFFPRGc/w
+bJt0jKQy6xW7ho9sJ1Z+FJpgjUa2LRg8Sm0zmw/cFa0bpLOx6buw7x5lIwjg98c
+POEe1F7V8MM8l+ZgK4pqkr1tOk3Znw0vPajIihTOu8wMr6D2ZETEkYKyALR51ng
kzoHLT81Ch1v8k0VhTrMXqthOOLv0xpMNOo6TcweyqE8ecwaMp2CWgRpzW7/f8iq
mRZaF0SWhAnN2UF879sxHQ1W9k9h4ZLPWueijwoZht/5Xo2VSh2hycutaFkSu+7G
/FZsvlh3bzxJXNugjB+Af7N+qGEoffdz+mAcrWjs8QKBgQDw4UaVHGQn9391DaLr
sfWBb+x9SnUYNy0dNuLOKYXgLnvDYG1YloTyU7GMS/Ri/SrSxnfQoQhggxXcc9xO
ivumK8d8K4pGllqajvvqkxU063YgirHrbL9KC3Vn2wLvjJ6R8HD6QTYPHOATkR/Q
Ig76FoEGaqAR5X+gpm5W/+aVVwKBgQDE3MHGReNIkyCtYoiG2AUWJ8P4dLOSI3FJ
hAkDevYwktPdikCkPUnxzSblObqLVkgewaYPTBsXPQJ7weSr3YCt7i8oc4ew1Jqi
jAqB2MLmie4AndwSZzIV42ZLFqFMDV8Z8vl+kTOBGRaWpJ3G1Y1OBnEe24rENyO6
xxb3ySjp8QKBgQDJNeSXudeP6xX02Sc2arkBHlUVc5TMXYq51JcwT08dLLcFRQ8R
6Om04mR1JR1HcuLKni6Hf3xX4ifotn9YvI/pBrjj6BrhS8bzRGz6TVJxmh5aoIBu
f7BqUZgI4NFa+MOcdJRq9v4JMb2bmqZQXaLVFOdCTN7ZFDPAJkYVNj2OkQKBgQCw
nQ0LgK/D8Jskcn3h2/PUSKC8Spa/ySRdvCMKCErOkSuaWepcbs/kKxV2GTCOyT2y
ujDtEG5NjuKnfPBWcEZ9xG5ycBOQRWzl35WdoIZapevsibNin0qD8JtZSlgzDtv/
P8kuD76RV5y4Ub9rHzPCiGz8LiJ0nrNjYjHs43/dQQKBgCunbmkDI0y8xbOkyxG6
+Z3o56OOxy2Cp44zB/cE326eORP7hTOQWcA2t9m3jMKC6sT+SmDqC3fasQw2VcrZ
hg6miACPX/7cLegrlgQ1eXkU8D3D8oxqUNn524OC5luFUcXwGI9PxWmls2lgvgSQ
ipifiAcQQNtFbtTitDa7zuoe
-----END PRIVATE KEY-----
''';

const String _modulusHex =
    'B93C31F73816AA78E0B39882F0BCC39AE0382478CD672136206CA281FF251D1DB55D1262B0AE8A0381B0B892495D006E4945178314498A04E10711251BB48FB751F179C00D57960919CFBF604865460C6E77855BE008E42D3D795AFD7AE2CDB6D97D3DDC92C1570E4AFF80ABB172DA11C2FB4C57E07A180BFC32D3225051AD7AD4124E27B128CB8A4B6AD31E2B442C16D59ACCBFCB5D09BB825EFFD9561ECA260A0D118D0670F7A55E02F30011676FF5CE244520988B39757756F00374C842AB910C709FFFF6AAF4B8486BACB1D2485D081E13F576566F919AC33E1B6A85466CC97AA9F1F5F1FD815BE538425356347970BE4CE318A47D94488FA7096A96C5E7';

const int _publicExponent = 65537;

/// What the fake answers one request with.
final class DwFakePushAnswer {
  const DwFakePushAnswer(
    this.status, [
    this.body = '{}',
    this.headers = const {},
  ]);

  const DwFakePushAnswer.ok()
    : this(200, '{"name":"projects/test/messages/1"}');

  /// FCM's documented error shape.
  factory DwFakePushAnswer.fcmError(
    int status,
    String googleStatus,
    String message, {
    String? fcmCode,
    Map<String, String> headers = const {},
  }) => DwFakePushAnswer(
    status,
    jsonEncode({
      'error': {
        'code': status,
        'message': message,
        'status': googleStatus,
        'details': [
          if (fcmCode != null)
            {
              '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
              'errorCode': fcmCode,
            },
        ],
      },
    }),
    headers,
  );

  /// RuStore's documented error shape.
  factory DwFakePushAnswer.ruStoreError(
    int status,
    String googleStatus,
    String message,
  ) => DwFakePushAnswer(
    status,
    jsonEncode({
      'error': {'code': status, 'message': message, 'status': googleStatus},
    }),
  );

  final int status;
  final String body;
  final Map<String, String> headers;
}

final class DwFakePushSend {
  DwFakePushSend(this.path, this.authorization, this.contentType, this.body);

  final String path;
  final String? authorization;
  final String? contentType;
  final Map<String, Object?> body;

  Map<String, Object?> get message => body['message']! as Map<String, Object?>;

  String get token => message['token']! as String;
}

/// An HTTP service on loopback speaking a provider's send API and, for FCM,
/// Google's OAuth token endpoint — which verifies the assertion's RS256
/// signature against the test key's public half.
final class DwFakePushService {
  DwFakePushService._(this._server) {
    _server.listen(_handle);
  }

  static Future<DwFakePushService> start() async => DwFakePushService._(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
  );

  final HttpServer _server;

  Uri get endpoint => Uri.parse('http://127.0.0.1:${_server.port}');

  final List<DwFakePushSend> sends = [];
  final List<Map<String, String>> tokenRequests = [];
  final List<Map<String, Object?>> assertions = [];

  /// The answer to a send; by default accepted.
  FutureOr<DwFakePushAnswer> Function(DwFakePushSend send) answer = (_) =>
      const DwFakePushAnswer.ok();

  /// Held before answering every send, when set.
  Duration delay = Duration.zero;

  /// Sends wait here while it is set and not completed.
  Completer<void>? gate;

  /// The token endpoint refuses every assertion, as Google does a key that
  /// was deleted.
  bool refuseTokens = false;

  /// Sends are answered by closing the connection without a response.
  bool dropConnections = false;

  int inFlight = 0;
  int maxInFlight = 0;

  int _accessTokens = 0;
  String get lastAccessToken => 'access-$_accessTokens';

  /// Service account JSON whose token endpoint is this fake.
  String serviceAccountJson({String projectId = 'test-project'}) => jsonEncode({
    'type': 'service_account',
    'project_id': projectId,
    'private_key_id': 'test-key-1',
    'private_key': dwFakePushPrivateKey,
    'client_email': 'push@test-project.iam.gserviceaccount.com',
    'token_uri': endpoint.replace(path: '/token').toString(),
  });

  Future<void> _handle(HttpRequest request) async {
    final text = await utf8.decodeStream(request);
    if (request.uri.path == '/token') {
      final form = Uri.splitQueryString(text);
      tokenRequests.add(form);
      final claims = refuseTokens
          ? null
          : verifyAssertion(form['assertion'] ?? '');
      if (claims == null) {
        return _write(
          request,
          const DwFakePushAnswer(
            400,
            '{"error":"invalid_grant","error_description":"Invalid JWT Signature."}',
          ),
        );
      }
      assertions.add(claims);
      _accessTokens++;
      return _write(
        request,
        DwFakePushAnswer(
          200,
          jsonEncode({
            'access_token': lastAccessToken,
            'expires_in': 3599,
            'token_type': 'Bearer',
          }),
        ),
      );
    }
    final send = DwFakePushSend(
      request.uri.path,
      request.headers.value('authorization'),
      request.headers.contentType?.mimeType,
      jsonDecode(text) as Map<String, Object?>,
    );
    sends.add(send);
    if (dropConnections) {
      final socket = await request.response.detachSocket(writeHeaders: false);
      socket.destroy();
      return;
    }
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      await gate?.future;
      await _write(request, await answer(send));
    } finally {
      inFlight--;
    }
  }

  Future<void> _write(HttpRequest request, DwFakePushAnswer answer) async {
    request.response.statusCode = answer.status;
    request.response.headers.contentType = ContentType.json;
    answer.headers.forEach(request.response.headers.set);
    request.response.write(answer.body);
    await request.response.close();
  }

  Future<void> close() => _server.close(force: true);

  /// The claims of an RS256 JWT signed by the test key, or `null` when the
  /// signature does not verify.
  static Map<String, Object?>? verifyAssertion(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    List<int> decode(String part) =>
        base64Url.decode(base64Url.normalize(part));
    final signature = decode(parts[2]);
    final n = BigInt.parse(_modulusHex, radix: 16);
    var s = BigInt.zero;
    for (final byte in signature) {
      s = (s << 8) | BigInt.from(byte);
    }
    final m = s.modPow(BigInt.from(_publicExponent), n);
    final digest = sha256.convert(utf8.encode('${parts[0]}.${parts[1]}'));
    final hex = m.toRadixString(16);
    // 01 FF…FF 00 DigestInfo(sha256) digest — leading 00 dropped by BigInt.
    final expectedTail =
        '003031300d060960864801650304020105000420${digest.toString()}';
    if (!hex.startsWith('1ff') || !hex.endsWith(expectedTail)) return null;
    final header = jsonDecode(utf8.decode(decode(parts[0])));
    if (header is! Map || header['alg'] != 'RS256') return null;
    return jsonDecode(utf8.decode(decode(parts[1]))) as Map<String, Object?>;
  }
}

extension DwFakePushProviders on DwFakePushService {
  /// An FCM provider sending to this fake, with its service account.
  DwFcmProvider fcmProvider({Uri? webLinkBase}) => DwFcmProvider(
    account: DwFcmServiceAccount.fromJson(serviceAccountJson()),
    endpoint: endpoint,
    webLinkBase: webLinkBase,
    requestTimeout: const Duration(seconds: 5),
  );

  /// A RuStore provider sending to this fake.
  DwRuStoreProvider ruStoreProvider({String projectId = 'rustore-project'}) =>
      DwRuStoreProvider(
        projectId: projectId,
        serviceToken: 'rustore-service-token',
        endpoint: endpoint,
        requestTimeout: const Duration(seconds: 5),
      );
}
