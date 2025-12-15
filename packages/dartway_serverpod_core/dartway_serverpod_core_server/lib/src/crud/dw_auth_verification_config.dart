import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_serverpod_core_server/src/business/auth/dw_auth_utils.dart';
import 'package:dartway_serverpod_core_server/src/business/auth/dw_auth_verification_extension.dart';
import 'package:serverpod/serverpod.dart';

const verificationCodeKey = 'verificationCode';

final dwAuthVerificationConfig = DwCrudConfig<DwAuthVerification>(
  table: DwAuthVerification.t,
  saveConfig: DwSaveConfig<DwAuthVerification>(
    allowSave:
        (
          Session session,
          DwSaveContext<DwAuthVerification> saveContext,
        ) async => true,
    // TODO: implement attempts limit and reset period
    beforeSaveTransaction: (
      Session session,
      DwSaveContext<DwAuthVerification> saveContext,
    ) async {
      final authRequest = await DwAuthRequest.db.findById(
        session,
        saveContext.currentModel.dwAuthRequestId,
      );

      if (saveContext.currentModel.verificationCode == null ||
          authRequest?.verificationHash !=
              DwAuthUtils.hashVerificationCode(
                saveContext.currentModel.verificationCode!,
              )) {
        saveContext.currentModel.setFailed(
          session,
          DwAuthFailReason.invalidVerificationCode,
        );
      } else {
        saveContext.currentModel.accessToken =
            DwAuthUtils.generateSecureToken();
      }
    },
  ),
);
