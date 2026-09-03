import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/src/private/dw_singleton.dart';
import 'package:file_picker/file_picker.dart';
import 'package:heif_converter/heif_converter.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DwFileUploadHandler {
  // -----------------------------
  //  EXISTING IMAGE UPLOAD LOGIC
  // -----------------------------

  /// [path] is the folder the object is placed in, as in
  /// [uploadXFileToServer]. Picking a file and deciding where it lands are
  /// unrelated choices, and taking the first used to forfeit the second:
  /// every picked image went to the bucket root.
  static Future<String?> pickAndUploadImageUrl({
    ImageSource imageSource = ImageSource.gallery,
    String? path,
  }) async => pickAndUploadImage(
    imageSource: imageSource,
    path: path,
  ).then((media) => media?.publicUrl);

  static Future<DwCloudFile?> pickAndUploadImage({
    ImageSource imageSource = ImageSource.gallery,
    String? path,
  }) async {
    final file = await ImagePicker().pickImage(source: imageSource);

    if (file == null) {
      log('no image');
      return null;
    }

    return await uploadXFileToServer(xFile: file, path: path);
  }

  static Future<String?> uploadXFileToServerUrl({
    required XFile xFile,
    String? path,
  }) async => uploadXFileToServer(
    xFile: xFile,
    path: path,
  ).then((media) => media.publicUrl);

  static Future<DwCloudFile> uploadXFileToServer({
    required XFile xFile,
    String? path,
  }) async {
    final fileExtension = extension(xFile.path).toLowerCase();

    final originalBytes = await xFile.readAsBytes();

    final jpegBytes = await _convertToJpeg(originalBytes, fileExtension);

    final bytesToUpload = jpegBytes ?? originalBytes;

    // The bytes decide the extension, not the picked file: a HEIC that was
    // converted is uploaded as JPEG, and the server derives the recorded mime
    // type from this name.
    final uploadedExtension = jpegBytes != null ? '.jpg' : fileExtension;

    return uploadBytesToServer(
      bytes: bytesToUpload,
      folder: path,
      fileExtension: uploadedExtension,
      fileName: basenameWithoutExtension(xFile.path),
    );
  }

  // -----------------------------
  //  🆕 UNIVERSAL FILE UPLOAD LOGIC
  // -----------------------------

  static Future<String?> uploadPlatformFileToServerUrl({
    required PlatformFile platformFile,
    String? path,
  }) async => uploadPlatformFileToServer(
    platformFile: platformFile,
    path: path,
  ).then((media) => media.publicUrl);

  static Future<DwCloudFile> uploadPlatformFileToServer({
    required PlatformFile platformFile,
    String? path,
  }) async {
    // final fileExtension = extension(platformFile.name ?? '').toLowerCase();

    // Read the bytes
    final Uint8List bytes;
    if (platformFile.bytes != null) {
      bytes = platformFile.bytes!;
    } else if (platformFile.path != null) {
      bytes = await File(platformFile.path!).readAsBytes();
    } else {
      throw Exception(
        "PlatformFile has no bytes or path: ${platformFile.name}",
      );
    }

    final bytesToUpload = bytes;

    // Nothing converts here, so the picked file's extension is the uploaded
    // one.
    final uploadedExtension = platformFile.extension != null
        ? '.${platformFile.extension!.toLowerCase()}'
        : '';

    return uploadBytesToServer(
      bytes: bytesToUpload,
      folder: path,
      fileExtension: uploadedExtension,
      fileName: basenameWithoutExtension(platformFile.name),
    );
  }

  // -----------------------------
  //  CORE UPLOAD LOGIC
  // -----------------------------

  static Future<String?> uploadBytesToServerUrl({
    required Uint8List bytes,
    String? folder,
    required String fileExtension,
    String? fileName,
  }) async => uploadBytesToServer(
    bytes: bytes,
    folder: folder,
    fileExtension: fileExtension,
    fileName: fileName,
  ).then((media) => media.publicUrl);

  /// Uploads [bytes] and answers with the stored file.
  ///
  /// The object's key is the server's to build — see [DwUploadTicket]. What
  /// travels from here is where the object belongs ([folder]), what the bytes
  /// are ([fileExtension]) and, optionally, what to call it ([fileName]).
  /// [fileExtension] is separate from [fileName] because the two disagree: an
  /// image picked as HEIC is uploaded as JPEG, and the server reads the
  /// recorded mime type off the key it builds.
  static Future<DwCloudFile> uploadBytesToServer({
    required Uint8List bytes,
    String? folder,
    required String fileExtension,
    String? fileName,
  }) async {
    final byteData = ByteData.view(bytes.buffer);

    final ticket = await dw.serverTransport.getUploadDescription(
      folder: folder,
      fileExtension: fileExtension,
      fileName: fileName,
    );

    if (ticket == null) {
      throw Exception(
        'Failed to get an upload description for folder: $folder',
      );
    }
    log(ticket.uploadDescription);

    final uploader = FileUploader(ticket.uploadDescription);

    await uploader.uploadByteData(byteData);

    final dwMedia = await dw.serverTransport.verifyUpload(
      fileId: ticket.fileId,
    );

    if (dwMedia == null) {
      throw Exception(
        'Failed to verify the uploaded file for reservation ${ticket.fileId}',
      );
    }

    log(dwMedia.publicUrl);

    return dwMedia;
  }

  // -----------------------------
  //  FILE CONVERSION
  // -----------------------------

  static Future<Uint8List?> _convertToJpeg(
    Uint8List bytes,
    String fileExtension,
  ) async {
    switch (fileExtension.toLowerCase()) {
      case '.heic':
      case '.heif':
        try {
          final tempDir = await getTemporaryDirectory();
          final tempInputFile = File('${tempDir.path}/temp.heic');
          await tempInputFile.writeAsBytes(bytes);

          final tempOutputFile = File('${tempDir.path}/temp.jpg');

          final convertedPath = await HeifConverter.convert(
            tempInputFile.path,
            output: tempOutputFile.path,
            format: 'jpeg',
          );

          if (convertedPath != null) {
            return await File(convertedPath).readAsBytes();
          } else {
            log('Conversion HEIC/HEIF failed');
            return null;
          }
        } catch (e) {
          log('Error while conversion from HEIC/HEIF: $e');
          return null;
        }

      case '.jpg':
      case '.jpeg':
        return bytes;

      default:
        try {
          final image = img.decodeImage(Uint8List.fromList(bytes));
          if (image != null) {
            return Uint8List.fromList(img.encodeJpg(image));
          }

          log('Unsupported file extension $fileExtension');
          break;
        } catch (e) {
          log('Error while file conversion: $e');
          break;
        }
    }
    return null;
  }
}
