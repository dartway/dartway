// import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:riverpod_annotation/riverpod_annotation.dart';
// import 'package:tvolkova_client/tvolkova_client.dart';
// import 'package:tvolkova_flutter/admin/chats/states/chat_view_state/chat_view_state.dart';
// import 'package:tvolkova_flutter/core/user_profile_provider.dart';

// part 'voice_message_state.g.dart';

// @riverpod
// class VoiceMessageState extends _$VoiceMessageState {
//   @override
//   Media? build(int chatId) {
//     return null;
//   }

//   Future<void> uploadVoiceMessage(XFile file, int duration) async {
//     final nitMediaUrl = await DwFileUploadHandler.uploadXFileToServerUrl(
//       xFile: file,
//       path: 'chat/${ref.readUserProfile.id}',
//     );
//     if (nitMediaUrl == null) {
//       return;
//     }
//     final nitMedia = await ref.saveModel(
//       Media(
//         id: null,
//         publicUrl: nitMediaUrl,
//         type: MediaType.audio,
//         duration: duration,
//         createdAt: DateTime.now(),
//       ),
//     );
//     await ref
//         .read(chatStateProvider(chatId).notifier)
//         .sendMessage('Голосовое сообщение', nitMedia);
//   }
// }
