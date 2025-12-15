import 'package:dartway_serverpod_chat_server/dartway_serverpod_chat_server.dart';
import 'package:dartway_serverpod_chat_server/src/business/chat_channel_extension.dart';
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';

final chatChannelInclude = DwChatChannel.include(
  chatParticipants: DwChatParticipant.includeList(
    include: DwChatParticipant.include(
      lastMessage: DwChatMessage.include(),
      lastReadMessage: DwChatMessage.include(),
      chatChannel: DwChatChannel.include(),
    ),
  ),
);

final chatChannelCrudConfig = DwCrudConfig<DwChatChannel>(
  table: DwChatChannel.t,
  getModelConfigs: [
    DwGetModelConfig(
      filterPrototype: DwBackendFilter.equalsPrototype(fieldName: 'id'),
      include: chatChannelInclude,
    ),
    DwGetModelConfig(
      filterPrototype: DwBackendFilter.equalsPrototype(fieldName: 'channel'),
      include: chatChannelInclude,
      createIfMissing: (session, values) async {
        final channel = values.fieldValue!;

        final insertedChatChannel = await session.createChatChannel(
          channel: channel,
        );

        return insertedChatChannel;
      },
    ),
  ],
  // saveConfig: DwSaveConfig(
  //   allowSave: (session, saveContext) async =>
  //       DwChatChannelNames.getChannelType(saveContext.currentModel.channel) ==
  //           DwChatChannelType.admin &&
  //       (await session.currentUserProfileId) == true,
  //   afterSaveTransaction: (session, saveContext) async {
  //     if (DwChatChannelNames.getChannelType(saveContext.currentModel.channel) ==
  //         ChatChannelType.admin) {
  //       final adminProfiles = await UserProfile.db.find(
  //         session,
  //         where: (t) => t.isAdmin.equals(true),
  //       );

  //       final selfUserId = await session.currentUserProfileId;

  //       final participants = await session.db.insert(
  //         [
  //           DwChatParticipant(
  //             userId: selfUserId!,
  //             chatChannelId: saveContext.currentModel.id!,
  //             chatChannel: saveContext.currentModel,
  //           ),
  //           ...adminProfiles
  //               .where((adminProfile) => adminProfile.id != selfUserId)
  //               .map(
  //                 (adminProfile) => DwChatParticipant(
  //                   userId: adminProfile.id!,
  //                   chatChannelId: saveContext.currentModel.id!,
  //                   chatChannel: saveContext.currentModel,
  //                 ),
  //               ),
  //         ],
  //         transaction: saveContext.transaction,
  //       );
  //       saveContext.currentModel.chatParticipants = participants;
  //     }
  //   },
  // ),
  // TODO: implement deleteConfig
  // deleteConfig: DwDeleteConfig<ChatChannel>(
  //   allowDelete: (session, model) async =>
  //       ChatChannelNames.getChannelType(model.channel) != ChatChannelType.admin,
  //   afterDelete: (session, model) async {
  //     // TODO implement attachments deletion
  //     return [];
  //   },
  // ),
);
