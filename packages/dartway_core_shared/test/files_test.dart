import 'dart:convert';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:test/test.dart';

enum ShopUpload with DwUploadPurpose { productPhoto }

/// The file DTOs: in every protocol, their wire shape, and the validation
/// both sides run.
void main() {
  final protocol = DwWireProtocol(const [], include: DwWireProtocol.core);

  T roundTrip<T extends DwWireObject>(T object) {
    final json = jsonDecode(jsonEncode(object.toJson()));
    return protocol.decodeNamed(object.dwTypeName, json) as T;
  }

  test('every file DTO is registered in the core protocol, by kind', () {
    expect(
      {
        for (final name in [
          'DwStartUpload',
          'DwUploadTicket',
          'DwFinishUpload',
          'DwStoredFile',
          'DwGetFileLink',
          'DwFileLink',
        ])
          name: protocol.entryNamed(name)?.kind,
      },
      {
        'DwStartUpload': DwWireObjectKind.command,
        'DwUploadTicket': DwWireObjectKind.dataObject,
        'DwFinishUpload': DwWireObjectKind.command,
        'DwStoredFile': DwWireObjectKind.dataObject,
        'DwGetFileLink': DwWireObjectKind.request,
        'DwFileLink': DwWireObjectKind.dataObject,
      },
    );
  });

  group('DwStartUpload', () {
    test('travels with the purpose by name and a normalised content type', () {
      final command = DwStartUpload(
        purpose: ShopUpload.productPhoto,
        fileName: 'Фото 1.JPG',
        contentType: ' Image/JPEG ',
        byteSize: 1024,
      );
      expect(command.toJson(), {
        'purpose': 'productPhoto',
        'fileName': 'Фото 1.JPG',
        'contentType': 'image/jpeg',
        'byteSize': 1024,
      });
      expect(roundTrip(command), command);
      expect(command.validate(), isEmpty);
    });

    test('validates what both sides can check without the rule', () {
      List<String?> fields(DwStartUpload command) => [
        for (final refusal in command.validate()) refusal.field,
      ];
      DwStartUpload raw({
        String purpose = 'avatar',
        String fileName = 'a.png',
        String contentType = 'image/png',
        int byteSize = 1,
      }) => DwStartUpload.raw(
        purpose: purpose,
        fileName: fileName,
        contentType: contentType,
        byteSize: byteSize,
      );

      expect(fields(raw(purpose: '')), ['purpose']);
      for (final name in ['', '   ', 'a/b', r'a\b', 'a\x00b', 'x' * 256]) {
        expect(fields(raw(fileName: name)), ['fileName'], reason: name);
      }
      expect(fields(raw(fileName: 'я' * 255)), isEmpty);
      for (final type in [
        'image',
        'image/',
        'Image/png',
        'image/png; charset=binary',
        'image/png ',
        '*/*',
      ]) {
        expect(fields(raw(contentType: type)), ['contentType'], reason: type);
      }
      expect(fields(raw(byteSize: 0)), ['byteSize']);
      expect(
        fields(raw(purpose: '', fileName: '', contentType: '', byteSize: -1)),
        ['purpose', 'fileName', 'contentType', 'byteSize'],
      );
      expect(
        raw(byteSize: 0).validate().single.isCode(DwCoreRefusal.invalid),
        isTrue,
      );
    });
  });

  test('a ticket, a file and a link round-trip; credentials stay out of '
      'their text', () {
    final ticket = DwUploadTicket(
      id: 7,
      uploadUrl: 'https://s3.example.com/b/avatar/1/x.png?X-Amz-Signature=abc',
      headers: const {'content-type': 'image/png', 'if-none-match': '*'},
      expiresAt: DateTime.utc(2026, 9, 14, 12),
    );
    expect(roundTrip(ticket), ticket);
    expect('$ticket', isNot(contains('Signature')));

    const public = DwStoredFile(
      id: 7,
      purpose: 'avatar',
      fileName: 'me.png',
      contentType: 'image/png',
      byteSize: 10,
      url: 'https://cdn.example.com/avatar/1/x.png',
    );
    const private = DwStoredFile(
      id: 8,
      purpose: 'document',
      fileName: 'a.pdf',
      contentType: 'application/pdf',
      byteSize: 10,
    );
    expect(roundTrip(public), public);
    expect(roundTrip(private), private);
    expect(private.toJson().containsKey('url'), isFalse);

    final link = DwFileLink(
      id: 8,
      url: 'https://s3.example.com/b/document/1/y.pdf?X-Amz-Signature=def',
      expiresAt: DateTime.utc(2026, 9, 14, 12, 10),
    );
    expect(roundTrip(link), link);
    expect('$link', isNot(contains('Signature')));
    const publicLink = DwFileLink(id: 7, url: 'https://cdn.example.com/x');
    expect(roundTrip(publicLink), publicLink);

    expect(
      roundTrip(const DwFinishUpload(ticketId: 7)),
      const DwFinishUpload(ticketId: 7),
    );
    expect(
      roundTrip(const DwGetFileLink(fileId: 8)),
      const DwGetFileLink(fileId: 8),
    );
  });

  test('a command answers its file through the protocol', () {
    const file = DwStoredFile(
      id: 1,
      purpose: 'avatar',
      fileName: 'a.png',
      contentType: 'image/png',
      byteSize: 3,
    );
    const finish = DwFinishUpload(ticketId: 1);
    expect(
      finish.decodeResult(
        jsonDecode(jsonEncode(finish.encodeResult(file, protocol))),
        protocol,
      ),
      file,
    );
  });

  test('upload refusals are dw. codes of their own enum', () {
    expect(
      {for (final refusal in DwUploadRefusal.values) refusal.code},
      {
        'dw.uploadPurposeUnknown',
        'dw.uploadTooLarge',
        'dw.uploadTypeRejected',
        'dw.uploadMissing',
        'dw.uploadMismatch',
        'dw.uploadExpired',
        'dw.fileNotOwned',
      },
    );
    final refusal = DwCallRefusal(
      DwUploadRefusal.tooLarge,
      field: 'byteSize',
      params: {'maxBytes': 64},
    );
    expect(refusal.isCode(DwUploadRefusal.tooLarge), isTrue);
    expect(refusal.isIncompatibility, isFalse);
    expect(DwApiResponse.refused(refusal).httpStatus, 422);
  });
}
