// The wire format, recorded (D-052).
//
// An app build installed on a phone keeps speaking the wire it was compiled
// with. When the framework changes how a call, an ApiResponse, an update
// transport, a live message or a DTO looks on the wire, that build does not
// get a compile error — it gets a body it cannot decode, and its user gets a
// broken screen. The protocol version is what turns that into an honest
// "update the app" (`426`): so a wire change is a protocol change, and this
// test is what notices one.
//
// Every shape below is encoded as the framework encodes it and compared with
// `goldens/wire_golden.dart`, which records the encodings together with the
// `dwProtocolVersion` they were taken at. Each recorded encoding is also
// decoded again, so a reader that stops accepting what it used to accept is a
// wire change too.
//
//   dart test test/wire_golden_test.dart                       compare
//   DW_UPDATE_GOLDENS=1 dart test test/wire_golden_test.dart   refresh (VM)
//
// A refresh records new shapes freely, but refuses to overwrite or drop a
// recorded encoding while the protocol version is the one it was recorded at:
// the refresh is the step that follows a bump, not a way around it.
//
// Runs on the VM and on node (`dart test -p vm,node`): the golden is a Dart
// constant rather than a file read at runtime, and every value in it survives
// a JavaScript number.
import 'dart:convert';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:test/test.dart';

import 'goldens/wire_golden.dart';
import 'support/golden_io_stub.dart'
    if (dart.library.io) 'support/golden_io.dart';
import 'support/protocol.dart';

const _goldenPath = 'test/goldens/wire_golden.dart';

const _bumpInstruction =
    'the wire changed: bump dwProtocolVersion (D-052) and refresh the golden '
    'with DW_UPDATE_GOLDENS=1';

void main() {
  final shapes = _wireShapes();
  final recorded = _Golden.parse(wireGolden);

  if (goldenUpdateRequested) {
    test('refresh $_goldenPath', () {
      final current = {for (final shape in shapes) shape.name: shape.json()};
      if (recorded != null && recorded.protocolVersion == dwProtocolVersion) {
        final changed = [
          for (final MapEntry(:key, :value) in recorded.shapes.entries)
            if (!current.containsKey(key))
              '$key: recorded, no longer produced'
            else if (!_sameJson(value, current[key]))
              '$key:\n    recorded ${jsonEncode(value)}\n'
                  '    now      ${jsonEncode(current[key])}',
        ];
        if (changed.isNotEmpty) {
          fail(
            'Refusing to refresh: dwProtocolVersion is still '
            '$dwProtocolVersion, the version these encodings were recorded '
            'at, and ${changed.length} of them changed — $_bumpInstruction.'
            '\n  ${changed.join('\n  ')}',
          );
        }
      }
      writeGolden(_goldenPath, _Golden(dwProtocolVersion, current).source());
    });
    return;
  }

  test('the golden is recorded at the current protocol version', () {
    expect(
      recorded,
      isNotNull,
      reason:
          'no golden recorded yet: run DW_UPDATE_GOLDENS=1 dart test '
          'test/wire_golden_test.dart',
    );
    expect(
      recorded!.protocolVersion,
      dwProtocolVersion,
      reason:
          'dwProtocolVersion is $dwProtocolVersion and the golden was recorded '
          'at ${recorded.protocolVersion}: refresh the golden with '
          'DW_UPDATE_GOLDENS=1, so the next change is compared with the wire '
          'of this version',
    );
  });

  test('every recorded shape is still produced', () {
    final names = {for (final shape in shapes) shape.name};
    final dropped = recorded?.shapes.keys.where((k) => !names.contains(k));
    expect(
      dropped?.toList() ?? const [],
      isEmpty,
      reason:
          'a recorded shape is no longer produced — a message or field left '
          'the wire; $_bumpInstruction',
    );
  });

  test('every framework DTO has a recorded shape', () {
    final covered = {for (final shape in shapes) ?shape.dtoName};
    final uncovered = [
      for (final entry in DwWireProtocol.core.entries)
        if (!covered.contains(entry.name)) entry.name,
    ];
    expect(
      uncovered,
      isEmpty,
      reason:
          'a DTO of DwWireProtocol.core travels without a golden: add a shape '
          'for it here and record it with DW_UPDATE_GOLDENS=1',
    );
  });

  group('encodings match the golden', () {
    for (final shape in shapes) {
      test(shape.name, () {
        final golden = recorded;
        if (golden == null || golden.protocolVersion != dwProtocolVersion) {
          markTestSkipped('the golden is not of this protocol version');
          return;
        }
        if (!golden.shapes.containsKey(shape.name)) {
          fail(
            'no golden for "${shape.name}": record it with '
            'DW_UPDATE_GOLDENS=1',
          );
        }
        final expected = golden.shapes[shape.name];

        final encoded = shape.json();
        if (!_sameJson(encoded, expected)) {
          fail(
            '${shape.name}: $_bumpInstruction.\n'
            '  recorded: ${jsonEncode(expected)}\n'
            '  encoded:  ${jsonEncode(encoded)}',
          );
        }

        final reencoded = shape.readBack(expected);
        if (!_sameJson(reencoded, expected)) {
          fail(
            '${shape.name}: the recorded encoding no longer reads back as '
            'itself — a client or server of this protocol version would read '
            'it differently; $_bumpInstruction.\n'
            '  recorded:  ${jsonEncode(expected)}\n'
            '  read back: ${jsonEncode(reencoded)}',
          );
        }
      });
    }
  });
}

