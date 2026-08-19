import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/src/repository/dw_repository.dart';
import 'package:dartway_serverpod_core_flutter/src/repository/domain/dw_pagination_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Query keys are observed where they are actually consumed: a local store is
  // handed the key of every read it is asked to keep, and that is the only
  // place in the framework a key is anybody's business. Reads here declare
  // `networkFirstWithSnapshot` because they genuinely are kept — no read is
  // made to claim something about itself in order to be watched.
  late _TestLocalStore store;
  late _KeyRecordingLocalReads localReads;

  setUpAll(() {
    store = _TestLocalStore();
    _queryKeyCore = DwCore<_EndpointCapturingClient, _QueryLesson>(
      config: const DwConfig(),
      client: _EndpointCapturingClient(),
      dwAlerts: DwAlerts.init(logErrors: false, logFunction: (_) {}),
      getUserId: (_) => null,
      plugins: [store],
    );
    DwRepository.setupRepository(defaultModel: _QueryLesson());
  });

  setUp(() {
    localReads = _KeyRecordingLocalReads();
    store.reads = localReads;
  });

  tearDown(() {
    store.reads = null;
  });

  test(
    'uses one storage key for filters with a different map insertion order',
    () {
      final firstKey = DwRepoQueryKey<_Lesson>.getAll(
        modelClassName: 'Lesson',
        apiGroup: 'learning',
        filters: <String, Object?>{
          'authorId': 42,
          'published': true,
          'topics': <Object?>['dart', null],
        },
        ordering: <Object?>[
          <String, Object?>{'field': 'startsAt', 'descending': false},
        ],
        pagination: <String, Object?>{'limit': 25, 'offset': 50},
        includes: <Object?>['chapters'],
      );
      final reorderedKey = DwRepoQueryKey<_Lesson>.getAll(
        modelClassName: 'Lesson',
        apiGroup: 'learning',
        filters: <String, Object?>{
          'topics': <Object?>['dart', null],
          'published': true,
          'authorId': 42,
        },
        ordering: <Object?>[
          <String, Object?>{'descending': false, 'field': 'startsAt'},
        ],
        pagination: <String, Object?>{'offset': 50, 'limit': 25},
        includes: <Object?>['chapters'],
      );

      expect(firstKey, reorderedKey);
      expect(
        firstKey.toStorageKey(),
        '6e4642628d8947b469c4680275d80a6f800bea97d482b5391512cad81556e2e7',
      );
    },
  );

  test('changes storage identity for every request dimension', () {
    final baseKey = DwRepoQueryKey<_Lesson>.getAll(
      modelClassName: 'Lesson',
      apiGroup: 'learning',
      filters: <String, Object?>{'authorId': 42},
      ordering: <Object?>[
        <String, Object?>{'field': 'startsAt', 'descending': false},
      ],
      pagination: <String, Object?>{'limit': 25, 'offset': 50},
      includes: <Object?>['chapters'],
    );

    final differentKeys = <DwRepoQueryKey<_Lesson>>[
      DwRepoQueryKey<_Lesson>.getOne(
        modelClassName: 'Lesson',
        apiGroup: 'learning',
        filters: <String, Object?>{'authorId': 42},
        ordering: <Object?>[
          <String, Object?>{'field': 'startsAt', 'descending': false},
        ],
        pagination: <String, Object?>{'limit': 25, 'offset': 50},
        includes: <Object?>['chapters'],
      ),
      DwRepoQueryKey<_Lesson>.getAll(
        modelClassName: 'Module',
        apiGroup: 'learning',
        filters: <String, Object?>{'authorId': 42},
        ordering: <Object?>[
          <String, Object?>{'field': 'startsAt', 'descending': false},
        ],
        pagination: <String, Object?>{'limit': 25, 'offset': 50},
        includes: <Object?>['chapters'],
      ),
      DwRepoQueryKey<_Lesson>.getAll(
        modelClassName: 'Lesson',
        apiGroup: 'admin',
        filters: <String, Object?>{'authorId': 42},
        ordering: <Object?>[
          <String, Object?>{'field': 'startsAt', 'descending': false},
        ],
        pagination: <String, Object?>{'limit': 25, 'offset': 50},
        includes: <Object?>['chapters'],
      ),
      DwRepoQueryKey<_Lesson>.getAll(
        modelClassName: 'Lesson',
        apiGroup: 'learning',
        filters: <String, Object?>{'authorId': 43},
        ordering: <Object?>[
          <String, Object?>{'field': 'startsAt', 'descending': false},
        ],
        pagination: <String, Object?>{'limit': 25, 'offset': 50},
        includes: <Object?>['chapters'],
      ),
      DwRepoQueryKey<_Lesson>.getAll(
        modelClassName: 'Lesson',
        apiGroup: 'learning',
        filters: <String, Object?>{'authorId': 42},
        ordering: <Object?>[
          <String, Object?>{'field': 'startsAt', 'descending': true},
        ],
        pagination: <String, Object?>{'limit': 25, 'offset': 50},
        includes: <Object?>['chapters'],
      ),
      DwRepoQueryKey<_Lesson>.getAll(
        modelClassName: 'Lesson',
        apiGroup: 'learning',
        filters: <String, Object?>{'authorId': 42},
        ordering: <Object?>[
          <String, Object?>{'field': 'startsAt', 'descending': false},
        ],
        pagination: <String, Object?>{'limit': 26, 'offset': 50},
        includes: <Object?>['chapters'],
      ),
      DwRepoQueryKey<_Lesson>.getAll(
        modelClassName: 'Lesson',
        apiGroup: 'learning',
        filters: <String, Object?>{'authorId': 42},
        ordering: <Object?>[
          <String, Object?>{'field': 'startsAt', 'descending': false},
        ],
        pagination: <String, Object?>{'limit': 25, 'offset': 51},
        includes: <Object?>['chapters'],
      ),
      DwRepoQueryKey<_Lesson>.getAll(
        modelClassName: 'Lesson',
        apiGroup: 'learning',
        filters: <String, Object?>{'authorId': 42},
        ordering: <Object?>[
          <String, Object?>{'field': 'startsAt', 'descending': false},
        ],
        pagination: <String, Object?>{'limit': 25, 'cursor': 'next-page'},
        includes: <Object?>['chapters'],
      ),
      DwRepoQueryKey<_Lesson>.getAll(
        modelClassName: 'Lesson',
        apiGroup: 'learning',
        filters: <String, Object?>{'authorId': 42},
        ordering: <Object?>[
          <String, Object?>{'field': 'startsAt', 'descending': false},
        ],
        pagination: <String, Object?>{'limit': 25, 'offset': 50},
        includes: <Object?>['chapters', 'materials'],
      ),
    ];

    for (final differentKey in differentKeys) {
      expect(differentKey, isNot(baseKey));
      expect(differentKey.toStorageKey(), isNot(baseKey.toStorageKey()));
    }
  });

  test('preserves list order and rejects unsupported query values', () {
    final firstKey = DwRepoQueryKey<_Lesson>.getAll(
      modelClassName: 'Lesson',
      filters: <String, Object?>{
        'topicIds': <Object?>[7, 8],
      },
    );
    final reorderedKey = DwRepoQueryKey<_Lesson>.getAll(
      modelClassName: 'Lesson',
      filters: <String, Object?>{
        'topicIds': <Object?>[8, 7],
      },
    );

    expect(firstKey, isNot(reorderedKey));
    expect(
      () => DwRepoQueryKey<_Lesson>.getAll(
        modelClassName: 'Lesson',
        filters: <String, Object?>{'createdAt': DateTime.utc(2026, 8, 12)},
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('Unsupported query key value'),
        ),
      ),
    );
  });

  test('list and single configs create keys from their request inputs', () {
    final listConfig = DwModelListStateConfig<_QueryLesson>(
      backendFilter: const DwBackendFilter<int>.value(
        type: DwBackendFilterType.equals,
        fieldName: 'authorId',
        fieldValue: 42,
      ),
      orderByList: [DwOrderBy(fieldName: 'startsAt', orderDescending: true)],
      apiGroupOverride: 'learning',
    );
    final singleConfig = DwSingleModelStateConfig<_QueryLesson>(
      id: 42,
      apiGroupOverride: 'learning',
    );

    expect(
      listConfig.queryKeyFor(const DwPaginationParams(limit: 25, offset: 50)),
      DwRepoQueryKey<_QueryLesson>.getAll(
        modelClassName: 'QueryLesson',
        apiGroup: 'learning',
        filters: <String, Object?>{
          'fieldName': 'authorId',
          'fieldValue': 42,
          'negate': false,
          'type': 'equals',
          'valueClassName': 'int',
        },
        ordering: <Object?>[
          <String, Object?>{'fieldName': 'startsAt', 'orderDescending': true},
        ],
        pagination: <String, Object?>{'limit': 25, 'offset': 50},
      ),
    );
    expect(
      singleConfig.queryKey,
      DwRepoQueryKey<_QueryLesson>.getOne(
        modelClassName: 'QueryLesson',
        apiGroup: 'learning',
        filters: <String, Object?>{
          'fieldName': 'id',
          'fieldValue': 42,
          'negate': false,
          'type': 'equals',
          'valueClassName': 'int',
        },
      ),
    );
  });

  test(
    'list config keeps a stable family hash when caller mutates ordering',
    () {
      final orderByList = [
        DwOrderBy(fieldName: 'startsAt', orderDescending: false),
      ];
      final config = DwModelListStateConfig<_QueryLesson>(
        orderByList: orderByList,
      );
      final initialHash = config.hashCode;
      final initialKey = config.queryKeyFor(
        const DwPaginationParams(limit: 25),
      );

      orderByList.add(DwOrderBy(fieldName: 'title', orderDescending: true));

      expect(config.hashCode, initialHash);
      expect(
        config.queryKeyFor(const DwPaginationParams(limit: 25)),
        initialKey,
      );
      expect(
        () => config.orderByList!.add(
          DwOrderBy(fieldName: 'minutes', orderDescending: false),
        ),
        throwsUnsupportedError,
      );
    },
  );

  test('filter group keeps a stable key when caller mutates children', () {
    final children = <DwBackendFilter>[
      const DwBackendFilter<int>.value(
        type: DwBackendFilterType.equals,
        fieldName: 'authorId',
        fieldValue: 42,
      ),
    ];
    final filter = DwBackendFilter.and(children);
    final config = DwModelListStateConfig<_QueryLesson>(backendFilter: filter);
    final initialHash = config.hashCode;
    final initialKey = config.queryKeyFor(const DwPaginationParams(limit: 25));

    children.add(
      const DwBackendFilter<bool>.value(
        type: DwBackendFilterType.equals,
        fieldName: 'published',
        fieldValue: true,
      ),
    );

    expect(config.hashCode, initialHash);
    expect(config.queryKeyFor(const DwPaginationParams(limit: 25)), initialKey);
    expect(
      () => filter.children!.add(
        const DwBackendFilter<int>.value(
          type: DwBackendFilterType.equals,
          fieldName: 'courseId',
          fieldValue: 7,
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('list config identity distinguishes different server ordering', () {
    final ascendingConfig = DwModelListStateConfig<_QueryLesson>(
      orderByList: [DwOrderBy(fieldName: 'startsAt', orderDescending: false)],
    );
    final equivalentAscendingConfig = DwModelListStateConfig<_QueryLesson>(
      orderByList: [DwOrderBy(fieldName: 'startsAt', orderDescending: false)],
    );
    final descendingConfig = DwModelListStateConfig<_QueryLesson>(
      orderByList: [DwOrderBy(fieldName: 'startsAt', orderDescending: true)],
    );

    expect(ascendingConfig, equivalentAscendingConfig);
    expect(ascendingConfig.hashCode, equivalentAscendingConfig.hashCode);
    expect(ascendingConfig, isNot(descendingConfig));
  });

  test('list config copyWith retains and can replace server ordering', () {
    final initialOrdering = [
      DwOrderBy(fieldName: 'startsAt', orderDescending: false),
    ];
    final replacementOrdering = [
      DwOrderBy(fieldName: 'title', orderDescending: true),
    ];
    final initialConfig = DwModelListStateConfig<_QueryLesson>(
      orderByList: initialOrdering,
    );

    expect(initialConfig.copyWith().orderByList, initialOrdering);
    expect(
      initialConfig.copyWith(orderByList: replacementOrdering).orderByList,
      replacementOrdering,
    );
  });

  test(
    'modelList routes its exact paginated request through to the local store',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final config = DwModelListStateConfig<_QueryLesson>(
        backendFilter: const DwBackendFilter<int>.value(
          type: DwBackendFilterType.equals,
          fieldName: 'authorId',
          fieldValue: 42,
        ),
        orderByList: [DwOrderBy(fieldName: 'startsAt', orderDescending: true)],
        apiGroupOverride: 'learning',
        paginationStrategy: _FixedPagination(),
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
      );

      await container.read(
        DwRepository.modelListStateProvider<_QueryLesson>()(config).future,
      );

      final capturedKey =
          localReads.queryKeys.single as DwRepoQueryKey<_QueryLesson>;
      expect(capturedKey.canonicalFilters, <String, Object?>{
        'children': <Object?>[
          <String, Object?>{
            'fieldName': 'authorId',
            'fieldValue': 42,
            'negate': false,
            'type': 'equals',
            'valueClassName': 'int',
          },
          <String, Object?>{
            'fieldName': 'id',
            'fieldValue': 30,
            'negate': false,
            'type': 'greaterThan',
            'valueClassName': 'int',
          },
          <String, Object?>{
            'fieldName': 'id',
            'fieldValue': 70,
            'negate': false,
            'type': 'lessThan',
            'valueClassName': 'int',
          },
        ],
        'negate': false,
        'type': 'and',
        'valueClassName': 'null',
      });

      expect(localReads.queryKeys, [
        DwRepoQueryKey<_QueryLesson>.getAll(
          modelClassName: 'QueryLesson',
          apiGroup: 'learning',
          filters: <String, Object?>{
            'children': <Object?>[
              <String, Object?>{
                'fieldName': 'authorId',
                'fieldValue': 42,
                'negate': false,
                'type': 'equals',
                'valueClassName': 'int',
              },
              <String, Object?>{
                'fieldName': 'id',
                'fieldValue': 30,
                'negate': false,
                'type': 'greaterThan',
                'valueClassName': 'int',
              },
              <String, Object?>{
                'fieldName': 'id',
                'fieldValue': 70,
                'negate': false,
                'type': 'lessThan',
                'valueClassName': 'int',
              },
            ],
            'negate': false,
            'type': 'and',
            'valueClassName': 'null',
          },
          ordering: <Object?>[
            <String, Object?>{'fieldName': 'startsAt', 'orderDescending': true},
          ],
          pagination: <String, Object?>{
            'afterId': 30,
            'beforeId': 70,
            'limit': 20,
            'offset': 40,
          },
        ),
      ]);
    },
  );

  test(
    'modelList sends the key API group to the actual endpoint request',
    () async {
      final endpointClient = _queryKeyCore.client..reset();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final config = DwModelListStateConfig<_QueryLesson>(
        apiGroupOverride: 'learning',
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
      );

      await container.read(
        DwRepository.modelListStateProvider<_QueryLesson>()(config).future,
      );

      expect(localReads.queryKeys.single.apiGroup, 'learning');
      expect(endpointClient.getAllApiGroup, 'learning');
    },
  );

  test('dw.repo exposes exact keys for default reactive reads', () async {
    final filter = const DwBackendFilter<int>.value(
      type: DwBackendFilterType.equals,
      fieldName: 'authorId',
      fieldValue: 42,
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(
      const DwRepo()
          .modelList<_QueryLesson>(
            customConfig: DwModelListStateConfig<_QueryLesson>(
              backendFilter: filter,
              readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
            ),
          )
          .future,
    );

    expect(
      const DwRepo().unpaginatedModelListQueryKey<_QueryLesson>(
        backendFilter: filter,
      ),
      localReads.queryKeys.single,
    );
    expect(
      const DwRepo().modelQueryKey<_QueryLesson>(id: 42),
      DwSingleModelStateConfig<_QueryLesson>(id: 42).queryKey,
    );
  });

  test(
    'single initial and forced reads route the same key to the local store',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final config = DwSingleModelStateConfig<_QueryLesson>(
        id: 42,
        apiGroupOverride: 'learning',
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
      );
      final provider = DwRepository.singleModelProvider<_QueryLesson>()(config);

      await container.read(provider.future);
      await container.read(provider.notifier).read(forceFetch: true);

      final expectedKey = DwRepoQueryKey<_QueryLesson>.getOne(
        modelClassName: 'QueryLesson',
        apiGroup: 'learning',
        filters: <String, Object?>{
          'fieldName': 'id',
          'fieldValue': 42,
          'negate': false,
          'type': 'equals',
          'valueClassName': 'int',
        },
      );
      expect(localReads.queryKeys, [expectedKey, expectedKey]);
    },
  );

  test(
    'dw.repo.fetchList routes the imperative request to the local store',
    () async {
      await const DwRepo().fetchList<_QueryLesson>(
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        filter: const DwBackendFilter<int>.value(
          type: DwBackendFilterType.equals,
          fieldName: 'authorId',
          fieldValue: 42,
        ),
        orderByList: [DwOrderBy(fieldName: 'startsAt', orderDescending: true)],
        limit: 20,
        offset: 40,
        apiGroupOverride: 'learning',
      );

      expect(localReads.queryKeys, [
        DwRepoQueryKey<_QueryLesson>.getAll(
          modelClassName: 'QueryLesson',
          apiGroup: 'learning',
          filters: <String, Object?>{
            'fieldName': 'authorId',
            'fieldValue': 42,
            'negate': false,
            'type': 'equals',
            'valueClassName': 'int',
          },
          ordering: <Object?>[
            <String, Object?>{'fieldName': 'startsAt', 'orderDescending': true},
          ],
          pagination: <String, Object?>{'limit': 20, 'offset': 40},
        ),
      ]);
    },
  );
}

class _Lesson {}

class _QueryLesson implements SerializableModel {
  @override
  Map<String, dynamic> toJson() => <String, dynamic>{};
}

class _QueryKeyProtocol extends SerializationManager {
  @override
  String? getClassNameForObject(Object? value) => switch (value) {
    _QueryLesson() => 'QueryLesson',
    int() => 'int',
    _ => super.getClassNameForObject(value),
  };
}

late final DwCore<_EndpointCapturingClient, _QueryLesson> _queryKeyCore;

class _EndpointCapturingClient extends ServerpodClientShared {
  _EndpointCapturingClient()
    : super(
        'http://localhost:8080',
        _QueryKeyProtocol(),
        streamingConnectionTimeout: null,
        connectionTimeout: null,
      ) {
    _dartwayCaller = Caller(this);
  }

  late final Caller _dartwayCaller;
  String? getAllApiGroup;

  void reset() {
    getAllApiGroup = null;
  }

  @override
  Map<String, ModuleEndpointCaller> get moduleLookup =>
      <String, ModuleEndpointCaller>{'dartway_serverpod_core': _dartwayCaller};

  @override
  Map<String, EndpointRef> get endpointRefLookup => <String, EndpointRef>{};

  @override
  Future<T> callServerEndpoint<T>(
    String endpoint,
    String method,
    Map<String, dynamic> args, {
    bool authenticated = true,
  }) async {
    if (endpoint == 'dartway_serverpod_core.dwCrud' && method == 'getAll') {
      getAllApiGroup = args['apiGroup'] as String?;
      return const DwApiResponse<List<DwModelWrapper>>(
            isOk: true,
            value: <DwModelWrapper>[],
          )
          as T;
    }
    if (endpoint == 'dartway_serverpod_core.dwCrud' && method == 'getOne') {
      return const DwApiResponse<DwModelWrapper>(isOk: true, value: null) as T;
    }
    throw StateError('Unexpected endpoint request: $endpoint.$method');
  }
}

class _FixedPagination implements DwPaginationStrategy {
  @override
  int? get limit => 20;

  @override
  DwPaginationParams buildParams() => const DwPaginationParams(
    afterId: 30,
    beforeId: 70,
    limit: 20,
    offset: 40,
  );

  @override
  bool get hasMore => true;

  @override
  void onPageLoaded(List<DwModelWrapper> data) {}

  @override
  void reset() {}
}

/// The application's own plugin, standing in for a real store.
class _TestLocalStore extends DwRepoLocalStorePlugin {
  DwRepoLocalReads? reads;

  @override
  DwRepoLocalReads? get localReads => reads;

  @override
  DwRepoLocalWrites? get localWrites => null;

  @override
  Future<void> init(DwFlutter core) async {}
}

/// Keeps nothing; records the identity every read is offered under.
class _KeyRecordingLocalReads implements DwRepoLocalReads {
  final queryKeys = <DwRepoQueryKey<Object?>>[];
  late final _binding = DwRepoBinding(scope: DwRepoScope('query-key-test'));

  @override
  Future<DwRepoBinding?> resolveBinding() async => _binding;

  @override
  Future<bool> isBindingCurrent(DwRepoBinding binding) async =>
      identical(binding, _binding);

  @override
  Future<DwRepoReadSnapshot?> loadSnapshot<Model>({
    required DwRepoBinding binding,
    required DwRepoQueryKey<Model> queryKey,
  }) async => null;

  @override
  Future<R> keep<R>(Future<R> Function(DwRepoLocalReadTx tx) body) =>
      body(_KeyRecordingReadTx(this));
}

class _KeyRecordingReadTx implements DwRepoLocalReadTx {
  _KeyRecordingReadTx(this._store);

  final _KeyRecordingLocalReads _store;

  @override
  Future<bool> isBindingCurrent(DwRepoBinding binding) =>
      _store.isBindingCurrent(binding);

  @override
  Future<bool> storeSnapshot<Model>({
    required DwRepoQueryKey<Model> queryKey,
    required DwRepoReadSnapshot snapshot,
  }) async {
    _store.queryKeys.add(queryKey as DwRepoQueryKey<Object?>);
    return true;
  }
}
