import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_client/testing.dart';
import 'package:test/test.dart';

import 'support.dart' show settle;

enum PlanStatus { draft, active }

enum FeedKind with DwOpenEnum { created, renamed, unknown }

/// A plan as the server writes it: [statusName] is whatever name the server's
/// build has, read back through the strict enum as the app's codec reads it.
final class PlanCard extends DwDataObject {
  const PlanCard({required this.id, required this.statusName});

  @override
  final int id;
  final String statusName;

  PlanStatus get status =>
      DwJsonCodec.decodeEnum(statusName, PlanStatus.values);

  @override
  String get dwTypeName => 'PlanCard';

  @override
  Map<String, Object?> toJson() => {'id': id, 'status': statusName};

  static PlanCard fromJson(Map<String, Object?> json) => PlanCard(
    id: json['id']! as int,
    statusName: DwJsonCodec.decodeEnum(json['status'], PlanStatus.values).name,
  );
}

final class FeedEntry extends DwDataObject {
  const FeedEntry({required this.id, required this.kindName});

  @override
  final int id;
  final String kindName;

  @override
  String get dwTypeName => 'FeedEntry';

  @override
  Map<String, Object?> toJson() => {'id': id, 'kind': kindName};

  static FeedEntry fromJson(Map<String, Object?> json) => FeedEntry(
    id: json['id']! as int,
    kindName: DwJsonCodec.decodeEnum(json['kind'], FeedKind.values).name,
  );
}

final class GetPlan extends DwSingleRequest<PlanCard> {
  const GetPlan();

  @override
  String get dwTypeName => 'GetPlan';

  @override
  Map<String, Object?> toJson() => const {};

  static GetPlan fromJson(Map<String, Object?> json) => const GetPlan();
}

final class GetFeedEntry extends DwSingleRequest<FeedEntry> {
  const GetFeedEntry();

  @override
  String get dwTypeName => 'GetFeedEntry';

  @override
  Map<String, Object?> toJson() => const {};

  static GetFeedEntry fromJson(Map<String, Object?> json) =>
      const GetFeedEntry();
}

final protocol = DwWireProtocol([
  const DwProtocolEntry<PlanCard>('PlanCard', PlanCard.fromJson),
  const DwProtocolEntry<FeedEntry>('FeedEntry', FeedEntry.fromJson),
  const DwProtocolEntry<GetPlan>('GetPlan', GetPlan.fromJson),
  const DwProtocolEntry<GetFeedEntry>('GetFeedEntry', GetFeedEntry.fromJson),
], include: DwWireProtocol.core);

void main() {
  late DwFakeServer server;
  late DwAppClient client;
  final reported = <Object>[];

  setUp(() async {
    reported.clear();
    server = DwFakeServer(protocol: protocol)
      ..onRequest<GetPlan>(
        (r, call) => const DwCallOk(PlanCard(id: 1, statusName: 'archived')),
      )
      ..onRequest<GetFeedEntry>(
        (r, call) => const DwCallOk(
          FeedEntry(id: 2, kindName: 'decompositionCancelled'),
        ),
      );
    client = server.newClient(onError: (error, _) => reported.add(error));
    addTearDown(client.stop);
    await client.start();
  });

  final updateRequired = DwCallRefusal(DwCoreRefusal.updateRequired);

  test('a strict enum value this build does not know makes the app out of '
      'date, instead of failing the call', () async {
    final result = await client.fetch(const GetPlan());
    expect(result, isA<DwCallRefused<PlanCard>>());
    expect((result as DwCallRefused<PlanCard>).refusal, updateRequired);
    expect(client.incompatibility, updateRequired);
    expect(client.connectionStatus, DwConnectionStatus.incompatible);
  });

  test('a watched request reading such a value does the same', () async {
    final watch = client.watch(const GetPlan());
    final states = DwStreamRecording(watch.states);
    await settle();
    expect(client.incompatibility, updateRequired);
    expect(
      states.values.last,
      isA<DwRequestRefused<PlanCard>>().having(
        (s) => s.refusal,
        'refusal',
        updateRequired,
      ),
    );
  });

  test('an open enum reads the unknown value and the app goes on', () async {
    final result = await client.fetch(const GetFeedEntry());
    expect(result.valueOrNull?.kindName, 'unknown');
    expect(client.incompatibility, isNull);
  });
}
