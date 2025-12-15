// import 'dart:async';

// import 'package:audio_waveforms/audio_waveforms.dart';
// import 'package:dartway_serverpod_chat_flutter/src/ui_kit/dw_chat_ui_kit.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_hooks/flutter_hooks.dart';
// import 'package:hooks_riverpod/hooks_riverpod.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:tvolkova_flutter/admin/chats/UI/chat_theme/chat_theme.dart';
// import 'package:tvolkova_flutter/admin/chats/UI/widget/voice_messages/state/voice_message_state.dart';

// class AudioRecorderWidget extends HookConsumerWidget {
//   final ValueNotifier<bool> isAudioMode;
//   final int chatId;

//   const AudioRecorderWidget({
//     super.key,
//     required this.chatId,
//     required this.isAudioMode,
//   });

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final recorderController = useMemoized(() => RecorderController());
//     final isRecording = useState(false);
//     final recordDuration = useState(Duration.zero);
//     Timer? timer;

//     useEffect(() {
//       // recorderController.checkPermission();
//       return () {
//         recorderController.dispose();
//         timer?.cancel();
//       };
//     }, [recorderController]);

//     void startRecording() async {
//       isRecording.value = true;
//       recordDuration.value = Duration.zero;
//       timer = Timer.periodic(const Duration(seconds: 1), (_) {
//         recordDuration.value += const Duration(seconds: 1);
//       });
//       await recorderController.record();
//     }

//     Future<void> stopAndSend() async {
//       timer?.cancel();

//       final fileUrl = await recorderController.stop();
//       if (fileUrl == null) {
//         return;
//       }

//       await ref
//           .read(voiceMessageStateProvider(chatId).notifier)
//           .uploadVoiceMessage(
//             XFile(fileUrl),
//             recordDuration.value.inMilliseconds,
//           );
//       isRecording.value = false;
//       isAudioMode.value = false;
//     }

//     void cancel() async {
//       timer?.cancel();
//       isRecording.value = false;
//       await recorderController.stop();
//       isAudioMode.value = false;
//     }

//     useEffect(() {
//       startRecording();
//       return null;
//     }, []);

//     return Container(
//       width: MediaQuery.of(context).size.width,
//       color: Colors.white,
//       padding: const EdgeInsets.only(top: 16, bottom: 10, left: 16, right: 16),
//       child: Row(
//         children: [
//           TextButton(
//             onPressed: cancel,
//             child: const Text('Отмена'),
//           ),
//           Expanded(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 AudioWaveforms(
//                   enableGesture: false,
//                   size: Size(MediaQuery.of(context).size.width * 0.5, 40),
//                   recorderController: recorderController,
//                   waveStyle: const WaveStyle(
//                     waveColor: Colors.black,
//                     extendWaveform: true,
//                     showMiddleLine: false,
//                   ),
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(8.0),
//                     color: const Color(0xFFF5F5F5),
//                   ),
//                   padding: const EdgeInsets.symmetric(horizontal: 12),
//                 ),
//               ],
//             ),
//           ),
//           HookBuilder(
//             builder: (context) {
//               final isLoading = useState(false);
//               return FloatingActionButton.small(
//                 backgroundColor: DwChatTheme.of(context).mainTheme.primaryColor,
//                 foregroundColor: Colors.white,
//                 onPressed: () async {
//                   isLoading.value = true;
//                   await stopAndSend();
//                   isLoading.value = false;
//                 },
//                 child: isLoading.value
//                     ? const CircularProgressIndicator()
//                     : const Icon(Icons.send),
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }
