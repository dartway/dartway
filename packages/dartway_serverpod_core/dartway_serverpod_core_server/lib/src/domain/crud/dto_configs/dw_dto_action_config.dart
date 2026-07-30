import 'dart:async';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import '../domain/dw_crud_entity.dart';
import '../../../private/dw_singleton.dart';

class DwDtoActionConfig<DTO extends SerializableModel> with DwCrudEntity<DTO> {
  const DwDtoActionConfig({
    this.allowAnonymous = false,
    required this.actionProcessing,
    this.afterSaveSideEffects,
  });


  /// Whether a caller who is not signed in may reach this operation.
  ///
  /// Defaults to `false`: a CRUD endpoint is reachable without a session, so
  /// without this gate the operation is open to the internet. Not configured
  /// means not allowed. Set it to `true` deliberately, and only for data that
  /// genuinely precedes the login screen.
  final bool allowAnonymous;

  final Future<List<DwModelWrapper>> Function(
    Session session,
    Transaction transaction,
    DTO dto,
  )
  actionProcessing;

  final Future<void> Function(
    Session session,
    DTO dto,
    List<DwModelWrapper> updatedModels,
  )?
  afterSaveSideEffects;

  /// Runs [actionProcessing] in a transaction, then fires the side effects.
  Future<DwApiResponse<DwModelWrapper>> save(Session session, DTO dto) async {
    // --- transaction block ---
    List<DwModelWrapper> updatedModels = [];

    try {
      await session.db.transaction((transaction) async {
        updatedModels = await actionProcessing(session, transaction, dto);
      });
    } on DatabaseException catch (e, stackTrace) {
      dw.alerts.reportError(
        'Database error while running the ${DTO.toString()} action',
        exception: e,
        stackTrace: stackTrace,
      );
      return DwApiResponse(
        isOk: false,
        value: null,
        error: 'Database error during save: $e',
      );
    }

    // --- afterSideEffects (outside the transaction, non-blocking) ---
    if (afterSaveSideEffects != null) {
      unawaited(afterSaveSideEffects!(session, dto, updatedModels));
    }

    return DwApiResponse(
      isOk: true,
      value: DwModelWrapper(object: dto),
      updatedModels: updatedModels,
    );
  }
}
