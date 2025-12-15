import 'package:dartway_serverpod_chat_server/dartway_serverpod_chat_server.dart';
import 'package:dartway_serverpod_chat_server/src/business/chat_channel_extension.dart';
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

final chatParticipantInclude = DwChatParticipant.include(
  chatChannel: DwChatChannel.include(),
  lastMessage: DwChatMessage.include(),
  lastReadMessage: DwChatMessage.include(),
);

final chatParticipantCrudConfig = DwCrudConfig<DwChatParticipant>(
  table: DwChatParticipant.t,
  getListConfig: DwGetListConfig<DwChatParticipant>(
    defaultOrderByList: [
      Order(
        column: DwChatParticipant.t.lastMessageSentAt,
        orderDescending: true,
      ),
    ],
    include: chatParticipantInclude,
  ),
  getModelConfigs: [
    DwGetModelConfig<DwChatParticipant>(
      filterPrototype: DwBackendFilter.andPrototype(
        children: [
          DwBackendFilter.equalsPrototype(fieldName: 'chatChannelId'),
          DwBackendFilter.equalsPrototype(fieldName: 'userId'),
        ],
      ),
      include: chatParticipantInclude,
      createIfMissing: (session, filter) async {
        final chatChannelId = filter.children!.first.fieldValue;
        final userId = filter.children!.last.fieldValue;
        return await session.joinChatChannel(
          chatChannelId: chatChannelId,
          userId: userId,
        );
      },
    ),
    DwGetModelConfig(
      filterPrototype: DwBackendFilter.equalsPrototype(fieldName: 'id'),
      createIfMissing: (session, filter) async {
        final chatChannelId = filter.children!.first.fieldValue;
        final userId = filter.children!.last.fieldValue;
        return await session.joinChatChannel(
          chatChannelId: chatChannelId,
          userId: userId,
        );
      },
      include: chatParticipantInclude,
    ),
    DwGetModelConfig(
      filterPrototype: DwBackendFilter.equalsPrototype(
        fieldName: 'chatChannelId',
      ),
      createIfMissing: (session, filter) async {
        final chatChannelId = filter.children!.first.fieldValue;
        final userId = filter.children!.last.fieldValue;
        return await session.joinChatChannel(
          chatChannelId: chatChannelId,
          userId: userId,
        );
      },
    ),
  ],
);