/// One canonical encoding: how it is produced, and how a recorded one is read
/// back and encoded again.
final class _WireShape {
  _WireShape(
    this.name,
    Object? Function() encode, {
    Object? Function(Object? json)? readBack,
    this.dtoName,
  }) : _encode = encode,
       _readBack = readBack;

  final String name;
  final Object? Function() _encode;
  final Object? Function(Object? json)? _readBack;

  /// The wire name of the DTO this shape records, for the coverage check.
  final String? dtoName;

  /// The encoding as JSON text carries it.
  Object? json() => _normalized(_encode());

  /// A recorded encoding decoded and encoded again; itself when the shape has
  /// no reader (a constant of the contract).
  Object? readBack(Object? recorded) {
    final read = _readBack;
    return read == null ? recorded : _normalized(read(recorded));
  }
}

Object? _normalized(Object? value) => jsonDecode(jsonEncode(value));

List<_WireShape> _wireShapes() {
  final at = DateTime.utc(2026, 9, 15, 10, 30);
  final later = DateTime.utc(2026, 9, 15, 10, 40);
  final booking = ClubBooking(
    id: 7,
    status: BookingStatus.booked,
    startsAt: at,
  );
  final fullBooking = ClubBooking(
    id: 8,
    status: BookingStatus.cancelled,
    startsAt: later,
    note: 'Window seat',
    tags: const ['yoga', 'morning'],
    seats: 2,
  );

  _WireShape dto(String name, DwWireObject object) => _WireShape(
    name,
    object.toJson,
    readBack: (json) => protocol.decodeNamed(object.dwTypeName, json).toJson(),
    dtoName: object.dwTypeName,
  );

  _WireShape response(String name, DwApiResponse Function() build) {
    Map<String, Object?> http(DwApiResponse response) => {
      'status': response.httpStatus,
      'headers': dwHttpHeadersFor(response),
      'body': response.toJson(),
    };
    return _WireShape(
      name,
      () => http(build()),
      readBack: (json) {
        final map = json! as Map<String, Object?>;
        return http(
          DwApiResponse.fromHttp(map['status']! as int, map['body'], protocol),
        );
      },
    );
  }

  _WireShape clientMessage(String name, DwClientMessage message) => _WireShape(
    name,
    message.toJson,
    readBack: (json) => DwClientMessage.fromJson(json).toJson(),
  );

  _WireShape serverMessage(String name, DwServerMessage message) => _WireShape(
    name,
    message.toJson,
    readBack: (json) => DwServerMessage.fromJson(json, protocol).toJson(),
  );

  _WireShape query(
    String name,
    DwDataRequest<Object?> request,
    DwPageQuery query,
  ) => _WireShape(
    name,
    query.toQuery,
    readBack: (json) => DwPageQuery.parse(
      request,
      (json! as Map<String, Object?>).cast<String, String>(),
    )!.toQuery(),
  );

  final transport = DwUpdateTransport([
    ('bookings:7', booking),
    ('schedule', fullBooking),
    // Collapsed before sending: a row updated, then deleted, travels as its
    // deletion.
    ('bookings:7', fullBooking),
    ('bookings:7', DwDeletedObject.of<ClubBooking>(8, protocol)),
  ]);

  final refused = DwCallRefusal(
    _GoldenRefusal.seatsNotEnough,
    params: {'left': 2},
    field: 'seats',
  );

  return [
    // The HTTP contract.
    _WireShape(
      'http.contract',
      () => {
        'callPath': DwHttpContract.callPath('RenameBooking'),
        'livePath': DwHttpContract.livePath,
        'healthPath': DwHttpContract.healthPath,
        'callMethod': DwHttpContract.callMethod,
        'contentType': DwHttpContract.jsonContentType,
        'headers': [
          DwHttpContract.authorizationHeader,
          DwHttpContract.bearerPrefix,
          DwHttpContract.idempotencyKeyHeader,
          DwHttpContract.protocolHeader,
          DwHttpContract.appVersionHeader,
          DwHttpContract.liveConnectionHeader,
          DwHttpContract.retryAfterHeader,
          DwHttpContract.contentTypeHeader,
        ],
        'query': [
          DwHttpContract.offsetParameter,
          DwHttpContract.pageSizeParameter,
          DwHttpContract.anchorParameter,
          DwHttpContract.beforeParameter,
          DwHttpContract.afterParameter,
          DwHttpContract.liveProtocolParameter,
          DwHttpContract.liveAppVersionParameter,
        ],
      },
    ),
    _WireShape(
      'http.appVersion',
      () => DwAppVersion('1.4.2', 87).toString(),
      readBack: (json) => DwAppVersion.parse(json! as String).toString(),
    ),
    _WireShape(
      'http.closeCodes',
      () => {
        'serverStopping': DwCloseCode.serverStopping,
        'unsupportedData': DwCloseCode.unsupportedData,
        'messageTooBig': DwCloseCode.messageTooBig,
        'internalError': DwCloseCode.internalError,
        'protocolError': DwCloseCode.protocolError,
        'incompatible': DwCloseCode.incompatible,
        'slowConsumer': DwCloseCode.slowConsumer,
      },
    ),

    // Call bodies: requests (defaults omitted), commands (a patch kept, set
    // and cleared).
    dto('call.request.defaults', const ListMyBookings()),
    dto(
      'call.request.fields',
      const ListMyBookings(status: BookingStatus.cancelled, includePast: true),
    ),
    dto('call.command.patchKept', const RenameBooking(bookingId: 7)),
    dto(
      'call.command.patchSet',
      const RenameBooking(bookingId: 7, note: DwFieldPatch.set('Window seat')),
    ),
    dto(
      'call.command.patchCleared',
      const RenameBooking(bookingId: 7, note: DwFieldPatch.clear()),
    ),
    query(
      'call.query.offset',
      const FeedBookings(),
      const DwOffsetQuery(offset: 40, pageSize: 60),
    ),
    query(
      'call.query.windowNewest',
      const BookingHistory(),
      const DwWindowQuery.newest(),
    ),
    query(
      'call.query.windowAround',
      const BookingHistory(),
      DwWindowQuery.around(DwWindowCursor.encode(at, 7), pageSize: 10),
    ),
    query(
      'call.query.windowOlder',
      const BookingHistory(),
      DwWindowQuery.older(DwWindowCursor.encode(at, 7)),
    ),
    query(
      'call.query.windowNewer',
      const BookingHistory(),
      DwWindowQuery.newer(DwWindowCursor.encode(later, 8)),
    ),

    // Data objects, generated shape: defaults omitted, and every field set.
    dto('object.defaults', booking),
    dto('object.fields', fullBooking),
    dto('object.deleted', DwDeletedObject.of<ClubBooking>(8, protocol)),

    // Results.
    _WireShape(
      'result.list',
      () =>
          const ListMyBookings().encodeResult([booking, fullBooking], protocol),
      readBack: (json) => const ListMyBookings().encodeResult(
        const ListMyBookings().decodeResult(json, protocol),
        protocol,
      ),
    ),
    _WireShape(
      'result.page',
      () => DwPageResult([booking], hasMore: true).toJson(),
      readBack: (json) =>
          DwPageResult.fromJson(json, protocol.decodeAs<ClubBooking>).toJson(),
    ),
    _WireShape(
      'result.table',
      () => DwTablePage([booking], total: 41, page: 3, pageSize: 20).toJson(),
      readBack: (json) =>
          DwTablePage.fromJson(json, protocol.decodeAs<ClubBooking>).toJson(),
    ),
    _WireShape(
      'result.window',
      () => DwWindowResult(
        [fullBooking, booking],
        olderCursor: DwWindowCursor.encode(at, 7),
        newerCursor: DwWindowCursor.encode(later, 8),
      ).toJson(),
      readBack: (json) => DwWindowResult.fromJson(
        json,
        protocol.decodeAs<ClubBooking>,
      ).toJson(),
    ),
    _WireShape(
      'result.cursors',
      () => [
        DwWindowCursor.encode(at, 7),
        DwWindowCursor.encode(42, 'b-7'),
        DwWindowCursor.encode('Zoë', 7),
      ],
      readBack: (json) => [
        for (final cursor in json! as List<Object?>)
          DwWindowCursor.decode(cursor! as String).encoded,
      ],
    ),

    // Refusals.
    _WireShape(
      'refusal.full',
      refused.toJson,
      readBack: (json) => DwCallRefusal.fromJson(json).toJson(),
    ),
    _WireShape(
      'refusal.codes',
      () => [
        for (final code in DwCoreRefusal.values) code.code,
        for (final code in DwAuthRefusal.values) code.code,
        for (final code in DwUploadRefusal.values) code.code,
      ],
    ),

    // Every ApiResponse status, with its HTTP status and headers.
    response('response.ok', () => DwApiResponse.ok(booking.toJson())),
    response('response.okVoid', () => const DwApiResponse.ok(null)),
    response(
      'response.okUpdates',
      () => DwApiResponse.ok(fullBooking.toJson(), updates: transport),
    ),
    response(
      'response.okReplayed',
      () => DwApiResponse.ok(booking.toJson(), replayed: true),
    ),
    response('response.refused', () => DwApiResponse.refused(refused)),
    response(
      'response.refusedForbidden',
      () => DwApiResponse.refused(DwCallRefusal(DwCoreRefusal.forbidden)),
    ),
    response(
      'response.refusedNotFound',
      () => DwApiResponse.refused(DwCallRefusal(DwCoreRefusal.notFound)),
    ),
    response(
      'response.refusedConflict',
      () => DwApiResponse.refused(DwCallRefusal(DwCoreRefusal.conflict)),
    ),
    response(
      'response.refusedTooManyRequests',
      () => DwApiResponse.refused(
        DwCallRefusal.tooManyRequests(const Duration(seconds: 30)),
      ),
    ),
    response(
      'response.unauthenticated',
      () => const DwApiResponse.unauthenticated(),
    ),
    response('response.failed', () => const DwApiResponse.failed('incident-1')),
    response(
      'response.failedMalformedCall',
      () => const DwApiResponse.failed(
        'incident-2',
        failure: DwFailureKind.malformedCall,
      ),
    ),
    response(
      'response.failedUnknownCall',
      () => const DwApiResponse.failed(
        'incident-3',
        failure: DwFailureKind.unknownCall,
      ),
    ),
    response(
      'response.incompatibleUpdateRequired',
      () => DwApiResponse.incompatible(
        DwCallRefusal(DwCoreRefusal.updateRequired),
      ),
    ),
    response(
      'response.incompatibleProtocolUnsupported',
      () => DwApiResponse.incompatible(
        DwCallRefusal(DwCoreRefusal.protocolUnsupported),
      ),
    ),

    // The update transport of a response: grouped by channel, then by type.
    _WireShape(
      'transport',
      transport.toJson,
      readBack: (json) => DwUpdateTransport.fromJson(json, protocol).toJson(),
    ),
    _WireShape(
      'channel.wireNames',
      () => [
        const DwLiveChannel(_GoldenChannel.schedule).wireName,
        const DwLiveChannel(_GoldenChannel.chat, 7).wireName,
        const DwLiveChannel(_GoldenChannel.chat, 'general').wireName,
        const DwLiveChannel.ofCaller(
          _GoldenChannel.bookings,
        ).resolvedFor(7).wireName,
      ],
      readBack: (json) => [
        for (final name in json! as List<Object?>)
          switch (dwParseChannelName(name! as String)) {
            (:final kind, key: null) => kind,
            (:final kind, :final key?) => '$kind:$key',
          },
      ],
    ),

    // Every live message.
    clientMessage('live.auth', const DwAuthenticateMessage('token-1')),
    clientMessage('live.authAnonymous', const DwAuthenticateMessage(null)),
    clientMessage('live.sub', const DwSubscribeMessage('bookings:7')),
    clientMessage('live.unsub', const DwUnsubscribeMessage('bookings:7')),
    serverMessage('live.hello', const DwHelloMessage('connection-1')),
    serverMessage('live.authed', const DwAuthenticatedMessage.account(7)),
    serverMessage(
      'live.authedAnonymous',
      const DwAuthenticatedMessage.anonymous(),
    ),
    serverMessage(
      'live.authedRejected',
      const DwAuthenticatedMessage.rejected(),
    ),
    serverMessage('live.subok', const DwSubscribedMessage('bookings:7')),
    serverMessage(
      'live.subnoRefused',
      DwSubscriptionRefusedMessage.refused(
        'bookings:8',
        DwCallRefusal(DwCoreRefusal.forbidden),
      ),
    ),
    serverMessage(
      'live.subnoUnauthenticated',
      const DwSubscriptionRefusedMessage.unauthenticated('bookings:7'),
    ),
    serverMessage(
      'live.subnoFailed',
      const DwSubscriptionRefusedMessage.failed('bookings:7', 'incident-4'),
    ),
    serverMessage(
      'live.upd',
      DwUpdateMessage(
        channel: 'bookings:7',
        updates: DwChannelUpdates([
          booking,
          DwDeletedObject.of<ClubBooking>(8, protocol),
        ]),
      ),
    ),
    serverMessage('live.closed', const DwChannelClosedMessage('bookings:7')),

    // The framework's own DTOs.
    dto(
      'dto.requestCode',
      const DwRequestCode(
        kind: DwIdentifierKind.phone,
        identifier: '79990000001',
      ),
    ),
    dto(
      'dto.codeTicket',
      DwCodeTicket(id: 't-1', expiresAt: later, resendAfter: at),
    ),
    dto(
      'dto.verifyCode',
      const DwVerifyCode(
        ticketId: 't-1',
        code: '123456',
        registration: {'firstName': 'Ada'},
      ),
    ),
    dto(
      'dto.verifyCodeDefaults',
      const DwVerifyCode(ticketId: 't-1', code: '123456'),
    ),
    dto(
      'dto.authSession',
      const DwAuthSession(id: 7, token: 'token-1', isNewAccount: true),
    ),
    dto(
      'dto.authSessionDefaults',
      const DwAuthSession(id: 7, token: 'token-1', isNewAccount: false),
    ),
    dto('dto.signOut', const DwSignOut()),
    dto(
      'dto.requestIdentifierCode',
      const DwRequestIdentifierCode(
        kind: DwIdentifierKind.email,
        identifier: 'ada@example.com',
      ),
    ),
    dto(
      'dto.confirmIdentifier',
      const DwConfirmIdentifier(ticketId: 't-2', code: '654321', replace: true),
    ),
    dto(
      'dto.confirmIdentifierDefaults',
      const DwConfirmIdentifier(ticketId: 't-2', code: '654321'),
    ),
    dto(
      'dto.identityInfo',
      DwIdentityInfo(
        id: 3,
        accountId: 7,
        kind: DwIdentifierKind.email,
        value: 'ada@example.com',
        createdAt: at,
        verifiedAt: later,
      ),
    ),
    dto(
      'dto.sessionKeyInfo',
      DwSessionKeyInfo(
        id: 4,
        accountId: 7,
        kind: DwSessionKeyKind.personal,
        label: 'CI deploy',
        createdAt: at,
        lastUsedAt: later,
        revokedAt: later,
      ),
    ),
    dto(
      'dto.startUpload',
      DwStartUpload(
        purpose: _GoldenUpload.avatar,
        fileName: 'me.png',
        contentType: 'image/png',
        byteSize: 2048,
      ),
    ),
    dto(
      'dto.uploadTicket',
      DwUploadTicket(
        id: 11,
        uploadUrl: 'https://storage.invalid/private/avatar/7/x.png',
        headers: const {'content-type': 'image/png', 'if-none-match': '*'},
        expiresAt: later,
      ),
    ),
    dto('dto.finishUpload', const DwFinishUpload(ticketId: 11)),
    dto(
      'dto.storedFile',
      const DwStoredFile(
        id: 11,
        purpose: 'avatar',
        fileName: 'me.png',
        contentType: 'image/png',
        byteSize: 2048,
        url: 'https://storage.invalid/public/avatar/7/x.png',
      ),
    ),
    dto('dto.getFileLink', const DwGetFileLink(fileId: 11)),
    dto(
      'dto.fileLink',
      DwFileLink(
        id: 11,
        url: 'https://storage.invalid/private/avatar/7/x.png?sig',
        expiresAt: later,
      ),
    ),
  ];
}

