// import 'package:dartway_flutter/dartway_flutter.dart';
// import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:nit_generic_forms/nit_generic_forms.dart';

// extension GenericFormsExtension on WidgetRef {
//   NitGenericModelManager<Model> dwGenericModelManager<
//     Model extends SerializableModel
//   >({bool allowDelete = false}) => NitGenericModelManager(
//     saveAction: (model) async => await saveModel<Model>(model),
//     deleteAction:
//         allowDelete ? (model) async => await deleteModel<Model>(model) : null,
//   );
// }

// class DwAdminModelManagerBlock<
//   Model extends SerializableModel,
//   FormDescriptor extends NitGenericFormsFieldsEnum<Model>
// >
//     extends ConsumerWidget {
//   const DwAdminModelManagerBlock({
//     super.key,
//     required this.fields,
//     required this.listViewBuilder,
//     required this.editingFormPresenter,
//     this.customBackendFilter,
//     this.defaultValuesProvider,
//     required this.allowDelete,
//   });

//   final List<FormDescriptor> fields;
//   final Widget Function({required Model model}) listViewBuilder;

//   final DwBackendFilter? customBackendFilter;
//   final Function(BuildContext context, Widget editingForm) editingFormPresenter;
//   final Future<Map<FormDescriptor, dynamic>> Function(WidgetRef ref)?
//   defaultValuesProvider;
//   final bool allowDelete;

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     return Stack(
//       children: [
//         Positioned.fill(
//           child: InfiniteListView(
//             listViewConfig: DwModelListStateConfig<Model>(
//               backendFilter: customBackendFilter,
//               pageSize: 20,
//             ),
//             listTileBuilder:
//                 (context, model) => Card(
//                   child: Row(
//                     children: [
//                       IconButton(
//                         onPressed:
//                             () async => editingFormPresenter(
//                               context,
//                               NitGenericForm<Model, FormDescriptor>(
//                                 fields: fields,
//                                 model: model,
//                                 modelManager: ref.dwGenericModelManager(
//                                   allowDelete: allowDelete,
//                                 ),
//                               ),
//                             ),
//                         icon: const Icon(Icons.edit),
//                       ),
//                       Expanded(
//                         child: Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: listViewBuilder(model: model),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//           ),
//         ),
//         Positioned(
//           right: 20,
//           bottom: 20,
//           child: FilledButton(
//             onPressed:
//                 () async =>
//                     !context.mounted
//                         ? {}
//                         : editingFormPresenter(
//                           context,
//                           NitGenericForm<Model, FormDescriptor>(
//                             fields: fields,
//                             model: null,
//                             modelManager: ref.dwGenericModelManager<Model>(),
//                             defaultValues: await defaultValuesProvider?.call(
//                               ref,
//                             ),
//                           ),
//                         ),
//             child: const Text('Добавить'),
//           ),
//         ),
//       ],
//     );
//   }
// }
