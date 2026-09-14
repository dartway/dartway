import '../protocol/dw_json_codec.dart';
import '../protocol/dw_wire_protocol.dart';
import '../result/dw_call_refusal.dart';
import '../wire/dw_self_validating.dart';
import '../wire/dw_server_call.dart';
import '../wire/dw_wire_object.dart';

/// What an uploaded file is for. The project declares its purposes as an enum
/// in its shared package:
///
/// ```dart
/// enum ExampleUpload with DwUploadPurpose { avatar, chatPhoto }
/// ```
///
/// The server declares, once per purpose, who may upload, how large a file
/// may be, which types it may have and whether it is public; a purpose
/// without a declaration refuses every upload.
///
/// The purpose is the first segment of every object key the server builds,
/// so its name is an identifier: letters, digits and `_`, starting with a
/// letter. The server refuses to start with a rule for any other name.
mixin DwUploadPurpose on Enum {
  /// The purpose's name on the wire and in object keys.
  String get purposeName => name;
}

/// The framework's refusals of file uploads. Codes, never text: the project
/// renders them through its string catalogue, as every other refusal.
///
/// A separate enum from `DwCoreRefusal` so a project that switches
/// exhaustively over the core codes keeps compiling; the codes share the
/// `dw.` namespace.
enum DwUploadRefusal implements DwRefusalCode {
  /// The server declares no rule for the purpose ([DwCallRefusal.field] is
  /// `purpose`): a client built against another server, or a rule forgotten.
  purposeUnknown('dw.uploadPurposeUnknown'),

  /// The file is larger than the purpose allows. `maxBytes` holds the limit;
  /// the field is `byteSize`.
  tooLarge('dw.uploadTooLarge'),

  /// The purpose does not accept this content type. `allowed` holds the
  /// accepted types, comma-separated; the field is `contentType`.
  typeRejected('dw.uploadTypeRejected'),

  /// Finishing an upload whose object is not in storage: the upload never
  /// arrived, or has not arrived yet. The ticket stays valid until it
  /// expires, so the client may upload and finish again.
  missing('dw.uploadMissing'),

  /// The stored object is not what the ticket was issued for — another size
  /// or type. The ticket is dead; the object is removed with the other
  /// unconfirmed uploads.
  mismatch('dw.uploadMismatch'),

  /// Finishing a ticket past its lifetime (and grace): its object is, or is
  /// about to be, removed. The client starts a new upload.
  expired('dw.uploadExpired'),

  /// A file id a project row wants to reference is not a confirmed file of
  /// the caller with the expected purpose (`DwCallContext.files`'
  /// `requireOwned`). Deliberately one code for "absent", "someone else's",
  /// "unconfirmed" and "another purpose": a caller must not learn which.
  notOwned('dw.fileNotOwned');

  const DwUploadRefusal(this.code);

  @override
  final String code;
}

