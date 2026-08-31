import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/src/private/dw_singleton.dart';
import 'package:file_picker/file_picker.dart';
import 'package:heif_converter/heif_converter.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DwFileUploadHandler {
  static final Random _random = Random.secure();

  /// A name no other upload can take, whatever the clock says.
  ///
  /// The timestamp is a prefix for humans reading the bucket; the random
  /// segment is what makes the name unique, and it is the only thing that
  /// does. Naming an object after a calendar second made two uploads in the
  /// same second address one key — the second silently replaced the first —
  /// and it made every key guessable from a neighbouring one, which a bucket
  /// serving anonymous `GetObject` has nothing else to hide behind.
  static String _uniqueObjectName() {
    final stamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final suffix = base64Url.encode(bytes).replaceAll('=', '');
    return '$stamp $suffix';
  }

  /// Names the object an [XFile] is uploaded as, **without an extension**.
  ///
  /// The extension is appended by [uploadXFileToServer], which is the only
  /// place that knows it: that method converts most images to JPEG, so the
  /// picked file's own extension describes the source rather than the bytes
  /// that reach the bucket — and the server reads the recorded mime type off
  /// this name.
  static String Function(XFile file) defaultUploadNameTemplate =
      (XFile file) => _uniqueObjectName();

  /// The [PlatformFile] counterpart, on the same terms: no extension here,
  /// [uploadPlatformFileToServer] appends it. That path uploads the bytes it
  /// was given, so there the source extension is the uploaded one.
  static String Function(PlatformFile file) defaultPlatformUploadNameTemplate =
      (PlatformFile file) => _uniqueObjectName();

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

    final name = '${defaultUploadNameTemplate(xFile)}$uploadedExtension';
    final uploadPath = path == null ? name : '$path/$name';

    return uploadBytesToServer(bytes: bytesToUpload, path: uploadPath);
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

    final name =
        '${defaultPlatformUploadNameTemplate(platformFile)}$uploadedExtension';
    final uploadPath = path == null ? name : '$path/$name';

    return uploadBytesToServer(bytes: bytesToUpload, path: uploadPath);
  }

  // -----------------------------
  //  CORE UPLOAD LOGIC
  // -----------------------------

  static Future<String?> uploadBytesToServerUrl({
    required Uint8List bytes,
    required String path,
  }) async => uploadBytesToServer(
    bytes: bytes,
    path: path,
  ).then((media) => media.publicUrl);

  static Future<DwCloudFile> uploadBytesToServer({
    required Uint8List bytes,
    required String path,
  }) async {
    final byteData = ByteData.view(bytes.buffer);

    var uploadDescription = await dw.serverTransport.getUploadDescription(
      path: path,
    );

    if (uploadDescription == null) {
      throw Exception("Failed to get upload description for path: $path");
    }
    log(uploadDescription);

    var uploader = FileUploader(uploadDescription);

    await uploader.uploadByteData(byteData);

    var dwMedia = await dw.serverTransport.verifyUpload(path: path);

    if (dwMedia == null) {
      throw Exception("Failed to verify uploaded file with path: $path");
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
