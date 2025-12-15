// // audio_provider.dart
// import 'dart:developer';
// import 'dart:io';

// import 'package:audio_waveforms/audio_waveforms.dart';
// import 'package:freezed_annotation/freezed_annotation.dart';
// import 'package:http/http.dart' as http;
// import 'package:path/path.dart' as p;
// import 'package:path_provider/path_provider.dart';
// import 'package:riverpod_annotation/riverpod_annotation.dart';

// part 'voice_message_bubble_state.freezed.dart';
// part 'voice_message_bubble_state.g.dart';

// @Riverpod(keepAlive: true)
// class VoiceMessageBubbleState extends _$VoiceMessageBubbleState {
//   @override
//   VoiceMessageBubbleStateModel build(String url) {
//     final playerController = PlayerController();
//     ref.onDispose(() {
//       playerController.dispose();
//     });

//     playerController.onCompletion.listen((_) async {
//       await playerController.seekTo(0);
//       await playerController.pausePlayer();
//     });

//     return VoiceMessageBubbleStateModel(
//       playerController: playerController,
//       type: AudioStateType.initial,
//     );
//   }

//   Future<void> initializeAudio() async {
//     if (state.type == AudioStateType.loading ||
//         state.type == AudioStateType.loaded) return;

//     state = VoiceMessageBubbleStateModel(
//         type: AudioStateType.loading, playerController: state.playerController);

//     try {
//       final localPath = await _downloadFile(url);
//       if (localPath == null) {
//         throw Exception('Failed to download audio file');
//       }

//       // Подготавливаем плеер с локальным путем
//       await state.playerController.preparePlayer(
//         path: localPath,
//         shouldExtractWaveform: true,
//         noOfSamples: 20,
//       );
//       state.playerController.setFinishMode(finishMode: FinishMode.pause);
//       state = VoiceMessageBubbleStateModel(
//           type: AudioStateType.loaded,
//           playerController: state.playerController);
//     } catch (e, st) {
//       log('initializeAudio error: $e\n$st');
//       state = VoiceMessageBubbleStateModel(
//         type: AudioStateType.error,
//         playerController: state.playerController,
//       );
//     }
//   }

//   Future<void> togglePlay() async {
//     if (state.type == AudioStateType.error ||
//         state.type == AudioStateType.initial) {
//       await initializeAudio();
//     }
//     if (state.type == AudioStateType.loaded) {
//       final controller = state.playerController;
//       if (controller.playerState == PlayerState.playing) {
//         await controller.pausePlayer();
//       } else {
//         await controller.startPlayer();
//       }
//       state = VoiceMessageBubbleStateModel(
//           type: AudioStateType.loaded, playerController: controller);
//     }
//   }

//   Future<String?> _downloadFile(String url) async {
//     try {
//       final uri = Uri.parse(url);
//       final response = await http.get(uri);
//       if (response.statusCode != 200) {
//         throw Exception(
//             'Failed to download file: Status ${response.statusCode}');
//       }

//       final tempDir = await getTemporaryDirectory();

//       // Получаем последний сегмент пути и декодируем %20 -> пробел и т.п.
//       final rawBaseName = (uri.pathSegments.isNotEmpty)
//           ? uri.pathSegments.last
//           : uri.toString();
//       final decodedBase = Uri.decodeComponent(rawBaseName);

//       // Снимаем потенциально проблемные символы, но сохраняем расширение если есть
//       String baseName = decodedBase
//           .replaceAll(RegExp(r'[\[\]():\/\\]'), '_')
//           .replaceAll('..', '.');

//       // Попробуем получить расширение из Content-Type
//       String? contentType = response.headers['content-type'];
//       String? ext;
//       if (contentType != null) {
//         if (contentType.contains('mpeg') || contentType.contains('mp3')) {
//           ext = '.mp3';
//         } else if (contentType.contains('ogg')) {
//           ext = '.ogg';
//         } else if (contentType.contains('wav') ||
//             contentType.contains('x-wav')) {
//           ext = '.wav';
//         } else if (contentType.contains('webm')) {
//           ext = '.webm';
//         } else if (contentType.contains('aac')) {
//           ext = '.aac';
//         }
//       }

//       // Если в имени есть расширение, используем его (приоритет)
//       final nameExtMatch = RegExp(r'\.[A-Za-z0-9]+$').firstMatch(baseName);
//       if (nameExtMatch != null) {
//         ext = nameExtMatch.group(0);
//       }

//       // Фоллбек
//       ext ??= '.mp3';

//       // Если в baseName уже есть расширение, не добавляем лишнее
//       if (!baseName.endsWith(ext)) {
//         // удалим возможные точки в конце и добавим ext
//         baseName = baseName.replaceAll(RegExp(r'\.+$'), '');
//         baseName = '$baseName$ext';
//       }

//       final fileName = '${DateTime.now().millisecondsSinceEpoch}_$baseName';
//       final filePath = p.join(tempDir.path, fileName);

//       final file = File(filePath);
//       await file.writeAsBytes(response.bodyBytes);

//       if (!await file.exists()) {
//         throw Exception('File not created');
//       }

//       log('Saved file path: $filePath');
//       return filePath;
//     } catch (e, st) {
//       log('Error downloading file: $e\n$st');
//       return null;
//     }
//   }
// }

// enum AudioStateType {
//   initial,
//   loading,
//   loaded,
//   error,
// }

// @freezed
// class VoiceMessageBubbleStateModel with _$VoiceMessageBubbleStateModel {
//   const factory VoiceMessageBubbleStateModel({
//     required AudioStateType type,
//     required PlayerController playerController,
//   }) = _VoiceMessageBubbleStateModel;
// }
