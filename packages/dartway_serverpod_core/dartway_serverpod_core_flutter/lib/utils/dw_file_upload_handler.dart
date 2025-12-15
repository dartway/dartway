import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/private/dw_singleton.dart';
import 'package:file_picker/file_picker.dart';
import 'package:heif_converter/heif_converter.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DwFileUploadHandler {
  static String Function(XFile file) defaultUploadNameTemplate =
      (XFile file) => DateFormat('yyyy-MM-dd hh:mm:ss').format(DateTime.now());

  // 🆕 шаблон для PlatformFile (если нет поля name)
  static String Function(PlatformFile file) defaultPlatformUploadNameTemplate =
      (PlatformFile file) =>
          '${DateFormat('yyyy-MM-dd hh:mm:ss').format(DateTime.now())}${file.extension != null ? '.${file.extension!.toLowerCase()}' : ''}';

  // -----------------------------
  //  EXISTING IMAGE UPLOAD LOGIC
  // -----------------------------

  static Future<String?> pickAndUploadImageUrl({
    ImageSource imageSource = ImageSource.gallery,
  }) async => pickAndUploadImage(
    imageSource: imageSource,
  ).then((media) => media?.publicUrl);

  static Future<DwCloudFile?> pickAndUploadImage({
    ImageSource imageSource = ImageSource.gallery,
  }) async {
    final file = await ImagePicker().pickImage(source: imageSource);

    if (file == null) {
      log('no image');
      return null;
    }

    return await uploadXFileToServer(xFile: file);
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

    final uploadPath =
        path == null
            ? defaultUploadNameTemplate(xFile)
            : '$path/${defaultUploadNameTemplate(xFile)}';

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

    // Чтение байтов
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

    // Если это изображение — конвертируем
    // final convertedBytes = await _convertToJpeg(bytes, fileExtension);
    final bytesToUpload = bytes;

    final uploadPath =
        path == null
            ? defaultPlatformUploadNameTemplate(platformFile)
            : '$path/${defaultPlatformUploadNameTemplate(platformFile)}';

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

    var uploadDescription = await dw.endpointCaller.dwUpload
        .getUploadDescription(path: path);

    if (uploadDescription == null) {
      throw Exception("Failed to get upload description for path: $path");
    }
    log(uploadDescription);

    var uploader = FileUploader(uploadDescription);

    await uploader.uploadByteData(byteData);

    var dwMedia = await dw.endpointCaller.dwUpload.verifyUpload(path: path);

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
