import 'dart:convert';

import 'package:dartway_core_server/src/files/dw_sigv4_signer.dart';
import 'package:test/test.dart';

/// Signature Version 4 against the vectors AWS publishes: the generic
/// `aws-sig-v4-test-suite` (as vendored by botocore, Apache-2.0) and the
/// S3 examples of the S3 API reference ("Signature calculations for the
/// Authorization header" and "Authenticating requests: using query
/// parameters"). No services needed.
void main() {
  group('the AWS SigV4 test suite', () {
    // Every vector of the suite uses these.
    final signer = DwSigV4Signer(
      accessKey: 'AKIDEXAMPLE',
      secretKey: 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY',
      region: 'us-east-1',
      service: 'service',
    );
    final time = DateTime.utc(2015, 8, 30, 12, 36);

    /// One vector: the request (path and query decoded, headers in order),
    /// and what the suite says its canonical request, string to sign and
    /// signature are.
    void vector(
      String name, {
      String method = 'GET',
      String path = '/',
      List<(String, String)> query = const [],
      List<(String, String)> headers = const [],
      String body = '',
      required String canonicalRequest,
      required String stringToSignHash,
      required String signature,
    }) {
      test(name, () {
        final allHeaders = [
          ('Host', 'example.amazonaws.com'),
          ...headers,
          ('X-Amz-Date', '20150830T123600Z'),
        ];
        final canonical = DwSigV4Signer.canonicalRequest(
          method: method,
          path: path,
          query: query,
          headers: allHeaders,
          payloadHash: DwSigV4Signer.hexSha256(utf8.encode(body)),
        );
        expect(canonical, canonicalRequest);
        final toSign = signer.stringToSign(time, canonical);
        expect(
          toSign,
          'AWS4-HMAC-SHA256\n20150830T123600Z\n'
          '20150830/us-east-1/service/aws4_request\n$stringToSignHash',
        );
        expect(signer.signature(time, toSign), signature);
      });
    }

    const empty =
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

    vector(
      'get-vanilla',
      canonicalRequest:
          'GET\n/\n\nhost:example.amazonaws.com\n'
          'x-amz-date:20150830T123600Z\n\nhost;x-amz-date\n$empty',
      stringToSignHash:
          'bb579772317eb040ac9ed261061d46c1f17a8133879d6129b6e1c25292927e63',
      signature:
          '5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31',
    );

    vector(
      'get-vanilla-query-order-key-case',
      query: const [('Param2', 'value2'), ('Param1', 'value1')],
      canonicalRequest:
          'GET\n/\nParam1=value1&Param2=value2\nhost:example.amazonaws.com\n'
          'x-amz-date:20150830T123600Z\n\nhost;x-amz-date\n$empty',
      stringToSignHash:
          '816cd5b414d056048ba4f7c5386d6e0533120fb1fcfa93762cf0fc39e2cf19e0',
      signature:
          'b97d918cfa904a5beff61c982a1b6f458b799221646efd99d3219ec94cdf2500',
    );

    const unreserved =
        '-._~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

    vector(
      'get-vanilla-query-unreserved',
      query: const [(unreserved, unreserved)],
      canonicalRequest:
          'GET\n/\n$unreserved=$unreserved\nhost:example.amazonaws.com\n'
          'x-amz-date:20150830T123600Z\n\nhost;x-amz-date\n$empty',
      stringToSignHash:
          'c30d4703d9f799439be92736156d47ccfb2d879ddf56f5befa6d1d6aab979177',
      signature:
          '9c3e54bfcdf0b19771a7f523ee5669cdf59bc7cc0884027167c21bb143a40197',
    );

    vector(
      'get-unreserved',
      path: '/$unreserved',
      canonicalRequest:
          'GET\n/$unreserved\n\nhost:example.amazonaws.com\n'
          'x-amz-date:20150830T123600Z\n\nhost;x-amz-date\n$empty',
      stringToSignHash:
          '6a968768eefaa713e2a6b16b589a8ea192661f098f37349f4e2c0082757446f9',
      signature:
          '07ef7494c76fa4850883e2b006601f940f8a34d404d0cfa977f52a65bbf5f24f',
    );

    vector(
      'get-utf8',
      path: '/ሴ',
      canonicalRequest:
          'GET\n/%E1%88%B4\n\nhost:example.amazonaws.com\n'
          'x-amz-date:20150830T123600Z\n\nhost;x-amz-date\n$empty',
      stringToSignHash:
          '2a0a97d02205e45ce2e994789806b19270cfbbb0921b278ccf58f5249ac42102',
      signature:
          '8318018e0b0f223aa2bbf98705b62bb787dc9c0e678f255a891fd03141be5d85',
    );

    vector(
      'get-vanilla-utf8-query',
      query: const [('ሴ', 'bar')],
      canonicalRequest:
          'GET\n/\n%E1%88%B4=bar\nhost:example.amazonaws.com\n'
          'x-amz-date:20150830T123600Z\n\nhost;x-amz-date\n$empty',
      stringToSignHash:
          'eb30c5bed55734080471a834cc727ae56beb50e5f39d1bff6d0d38cb192a7073',
      signature:
          '2cdec8eed098649ff3a119c94853b13c643bcf08f8b0a1d91e12c9027818dd04',
    );

    vector(
      'get-header-key-duplicate',
      headers: const [
        ('My-Header1', 'value2'),
        ('My-Header1', 'value2'),
        ('My-Header1', 'value1'),
      ],
      canonicalRequest:
          'GET\n/\n\nhost:example.amazonaws.com\n'
          'my-header1:value2,value2,value1\nx-amz-date:20150830T123600Z\n\n'
          'host;my-header1;x-amz-date\n$empty',
      stringToSignHash:
          'dc7f04a3abfde8d472b0ab1a418b741b7c67174dad1551b4117b15527fbe966c',
      signature:
          'c9d5ea9f3f72853aea855b47ea873832890dbdd183b4468f858259531a5138ea',
    );

    vector(
      'get-header-value-trim',
      headers: const [
        ('My-Header1', ' value1'),
        ('My-Header2', ' "a   b   c"'),
      ],
      canonicalRequest:
          'GET\n/\n\nhost:example.amazonaws.com\nmy-header1:value1\n'
          'my-header2:"a b c"\nx-amz-date:20150830T123600Z\n\n'
          'host;my-header1;my-header2;x-amz-date\n$empty',
      stringToSignHash:
          'a726db9b0df21c14f559d0a978e563112acb1b9e05476f0a6a1c7d68f28605c7',
      signature:
          'acc3ed3afb60bb290fc8d2dd0098b9911fcaa05412b367055dee359757a9c736',
    );

    vector(
      'post-vanilla-query',
      method: 'POST',
      query: const [('Param1', 'value1')],
      canonicalRequest:
          'POST\n/\nParam1=value1\nhost:example.amazonaws.com\n'
          'x-amz-date:20150830T123600Z\n\nhost;x-amz-date\n$empty',
      stringToSignHash:
          '9d659678c1756bb3113e2ce898845a0a79dbbc57b740555917687f1b3340fbbd',
      signature:
          '28038455d6de14eafc1f9222cf5aa6f1a96197d7deb8263271d420d138af7f11',
    );

    vector(
      'post-x-www-form-urlencoded',
      method: 'POST',
      headers: const [('Content-Type', 'application/x-www-form-urlencoded')],
      body: 'Param1=value1',
      canonicalRequest:
          'POST\n/\n\ncontent-type:application/x-www-form-urlencoded\n'
          'host:example.amazonaws.com\nx-amz-date:20150830T123600Z\n\n'
          'content-type;host;x-amz-date\n'
          '9095672bbd1f56dfc5b65f3e153adc8731a4a654192329106275f4c7b24d0b6e',
      stringToSignHash:
          '42a5e5bb34198acb3e84da4f085bb7927f2bc277ca766e6d19c73c2154021281',
      signature:
          'ff11897932ad3f4e8b18135d722051e5ac45fc38421b1da7b9d196a0fe09473a',
    );
  });

  group('the S3 API reference examples', () {
    final signer = DwSigV4Signer(
      accessKey: 'AKIAIOSFODNN7EXAMPLE',
      secretKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
      region: 'us-east-1',
    );
    final time = DateTime.utc(2013, 5, 24);
    const host = 'examplebucket.s3.amazonaws.com';

    String authorization(Map<String, String> headers) =>
        headers['authorization']!.split('Signature=').last;

    test('GET Object, header-signed', () {
      final headers = signer.authorizationHeaders(
        method: 'GET',
        path: '/test.txt',
        headers: const [('host', host), ('range', 'bytes=0-9')],
        payloadHash: DwSigV4Signer.emptyPayloadHash,
        time: time,
      );
      expect(headers['x-amz-date'], '20130524T000000Z');
      expect(headers['x-amz-content-sha256'], DwSigV4Signer.emptyPayloadHash);
      expect(
        headers['authorization'],
        'AWS4-HMAC-SHA256 '
        'Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request, '
        'SignedHeaders=host;range;x-amz-content-sha256;x-amz-date, '
        'Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41',
      );
    });

    test(r'PUT Object: a "$" in the key is encoded once', () {
      final headers = signer.authorizationHeaders(
        method: 'PUT',
        path: r'/test$file.text',
        headers: const [
          ('date', 'Fri, 24 May 2013 00:00:00 GMT'),
          ('host', host),
          ('x-amz-storage-class', 'REDUCED_REDUNDANCY'),
        ],
        payloadHash: DwSigV4Signer.hexSha256(
          utf8.encode('Welcome to Amazon S3.'),
        ),
        time: time,
      );
      expect(
        authorization(headers),
        '98ad721746da40c64f1a55b78f14c238d841ea1380cd77a1b5971af0ece108bd',
      );
    });

    test('GET Bucket lifecycle: a parameter without a value', () {
      final headers = signer.authorizationHeaders(
        method: 'GET',
        path: '/',
        query: const [('lifecycle', '')],
        headers: const [('host', host)],
        payloadHash: DwSigV4Signer.emptyPayloadHash,
        time: time,
      );
      expect(
        authorization(headers),
        'fea454ca298b7da1c68078a5d1bdbfbbe0d65c699e0f91ac7a200a0136783543',
      );
    });

    test('GET Bucket (list objects): parameters in order', () {
      final headers = signer.authorizationHeaders(
        method: 'GET',
        path: '/',
        query: const [('prefix', 'J'), ('max-keys', '2')],
        headers: const [('host', host)],
        payloadHash: DwSigV4Signer.emptyPayloadHash,
        time: time,
      );
      expect(
        authorization(headers),
        '34b48302e7b5fa45bde8084f4b7868a86f0a534bc59db6670ed5711ef69dc6f7',
      );
    });

    test('a presigned GET URL', () {
      final query = signer.presignedQuery(
        method: 'GET',
        path: '/test.txt',
        headers: const [('host', host)],
        expires: const Duration(days: 1),
        time: time,
      );
      expect(
        query,
        'X-Amz-Algorithm=AWS4-HMAC-SHA256'
        '&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request'
        '&X-Amz-Date=20130524T000000Z&X-Amz-Expires=86400'
        '&X-Amz-SignedHeaders=host'
        '&X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404',
      );
    });
  });

  group('encoding', () {
    test('keeps only the unreserved characters, and "/" in paths', () {
      expect(DwSigV4Signer.encode('a b+c/d=é'), 'a%20b%2Bc%2Fd%3D%C3%A9');
      expect(
        DwSigV4Signer.encode('avatar/7/x-_.~.png', keepSlash: true),
        'avatar/7/x-_.~.png',
      );
    });

    test('dates are basic ISO 8601 in UTC', () {
      expect(
        DwSigV4Signer.amzDate(DateTime.utc(2026, 9, 4, 3, 5, 9, 999)),
        '20260904T030509Z',
      );
      expect(
        DwSigV4Signer.amzDate(DateTime.parse('2026-09-14T02:00:00+04:00')),
        '20260913T220000Z',
      );
    });
  });
}
