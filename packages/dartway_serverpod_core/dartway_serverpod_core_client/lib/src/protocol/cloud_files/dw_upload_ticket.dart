/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

/// What the server hands back when it agrees to an upload.
///
/// The key is deliberately absent: the client does not need it and must not
/// act on it. It uploads with the signed description, then confirms with
/// [fileId] — the row the server reserved for this upload, which is also the
/// only thing `verifyUpload` accepts. A path travelling back to the client and
/// in again is what let one caller confirm another caller's object.
abstract class DwUploadTicket implements _i1.SerializableModel {
  DwUploadTicket._({
    required this.fileId,
    required this.uploadDescription,
  });

  factory DwUploadTicket({
    required int fileId,
    required String uploadDescription,
  }) = _DwUploadTicketImpl;

  factory DwUploadTicket.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwUploadTicket(
      fileId: jsonSerialization['fileId'] as int,
      uploadDescription: jsonSerialization['uploadDescription'] as String,
    );
  }

  int fileId;

  String uploadDescription;

  /// Returns a shallow copy of this [DwUploadTicket]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwUploadTicket copyWith({
    int? fileId,
    String? uploadDescription,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'dartway_serverpod_core.DwUploadTicket',
      'fileId': fileId,
      'uploadDescription': uploadDescription,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _DwUploadTicketImpl extends DwUploadTicket {
  _DwUploadTicketImpl({
    required int fileId,
    required String uploadDescription,
  }) : super._(
         fileId: fileId,
         uploadDescription: uploadDescription,
       );

  /// Returns a shallow copy of this [DwUploadTicket]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwUploadTicket copyWith({
    int? fileId,
    String? uploadDescription,
  }) {
    return DwUploadTicket(
      fileId: fileId ?? this.fileId,
      uploadDescription: uploadDescription ?? this.uploadDescription,
    );
  }
}
