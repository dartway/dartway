import 'dart:convert';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_push_shared/dartway_push_shared.dart';
import 'package:test/test.dart';

/// A project's payload, written as `dartway generate` writes one.
final class NewsAlert extends DwDataObject {
  const NewsAlert({required this.id, required this.title});

  @override
  final int id;
  final String title;

  @override
  String get dwTypeName => 'NewsAlert';

  @override
  Map<String, Object?> toJson() => {'id': id, 'title': title};

  static NewsAlert fromJson(Map<String, Object?> json) =>
      NewsAlert(id: json['id']! as int, title: json['title']! as String);

  @override
  bool operator ==(Object other) =>
      other is NewsAlert && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);
}

final class ReadNews extends DwActionCommand<void> {
  const ReadNews();

  @override
  String get dwTypeName => 'ReadNews';

  @override
  Map<String, Object?> toJson() => const {};
}

final protocol = DwWireProtocol([
  ...dwPushProtocolEntries,
  const DwProtocolEntry<NewsAlert>('NewsAlert', NewsAlert.fromJson),
  DwProtocolEntry<ReadNews>('ReadNews', (_) => const ReadNews()),
], include: DwWireProtocol.core);

void main() {
  group('DwPushData', () {
    test('round-trips a typed payload and a link through a string map', () {
      const data = DwPushData(
        payload: NewsAlert(id: 12, title: 'Pool closed'),
        link: '/news/12',
      );
      final wire = data.toWire();
      expect(wire, {
        'dw_type': 'NewsAlert',
        'dw_payload': jsonEncode({'id': 12, 'title': 'Pool closed'}),
        'dw_link': '/news/12',
      });
      // Providers hand the map back with values typed as `Object?`.
      final back = DwPushData.fromWire(
        Map<Object?, Object?>.of(wire),
        protocol,
      );
      expect(back, data);
      expect(back.payload, isA<NewsAlert>());
    });

    test('carries nothing it was not given', () {
      expect(const DwPushData().toWire(), isEmpty);
      expect(const DwPushData(link: '/a').toWire(), {'dw_link': '/a'});
      expect(DwPushData.fromWire({'other': 'x'}, protocol).isEmpty, isTrue);
      expect(DwPushData.fromWire({'dw_link': ''}, protocol).link, isNull);
    });

    test('refuses a payload the protocol cannot read', () {
      expect(
        () => DwPushData.fromWire({
          'dw_type': 'Unknown',
          'dw_payload': '{}',
        }, protocol),
        throwsFormatException,
      );
      expect(
        () => DwPushData.fromWire({
          'dw_type': 'ReadNews',
          'dw_payload': '{}',
        }, protocol),
        throwsFormatException,
        reason: 'only data objects are payloads',
      );
      expect(
        () => DwPushData.fromWire({'dw_type': 'NewsAlert'}, protocol),
        throwsFormatException,
      );
    });
  });

  group('commands', () {
    test('encode and decode through the protocol', () {
      const register = DwRegisterPushToken(
        transport: DwPushTransport.rustore,
        token: 'abc:123',
        platform: DwPushPlatform.android,
      );
      expect(register.toJson(), {
        'transport': 'rustore',
        'token': 'abc:123',
        'platform': 'android',
      });
      expect(
        protocol.decodeNamed('DwRegisterPushToken', register.toJson()),
        register,
      );
      const unregister = DwUnregisterPushToken(token: 'abc:123');
      expect(
        protocol.decodeNamed('DwUnregisterPushToken', unregister.toJson()),
        unregister,
      );
      expect(
        register.toString(),
        isNot(contains('abc')),
        reason: 'a token is not logged',
      );
    });

    test('validate the token on both sides', () {
      DwRegisterPushToken withToken(String token) => DwRegisterPushToken(
        transport: DwPushTransport.fcm,
        token: token,
        platform: DwPushPlatform.web,
      );
      expect(withToken('ok-token').validate(), isEmpty);
      for (final bad in ['', ' padded', 'new\nline', 'x' * 1025]) {
        expect(
          withToken(bad).validate().single.code,
          'dw.pushTokenInvalid',
          reason: jsonEncode(bad),
        );
        expect(DwUnregisterPushToken(token: bad).validate(), hasLength(1));
      }
    });
  });
}
