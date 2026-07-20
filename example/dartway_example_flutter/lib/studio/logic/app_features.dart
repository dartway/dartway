import 'package:dartway_flutter/dartway_flutter.dart';

/// The app's feature registry — the single enumerable source of feature
/// identity. Widgets reference these values from their [DwFeature]
/// implementation; the Studio manifest ships `values` as the full catalog, so
/// the platform can diff it on every connect (new features surface, a
/// vanished feature with open work is flagged).
///
/// Id convention: `<feature-folder>/<meaningful-name>` — the prefix is the
/// widget's top-level feature folder under `lib/app/` (domain identity,
/// survives refactors inside the folder). Ids are a contract: never rename
/// one in place — add a new value and retire the old id explicitly.
enum AppFeatures implements DwFeatureSpec {
  scheduleSessionList(
    id: 'schedule/session-list',
    title: 'Realtime session list',
    description: 'ref.watchModelList<ClubSession>() with a backend filter — '
        'realtime sync, pagination and loading states out of the box.',
  ),
  chatMessageList(
    id: 'chat/message-list',
    title: 'Realtime staff chat',
    description: 'A realtime chat is ~40 lines of DwCrudConfig, '
        'secure-by-default: the staff-only access filter means clients '
        'never receive it.',
  ),
  chatMessageComposer(
    id: 'chat/message-composer',
    title: 'Message composer',
    description: 'Sending is a single DwRepository.saveModel(ChatMessage) — '
        'the list above updates in realtime, no extra wiring.',
  );

  const AppFeatures({
    required this.id,
    required this.title,
    required this.description,
  });

  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
}
