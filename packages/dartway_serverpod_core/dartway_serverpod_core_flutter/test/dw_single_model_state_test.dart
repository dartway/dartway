import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/src/repository/dw_repository.dart';
import 'package:dartway_serverpod_core_flutter/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A single-model read that answered "no such row" has to hear about the row
/// once it exists. It used to stop listening the moment it resolved to null:
/// a feature saved a model, read the provider back and was told the row did
/// not exist, with nothing anywhere saying so (#242).
void main() {
  late DwRecordingServerTransport transport;

  setUpAll(() {
    // A manager that can read the model back, not only name it: updates reach
    // a live state the way the wire delivers them — through
    // `DwModelWrapper.fromJson`, which is what carries a `modelId`.
    transport = DwRecordingServerTransport(
      serializationManager: _OwnedProtocol(),
    );
    DwCore<ServerpodClientShared, _OwnedModel>(
      config: const DwConfig(),
      transport: transport,
      dwAlerts: DwAlerts.init(logErrors: false, logFunction: (_) {}),
      getUserId: (_) => null,
    );
    DwRepository.setupRepository(defaultModel: const _OwnedModel(id: 0));
  });

  setUp(() {
    transport.reset();
    // The server has no row yet — the state every case starts from.
    transport.answerGetOne = (_) async =>
        const DwApiResponse<DwModelWrapper>(isOk: true, value: null);
  });

  final ownerSeven = DwBackendFilter<int>.value(
    type: DwBackendFilterType.equals,
    fieldName: 'ownerId',
    fieldValue: 7,
  );

  Future<
    (
      ProviderContainer,
      AsyncNotifierProvider<DwSingleModelState<_OwnedModel>, _OwnedModel?>,
    )
  >
  emptyRead({int? id, DwBackendFilter? filter}) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = const DwRepo().maybeModel<_OwnedModel>(
      id: id,
      filter: filter,
    );
    // Keep it alive the way a watching widget would.
    container.listen(provider, (_, _) {});
    expect(await container.read(provider.future), isNull);
    return (container, provider);
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a created row that passes the filter fills the empty read', () async {
    final (container, provider) = await emptyRead(filter: ownerSeven);

    DwRepository.updateListeningStates(
      wrappedModelUpdates: [_arrived(const _OwnedModel(id: 1, ownerId: 7))],
    );
    await settle();

    expect(
      container.read(provider).value,
      const _OwnedModel(id: 1, ownerId: 7),
    );
  });

  test('a row that does not pass the filter leaves it empty', () async {
    final (container, provider) = await emptyRead(filter: ownerSeven);

    DwRepository.updateListeningStates(
      wrappedModelUpdates: [_arrived(const _OwnedModel(id: 2, ownerId: 8))],
    );
    await settle();

    expect(container.read(provider).value, isNull);
  });

  test('a read by id is filled by the row with that id', () async {
    // `id:` folds into an `id equals` filter, so the one rule covers both.
    final (container, provider) = await emptyRead(id: 42);

    DwRepository.updateListeningStates(
      wrappedModelUpdates: [
        _arrived(const _OwnedModel(id: 41, ownerId: 7)),
        _arrived(const _OwnedModel(id: 42, ownerId: 7)),
      ],
    );
    await settle();

    expect(container.read(provider).value?.id, 42);
  });

  test('a row already there is still replaced by its update', () async {
    transport.answerGetOne = (_) async => DwApiResponse<DwModelWrapper>(
      isOk: true,
      value: DwModelWrapper.wrap(model: const _OwnedModel(id: 5, ownerId: 7)),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = const DwRepo().maybeModel<_OwnedModel>(filter: ownerSeven);
    container.listen(provider, (_, _) {});
    expect((await container.read(provider.future))?.id, 5);

    DwRepository.updateListeningStates(
      wrappedModelUpdates: [
        _arrived(const _OwnedModel(id: 5, ownerId: 7, note: 'edited')),
      ],
    );
    await settle();

    expect(container.read(provider).value?.note, 'edited');
  });
}

/// An update as the wire delivers it.
DwModelWrapper _arrived(_OwnedModel model) => DwModelWrapper.fromJson({
  'className': 'OwnedModel',
  'data': model.toJson(),
  'isDeleted': false,
});

class _OwnedProtocol extends SerializationManager {
  @override
  String? getClassNameForObject(Object? data) =>
      data is _OwnedModel ? 'OwnedModel' : super.getClassNameForObject(data);

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    if (data['className'] == 'OwnedModel') {
      final json = data['data'] as Map<String, dynamic>;
      return _OwnedModel(
        id: json['id'] as int,
        ownerId: json['ownerId'] as int,
        note: json['note'] as String?,
      );
    }
    return super.deserializeByClassName(data);
  }
}

class _OwnedModel implements SerializableModel {
  const _OwnedModel({required this.id, this.ownerId = 0, this.note});

  final int id;
  final int ownerId;
  final String? note;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    if (note != null) 'note': note,
  };

  @override
  bool operator ==(Object other) =>
      other is _OwnedModel &&
      other.id == id &&
      other.ownerId == ownerId &&
      other.note == note;

  @override
  int get hashCode => Object.hash(id, ownerId, note);
}