/// Asks the server for a place to upload one file: answered with a
/// [DwUploadTicket] holding a presigned URL the client sends the bytes to —
/// directly to storage, never through the app server.
///
/// The server checks the declared [byteSize] and [contentType] against the
/// purpose's rule, and binds both into the URL's signature, so storage
/// refuses bytes of another length or type. [fileName] is kept as the file's
/// display name only; the object key is built by the server from nothing the
/// client sends.
final class DwStartUpload extends DwActionCommand<DwUploadTicket>
    implements DwSelfValidating {
  /// [contentType] is trimmed and lower-cased: `image/JPEG` and `image/jpeg`
  /// are one type, and the rule compares exactly.
  DwStartUpload({
    required DwUploadPurpose purpose,
    required this.fileName,
    required String contentType,
    required this.byteSize,
  }) : purpose = purpose.purposeName,
       contentType = contentType.trim().toLowerCase();

  /// The command as it travels: the purpose by name, the content type as
  /// sent. For decoding and for tests of what a client could send.
  const DwStartUpload.raw({
    required this.purpose,
    required this.fileName,
    required this.contentType,
    required this.byteSize,
  });

  /// The purpose's name ([DwUploadPurpose.purposeName]).
  final String purpose;

  /// The name the file had where it came from, for people: 1–255 characters,
  /// without control characters or path separators.
  final String fileName;

  /// A MIME type without parameters: `image/jpeg`.
  final String contentType;

  /// The exact size in bytes; at least one.
  final int byteSize;

  static const int maxFileNameLength = 255;

  /// Whether [contentType] is a type this command can carry: a lower-case
  /// MIME type without parameters. The server's upload rules are held to the
  /// same shape, so a rule can never name a type no client could send.
  static bool isContentType(String contentType) =>
      _mimeType.hasMatch(contentType);

  static final RegExp _mimeType = RegExp(
    r"^[a-z0-9][a-z0-9!#$&^_.+-]{0,126}/[a-z0-9][a-z0-9!#$&^_.+-]{0,126}$",
  );

  /// Control characters, and both path separators: a display name is not a
  /// path, and one that looks like `../x` is a mistake or an attack.
  static final RegExp _badNameCharacter = RegExp(r'[\x00-\x1f\x7f/\\]');

  @override
  List<DwCallRefusal> validate() => [
    if (purpose.isEmpty) DwCallRefusal(DwCoreRefusal.invalid, field: 'purpose'),
    if (fileName.trim().isEmpty ||
        fileName.runes.length > maxFileNameLength ||
        _badNameCharacter.hasMatch(fileName))
      DwCallRefusal(DwCoreRefusal.invalid, field: 'fileName'),
    if (!isContentType(contentType))
      DwCallRefusal(DwCoreRefusal.invalid, field: 'contentType'),
    if (byteSize < 1) DwCallRefusal(DwCoreRefusal.invalid, field: 'byteSize'),
  ];

  @override
  String get dwTypeName => 'DwStartUpload';

  @override
  Map<String, Object?> toJson() => {
    'purpose': purpose,
    'fileName': fileName,
    'contentType': contentType,
    'byteSize': byteSize,
  };

  static DwStartUpload fromJson(Map<String, Object?> json) => DwStartUpload.raw(
    purpose: json['purpose']! as String,
    fileName: json['fileName']! as String,
    contentType: json['contentType']! as String,
    byteSize: json['byteSize']! as int,
  );

  @override
  bool operator ==(Object other) =>
      other is DwStartUpload &&
      other.purpose == purpose &&
      other.fileName == fileName &&
      other.contentType == contentType &&
      other.byteSize == byteSize;

  @override
  int get hashCode => Object.hash(purpose, fileName, contentType, byteSize);

  @override
  String toString() =>
      'DwStartUpload($purpose, $fileName, $contentType, $byteSize bytes)';
}

/// Where to upload: `PUT` [uploadUrl] with exactly [headers] and the file's
/// bytes as the body, before [expiresAt]; then [DwFinishUpload] with [id].
final class DwUploadTicket extends DwDataObject {
  const DwUploadTicket({
    required this.id,
    required this.uploadUrl,
    required this.headers,
    required this.expiresAt,
  });

  /// The id of the file being uploaded; the file keeps it once finished.
  @override
  final int id;

  /// A presigned storage URL: whoever holds it may put this one object until
  /// [expiresAt], so it is not logged or shared.
  final String uploadUrl;

  /// Headers the signature covers besides the length: sending other values
  /// makes storage refuse the upload.
  final Map<String, String> headers;

  /// After this, storage refuses the URL.
  final DateTime expiresAt;

  @override
  String get dwTypeName => 'DwUploadTicket';

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'uploadUrl': uploadUrl,
    if (headers.isNotEmpty) 'headers': headers,
    'expiresAt': DwJsonCodec.encodeDateTime(expiresAt),
  };

  static DwUploadTicket fromJson(Map<String, Object?> json) => DwUploadTicket(
    id: json['id']! as int,
    uploadUrl: json['uploadUrl']! as String,
    headers: json['headers'] == null
        ? const {}
        : DwJsonCodec.decodeMap(json['headers'], (value) => value! as String),
    expiresAt: DwJsonCodec.decodeDateTime(json['expiresAt']),
  );

  @override
  bool operator ==(Object other) =>
      other is DwUploadTicket &&
      other.id == id &&
      other.uploadUrl == uploadUrl &&
      dwMapEquals(other.headers, headers) &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(
    id,
    uploadUrl,
    Object.hashAllUnordered(
      headers.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    expiresAt,
  );

  /// Without the URL: it is a credential.
  @override
  String toString() => 'DwUploadTicket($id, expires $expiresAt)';
}

/// Confirms an upload: the server checks the stored object against the
/// ticket and answers the file. Only the account that started the upload may
/// finish it; finishing a finished file answers the file again.
final class DwFinishUpload extends DwActionCommand<DwStoredFile> {
  const DwFinishUpload({required this.ticketId});

  /// [DwUploadTicket.id].
  final int ticketId;

  @override
  String get dwTypeName => 'DwFinishUpload';

  @override
  Map<String, Object?> toJson() => {'ticketId': ticketId};

  static DwFinishUpload fromJson(Map<String, Object?> json) =>
      DwFinishUpload(ticketId: json['ticketId']! as int);

  @override
  bool operator ==(Object other) =>
      other is DwFinishUpload && other.ticketId == ticketId;

  @override
  int get hashCode => ticketId.hashCode;

