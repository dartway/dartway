import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import '../endpoints/dw_real_time_endpoint.dart';

extension DwSessionExtension on Session {
  Future<int?> get currentUserProfileId async =>
      await DwCore.instance.currentUserProfile(this).then((value) => value?.id);

  Future<bool> isUser(int userProfileId) async =>
      userProfileId == await currentUserProfileId;

  sendUpdatesToUser(
    int userProfileId, {
    List<TableRow?>? updatedModels,
    List<TableRow?>? deletedModels,
  }) {
    messages.postMessage(
      DwRealTimeEndpoint.userUpdatesChannel(userProfileId),
      DwUpdatesTransport(
        wrappedModelUpdates: [
          if (updatedModels != null) ...DwModelWrapper.wrapMany(updatedModels),
          if (deletedModels != null)
            ...deletedModels
                .where((e) => e != null)
                .map((e) => DwModelWrapper.deleted(object: e!)),
        ],
      ),
    );
  }
}
