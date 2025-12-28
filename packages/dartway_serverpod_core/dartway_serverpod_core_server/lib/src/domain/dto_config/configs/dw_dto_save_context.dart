// import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
// import 'package:serverpod/serverpod.dart';

// /// Context for save operation.
// /// Available on all stages of the lifecycle.
// class DwDtoSaveContext<DTO extends SerializableModel, Model extends TableRow> {
//   final int? currentUserId;
//   final DTO dto;
//   final Model? initialModel;

//   /// Current model (updated on each step).
//   Model? currentModel;

//   Transaction? transaction;

//   /// Updates made before and after the main save.
//   final List<DwModelWrapper> beforeUpdates = [];
//   final List<DwModelWrapper> afterUpdates = [];

//   /// Arbitrary data between steps.
//   final Map<String, dynamic> extras = {};

//   DwDtoSaveContext({
//     required this.currentUserId,
//     required this.dto,
//     required this.initialModel,
//   });

//   bool get isInsert => initialModel == null;
// }
