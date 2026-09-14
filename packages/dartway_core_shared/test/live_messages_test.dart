import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:test/test.dart';

import 'support/protocol.dart';

void main() {
  group('client → server', () {
    test('auth, sub and unsub round-trip in the R2.2 shape', () {
      final messages = <DwClientMessage, Map<String, Object?>>{
        const DwAuthenticateMessage('token'): {'k': 'auth', 'token': 'token'},
        const DwAuthenticateMessage(null): {'k': 'auth'},
        const DwSubscribeMessage('chat:7'): {'k': 'sub', 'ch': 'chat:7'},
        const DwUnsubscribeMessage('chat:7'): {'k': 'unsub', 'ch': 'chat:7'},
      };
      for (final MapEntry(key: message, value: json) in messages.entries) {
        expect(message.toJson(), json);
        final back = DwClientMessage.fromJson(roundTrip(message.toJson()));
        expect(back.runtimeType, message.runtimeType);
        expect(back.toJson(), json);
      }
    });

    test('calls do not travel over the socket', () {
      for (final kind in ['req', 'cmd', 'res']) {
        expect(
          () => DwClientMessage.fromJson({'k': kind, 'id': 1}),
          throwsFormatException,
        );
      }
    });

    test('a malformed client message is a FormatException', () {
      for (final json in <Object?>[
        null,
        {'k': 'sub'},
        {'k': 'sub', 'ch': 7},
        {'k': 'auth', 'token': 1},
        {'k': 'auth', 'tokn': 'x'},
      ]) {
        expect(
          () => DwClientMessage.fromJson(roundTrip(json)),
          throwsFormatException,
          reason: '$json',
        );
      }
    });
  });

  group('server → client', () {
    DwServerMessage back(DwServerMessage message) =>
        DwServerMessage.fromJson(roundTrip(message.toJson()), protocol);

    test('hello names the connection', () {
      const hello = DwHelloMessage('c-1');
      expect(hello.toJson(), {'k': 'hello', 'connection': 'c-1'});
      expect((back(hello) as DwHelloMessage).connectionId, 'c-1');
    });

    test('authed: an account, anonymous, or rejected', () {
      final account =
          back(const DwAuthenticatedMessage.account(7))
              as DwAuthenticatedMessage;
      expect(account.accountId, 7);
      expect(account.rejected, isFalse);

      expect(const DwAuthenticatedMessage.anonymous().toJson(), {
        'k': 'authed',
      });
      final anonymous =
          back(const DwAuthenticatedMessage.anonymous())
              as DwAuthenticatedMessage;
      expect(anonymous.accountId, isNull);
      expect(anonymous.rejected, isFalse);

      expect(const DwAuthenticatedMessage.rejected().toJson(), {
        'k': 'authed',
        'rejected': true,
      });
      final rejected =
          back(const DwAuthenticatedMessage.rejected())
              as DwAuthenticatedMessage;
      expect(rejected.rejected, isTrue);

      expect(
        () => DwServerMessage.fromJson({
          'k': 'authed',
          'account': 7,
          'rejected': true,
        }, protocol),
        throwsFormatException,
      );
    });

    test('subok and closed', () {
      expect(
        (back(const DwSubscribedMessage('news')) as DwSubscribedMessage)
            .channel,
        'news',
      );
      expect(
        (back(const DwChannelClosedMessage('chat:7')) as DwChannelClosedMessage)
            .channel,
        'chat:7',
      );
    });

    test('subno is refused, unauthenticated or failed', () {
      DwSubscriptionRefusedMessage refusedBack(
        DwSubscriptionRefusedMessage m,
      ) => back(m) as DwSubscriptionRefusedMessage;

      final refused = refusedBack(
        DwSubscriptionRefusedMessage.refused(
          'chat:7',
          DwCallRefusal(DwCoreRefusal.forbidden),
        ),
      );
      expect(refused.refusal, DwCallRefusal(DwCoreRefusal.forbidden));
      expect(refused.incidentId, isNull);
      expect(refused.isUnauthenticated, isFalse);

      final anonymous = refusedBack(
        const DwSubscriptionRefusedMessage.unauthenticated('chat:7'),
      );
      expect(anonymous.isUnauthenticated, isTrue);

      final failed = refusedBack(
        const DwSubscriptionRefusedMessage.failed('chat:7', 'inc-1'),
      );
      expect(failed.incidentId, 'inc-1');
      expect(failed.refusal, isNull);
      expect(failed.isUnauthenticated, isFalse);

      expect(
        () => DwServerMessage.fromJson({
          'k': 'subno',
          'ch': 'chat:7',
          'r': {'code': 'dw.forbidden'},
          'x': 'inc-1',
        }, protocol),
        throwsFormatException,
      );
    });

    test('upd names its channel and carries its objects by type, typed on '
        'arrival', () {
      final message = DwUpdateMessage(
        channel: 'myBookings:3',
        updates: DwChannelUpdates([
          booking,
          DwDeletedObject.of<ClubBooking>(8, protocol),
        ]),
      );
      expect(roundTrip(message.toJson()), {
        'k': 'upd',
        'ch': 'myBookings:3',
        'updates': {
          'ClubBooking': [booking.toJson()],
          'DwDeletedObject': [
            {'type': 'ClubBooking', 'id': 8},
          ],
        },
      });
      final decoded = back(message) as DwUpdateMessage;
      expect(decoded.channel, 'myBookings:3');
      expect(decoded.updates, message.updates);
      expect(decoded.updates.objects.first, isA<ClubBooking>());
      final deleted = decoded.updates.objects.last as DwDeletedObject;
      expect(deleted.isOf<ClubBooking>(protocol), isTrue);
    });

    test('an unknown or malformed server message is a FormatException', () {
      for (final json in <Object?>[
        {'k': 'res', 'id': 1},
        {'k': 'hello'},
        {'k': 'upd', 'ch': 'x'},
        {'k': 'upd', 'ch': 'x', 'items': []},
        {'k': 'closed', 'ch': 'x', 'reason': 'y'},
      ]) {
        expect(
          () => DwServerMessage.fromJson(roundTrip(json), protocol),
          throwsFormatException,
          reason: '$json',
        );
      }
    });
  });

  test('close codes are distinct', () {
    final codes = [
      DwCloseCode.serverStopping,
      DwCloseCode.unsupportedData,
      DwCloseCode.messageTooBig,
      DwCloseCode.internalError,
      DwCloseCode.protocolError,
      DwCloseCode.incompatible,
      DwCloseCode.slowConsumer,
    ];
    expect(codes.toSet(), hasLength(codes.length));
  });
}