  @override
  String toString() => 'DwFinishUpload($ticketId)';
}

/// A confirmed file. A project row references it by [id] (`imageFileId`)
/// and never stores [url], which the storage configuration decides.
final class DwStoredFile extends DwDataObject {
  const DwStoredFile({
    required this.id,
    required this.purpose,
    required this.fileName,
    required this.contentType,
    required this.byteSize,
    this.url,
  });

  @override
  final int id;

  /// [DwUploadPurpose.purposeName].
  final String purpose;

  final String fileName;
  final String contentType;
  final int byteSize;

  /// Where anyone can read a public file; `null` for a private one, which is
  /// read through [DwGetFileLink].
  final String? url;

  @override
  String get dwTypeName => 'DwStoredFile';

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'purpose': purpose,
    'fileName': fileName,
    'contentType': contentType,
    'byteSize': byteSize,
    if (url != null) 'url': url,
  };

  static DwStoredFile fromJson(Map<String, Object?> json) => DwStoredFile(
    id: json['id']! as int,
    purpose: json['purpose']! as String,
    fileName: json['fileName']! as String,
    contentType: json['contentType']! as String,
    byteSize: json['byteSize']! as int,
    url: json['url'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is DwStoredFile &&
      other.id == id &&
      other.purpose == purpose &&
      other.fileName == fileName &&
      other.contentType == contentType &&
      other.byteSize == byteSize &&
      other.url == url;

  @override
  int get hashCode =>
      Object.hash(id, purpose, fileName, contentType, byteSize, url);

  @override
  String toString() =>
      'DwStoredFile($id, $purpose, $fileName, $contentType, $byteSize bytes'
      '${url == null ? ', private' : ''})';
}

/// Asks for a link to read a file. A read, so it is retried freely and
/// stores nothing; fetch it when the file is about to be shown, since a
/// private link expires — do not watch it.
///
/// Refused `dw.notFound` for a file that does not exist or is not confirmed,
/// and `dw.forbidden` when the project's read rule says no.
final class DwGetFileLink extends DwSingleRequest<DwFileLink> {
  const DwGetFileLink({required this.fileId});

  final int fileId;

  @override
  String get dwTypeName => 'DwGetFileLink';

  @override
  Map<String, Object?> toJson() => {'fileId': fileId};

  static DwGetFileLink fromJson(Map<String, Object?> json) =>
      DwGetFileLink(fileId: json['fileId']! as int);

  @override
  bool operator ==(Object other) =>
      other is DwGetFileLink && other.fileId == fileId;

  @override
  int get hashCode => fileId.hashCode;

  @override
  String toString() => 'DwGetFileLink($fileId)';
}

/// A link to read a file: short-lived and presigned for a private file,
/// the permanent public URL (without [expiresAt]) for a public one.
final class DwFileLink extends DwDataObject {
  const DwFileLink({required this.id, required this.url, this.expiresAt});

  /// The file's id.
  @override
  final int id;

  final String url;

  /// When a private link stops working; `null` for a public file.
  final DateTime? expiresAt;

  @override
  String get dwTypeName => 'DwFileLink';

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'url': url,
    if (expiresAt case final expiresAt?)
      'expiresAt': DwJsonCodec.encodeDateTime(expiresAt),
  };

  static DwFileLink fromJson(Map<String, Object?> json) => DwFileLink(
    id: json['id']! as int,
    url: json['url']! as String,
    expiresAt: json['expiresAt'] == null
        ? null
        : DwJsonCodec.decodeDateTime(json['expiresAt']),
  );

  @override
  bool operator ==(Object other) =>
      other is DwFileLink &&
      other.id == id &&
      other.url == url &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(id, url, expiresAt);

  /// Without the URL of a private link: it is a credential.
  @override
  String toString() =>
      'DwFileLink($id${expiresAt == null ? ', $url' : ', expires $expiresAt'})';
}

/// The file DTOs, registered in [DwWireProtocol.core].
const List<DwProtocolEntry> dwFileProtocolEntries = [
  DwProtocolEntry<DwStartUpload>('DwStartUpload', DwStartUpload.fromJson),
  DwProtocolEntry<DwUploadTicket>('DwUploadTicket', DwUploadTicket.fromJson),
  DwProtocolEntry<DwFinishUpload>('DwFinishUpload', DwFinishUpload.fromJson),
  DwProtocolEntry<DwStoredFile>('DwStoredFile', DwStoredFile.fromJson),
  DwProtocolEntry<DwGetFileLink>('DwGetFileLink', DwGetFileLink.fromJson),
  DwProtocolEntry<DwFileLink>('DwFileLink', DwFileLink.fromJson),
];
