// import 'dart:developer';
// import 'dart:io';

// import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
// import 'package:flutter/material.dart';
// import 'package:freezed_annotation/freezed_annotation.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:riverpod_annotation/riverpod_annotation.dart';
// import 'package:wechat_assets_picker/wechat_assets_picker.dart';

// part 'attachment_state.freezed.dart';
// part 'attachment_state.g.dart';

// @freezed
// class AdMediaStateModel with _$AdMediaStateModel {
//   const factory AdMediaStateModel({
//     required List<MediaOrAssetWrapper> items,
//     @Default(false) bool isUploading,
//     int? loadedCount,
//   }) = _AdMediaStateModel;
// }

// class MediaOrAssetWrapper {
//   final Object item;

//   MediaOrAssetWrapper(this.item);

//   bool get isMedia => item is Media;
//   bool get isAsset => item is AssetEntity;

//   Media asMedia() => item as Media;
//   AssetEntity asAsset() => item as AssetEntity;
// }

// @riverpod
// class AttachmentState extends _$AttachmentState {
//   final mediaLimit = 5;
//   @override
//   AdMediaStateModel build() {
//     return const AdMediaStateModel(items: []);
//   }

//   Future openMediaPicker(BuildContext context) async {
//     const textDelegate = RussianAssetPickerTextDelegate();
//     // check permission
//     final PermissionState ps = await PhotoManager.requestPermissionExtend();
//     if (!ps.isAuth) {
//       return;
//     }
//     if (!context.mounted) return;
//     final List<AssetEntity>? result = await AssetPicker.pickAssets(
//       context,
//       pickerConfig: AssetPickerConfig(
//         selectedAssets: state.items
//             .where((e) => e.isAsset)
//             .map((e) => e.asAsset())
//             .toList(),
//         maxAssets: mediaLimit,
//         requestType: RequestType.image,
//         gridCount: 3,
//         pageSize: 120,
//         pickerTheme: AssetPicker.themeData(const Color(0xFF0196A2)),
//         textDelegate: textDelegate,
//       ),
//     );

//     final media = state.items.where((e) => e.isMedia).toList();

//     if (result != null) {
//       state = state.copyWith(
//         items: [...media, ...result.map((e) => MediaOrAssetWrapper(e))],
//       );
//     }
//   }

//   Future<List<Media>> uploadMedia() async {
//     state = state.copyWith(isUploading: true);

//     try {
//       final assetsToUpload = state.items.where((e) => e.isAsset).toList();

//       for (var item in assetsToUpload) {
//         await _uploadSingleAsset(item);
//       }
//     } catch (e) {
//       log('Ошибка при загрузке медиа: $e');
//       return [];
//     } finally {
//       state = state.copyWith(isUploading: false);
//     }
//     final mediaItems = state.items.where((e) => e.isMedia).toList();

//     return mediaItems.map((e) => e.asMedia()).toList();
//   }

//   Future<void> _uploadSingleAsset(MediaOrAssetWrapper item) async {
//     try {
//       final asset = item.asAsset();
//       final file = await asset.file;

//       final url = await DwFileUploadHandler.uploadXFileToServerUrl(
//         xFile: XFile(
//           file!.path,
//           bytes: await file.readAsBytes(),
//           name: asset.title,
//         ),
//         path: 'chat/${ref.watchUserProfile.id}',
//       );

//       final fileName = asset.title ?? file.path.split(RegExp(r'[\\/]+')).last;
//       final ext =
//           fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

//       const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif'};
//       const videoExts = {'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', '3gp'};
//       const audioExts = {'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'};

//       final mediaType = videoExts.contains(ext)
//           ? MediaType.video
//           : audioExts.contains(ext)
//               ? MediaType.audio
//               : imageExts.contains(ext)
//                   ? MediaType.image
//                   : MediaType.image; // default to image

//       // TODO bad practice, fix later
//       final nitMedia = await ref.saveModel(
//         Media(publicUrl: url!, type: mediaType, createdAt: DateTime.now()),
//       );

//       state = state.copyWith(
//         loadedCount: (state.loadedCount ?? 0) + 1,
//         items: state.items
//             .map((e) => e == item ? MediaOrAssetWrapper(nitMedia) : e)
//             .toList(),
//       );
//     } catch (e) {
//       log('Ошибка при загрузке ассета: $e');
//     }
//   }

//   Future<void> uploadAudio(File file) async {
//     state = state.copyWith(isUploading: true);

//     try {
//       await DwFileUploadHandler.uploadXFileToServer(
//         xFile: XFile(
//           file.path,
//           bytes: await file.readAsBytes(),
//           name: file.path,
//         ),
//         path: 'chat/${ref.watchUserProfile.id}',
//       );
//     } catch (e) {
//       log('Ошибка при загрузке ассета: $e');
//     } finally {
//       state = state.copyWith(isUploading: false);
//     }
//   }

//   void toggleItem(MediaOrAssetWrapper item) {
//     final items = state.items;
//     final index = items.indexWhere(
//       (e) =>
//           (e.isAsset && e.asAsset().id == item.asAsset().id) ||
//           (e.isMedia && e.asMedia().id == item.asMedia().id),
//     );
//     if (index == -1 && items.length >= mediaLimit) {
//       return;
//     }
//     if (index == -1) {
//       state = state.copyWith(items: [...items, item]);
//     } else if (index != -1) {
//       state = state.copyWith(
//         items: [...items.sublist(0, index), ...items.sublist(index + 1)],
//       );
//     }
//   }
// }
