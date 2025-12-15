// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:carousel_slider/carousel_slider.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_hooks/flutter_hooks.dart';
// import 'package:hooks_riverpod/hooks_riverpod.dart';

// class FullscreenAttachmentView extends HookConsumerWidget {
//   const FullscreenAttachmentView({
//     super.key,
//     required this.startIndex,
//     required this.images,
//   });

//   final int startIndex;
//   final List<String> images;

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final indexValue = useState(startIndex);

//     return Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         // const Spacer(),
//         _AttachmentSlider(
//           startIndex: startIndex,
//           images: images,
//           onPageChanged: (index) {
//             indexValue.value = index;
//           },
//         ),
//         // const Gap(8),
//         // if (images.length > 1)
//         //   _AttachmentSliderIndicator(
//         //     index: indexValue.value,
//         //     length: images.length,
//         //   ),
//       ],
//     );
//   }
// }

// class _AttachmentSlider extends HookWidget {
//   const _AttachmentSlider({
//     required this.images,
//     this.onPageChanged,
//     this.startIndex = 0,
//   });

//   final Function(int index)? onPageChanged;
//   final List<String> images;
//   final int startIndex;

//   @override
//   Widget build(BuildContext context) {
//     final transformationController = useRef(TransformationController());
//     final isSliderDisabled = useState(false);
//     final pointers = useRef(0);

//     useEffect(
//         () => () {
//               transformationController.value.dispose();
//             },
//         []);

//     void onInteractionEnd() {
//       transformationController.value.value = Matrix4.identity();
//     }

//     void onPointerDown() {
//       pointers.value = pointers.value + 1;
//       if (!isSliderDisabled.value && pointers.value > 1) {
//         isSliderDisabled.value = true;
//       }
//     }

//     void onPointerUp() {
//       pointers.value = pointers.value - 1;
//       if (isSliderDisabled.value && pointers.value < 2) {
//         isSliderDisabled.value = false;
//       }
//     }

//     return Listener(
//       onPointerDown: (_) => onPointerDown(),
//       onPointerUp: (_) => onPointerUp(),
//       child: CarouselSlider(
//         disableGesture: true,
//         options: CarouselOptions(
//           initialPage: startIndex,
//           onPageChanged: onPageChanged != null
//               ? (index, _) => onPageChanged!(index)
//               : null,
//           height: MediaQuery.sizeOf(context).height * 0.7,

//           viewportFraction: 1,
//           enableInfiniteScroll: false, //!
//           scrollPhysics: isSliderDisabled.value
//               ? const NeverScrollableScrollPhysics()
//               : null,
//         ),
//         items: List<Widget>.generate(
//           images.length,
//           (index) {
//             return InteractiveViewer(
//               scaleEnabled: true,
//               transformationController: transformationController.value,
//               minScale: 1.0,
//               maxScale: 3.0,
//               onInteractionEnd: (_) => onInteractionEnd(),
//               child: Center(
//                 child: Image(
//                   image: CachedNetworkImageProvider(
//                     images[index],
//                   ),
//                   fit: BoxFit.fitWidth,
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

// // class _AttachmentSliderIndicator extends StatelessWidget {
// //   const _AttachmentSliderIndicator({
// //     required this.index,
// //     required this.length,
// //   });

// //   final int index;
// //   final int length;

// //   @override
// //   Widget build(BuildContext context) {
// //     return Row(
// //       mainAxisAlignment: MainAxisAlignment.center,
// //       children: List.generate(
// //         length,
// //         (i) => AnimatedContainer(
// //           duration: const Duration(milliseconds: 200),
// //           margin: const EdgeInsets.symmetric(horizontal: 4),
// //           width: index == i ? 20 : 8,
// //           height: 8,
// //           decoration: BoxDecoration(
// //             color: index == i ? Colors.white : Colors.grey,
// //             borderRadius: const BorderRadius.all(Radius.circular(8)),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
