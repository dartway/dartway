// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import 'dw_admin_database_page_descriptor.dart';

// class DwAdminDatabasePage extends ConsumerStatefulWidget {
//   const DwAdminDatabasePage({
//     super.key,
//     required this.scaffoldConstructor,
//     required this.pageDescriptors,
//   });

//   final Function({required String pageTitle, required Widget body})
//   scaffoldConstructor;
//   final List<DwAdminDatabasePageDescriptor> pageDescriptors;

//   @override
//   ConsumerState<DwAdminDatabasePage> createState() => _State();
// }

// class _State extends ConsumerState<DwAdminDatabasePage> {
//   late DwAdminDatabasePageDescriptor _selectedPage =
//       widget.pageDescriptors.first;

//   @override
//   Widget build(BuildContext context) {
//     return widget.scaffoldConstructor(
//       pageTitle: _selectedPage.pageDescriptor.pageTitle,
//       body: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Padding(
//           //   padding: const EdgeInsets.only(bottom: 4.0),
//           //   child: Text(
//           //     // "База данных: ${_selectedPage.pageDescriptor.pageTitle?.toLowerCase()}",
//           //     _selectedPage.pageDescriptor.pageTitle,
//           //   ),
//           // ),
//           // if (context.isMobile)
//           // Expanded(
//           //   child: Padding(
//           //     padding: const EdgeInsets.only(bottom: 8),
//           //     child: _selectedPage.pageDescriptor.modelManagerBlock,
//           //   ),
//           // ),
//           Wrap(
//             spacing: 12,
//             crossAxisAlignment: WrapCrossAlignment.center,
//             children: [
//               // IconButton(onPressed: () async =>
//               //       _selectedPage.pageDescriptor.modelManagerBlock. editingFormPresenter(
//               //             context,
//               //             NitGenericForm<Model, FormDescriptor>(
//               //               fields: fields,
//               //               model: null,
//               //               modelManager: ref.dwGenericModelManager<Model>(),
//               //               defaultValues: await defaultValuesProvider?.call(
//               //                 ref,
//               //               ),
//               //             ),
//               //           ), icon: icon)
//               const Text("Другие разделы:"),
//               ...widget.pageDescriptors
//                   .where((e) => e != _selectedPage)
//                   .map(
//                     (e) => ElevatedButton(
//                       onPressed:
//                           () => setState(() {
//                             _selectedPage = e;
//                           }),
//                       child: Text(e.pageDescriptor.pageTitle),
//                     ),
//                     // InkWell(
//                     //   onTap: () => setState(() {
//                     //     _selectedPage = e;
//                     //   }),
//                     //   child: Card(
//                     //     color: _selectedPage == e
//                     //         ? context.colorScheme.primaryContainer
//                     //         : context.colorScheme.secondaryContainer,
//                     //     child: Padding(
//                     //       padding: const EdgeInsets.all(8.0),
//                     //       child: Text(
//                     //         '${_selectedPage == e ? '✅ ' : ''}${e.pageDescriptor.pageTitle ?? '???'}',
//                     //         style: _selectedPage == e
//                     //             ? context.textTheme.bodyMedium!
//                     //                 .copyWith(fontWeight: FontWeight.w700)
//                     //             : null,
//                     //       ),
//                     //     ),
//                     //   ),
//                     // ),
//                   ),
//             ],
//           ),
//           // if (!context.isMobile)
//           Expanded(
//             child: Padding(
//               padding: const EdgeInsets.only(top: 8),
//               child: _selectedPage.pageDescriptor.modelManagerBlock,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