enum _GoldenChannel with DwChannelKind { schedule, chat, bookings }

enum _GoldenRefusal with DwRefusalCodes { seatsNotEnough }

enum _GoldenUpload with DwUploadPurpose { avatar }

/// The recorded encodings and the protocol version they were taken at.
final class _Golden {
  const _Golden(this.protocolVersion, this.shapes);

  /// `null` when nothing is recorded yet.
  static _Golden? parse(String source) {
    if (source.trim().isEmpty) return null;
    final map = jsonDecode(source) as Map<String, Object?>;
    return _Golden(
      map['protocolVersion']! as int,
      (map['shapes']! as Map<String, Object?>),
    );
  }

  final int protocolVersion;
  final Map<String, Object?> shapes;

  /// The Dart source of `goldens/wire_golden.dart`.
  String source() {
    final json = const JsonEncoder.withIndent(
      '  ',
    ).convert({'protocolVersion': protocolVersion, 'shapes': shapes});
    return '// GENERATED BY wire_golden_test.dart. DO NOT EDIT.\n'
        '//\n'
        '// The canonical wire encodings of dartway_core_shared and the\n'
        '// protocol version they were recorded at (D-052). Refresh after\n'
        '// bumping dwProtocolVersion:\n'
        '//   DW_UPDATE_GOLDENS=1 dart test test/wire_golden_test.dart\n'
        '\n'
        "const String wireGolden = r'''\n"
        '$json\n'
        "''';\n";
  }
}

/// JSON equality: objects by key regardless of order (a reader looks fields up
/// by name), arrays in order, numbers by value.
bool _sameJson(Object? a, Object? b) => switch ((a, b)) {
  (final Map<String, Object?> x, final Map<String, Object?> y) =>
    x.length == y.length &&
        x.entries.every(
          (entry) =>
              y.containsKey(entry.key) && _sameJson(entry.value, y[entry.key]),
        ),
  (final List<Object?> x, final List<Object?> y) =>
    x.length == y.length &&
        [
          for (var i = 0; i < x.length; i++) i,
        ].every((i) => _sameJson(x[i], y[i])),
  _ => a == b,
};
