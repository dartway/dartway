import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/src/repository/dw_repository.dart';
import 'package:dartway_serverpod_core_flutter/src/repository/domain/dw_pagination_strategy.dart';
import 'package:dartway_serverpod_core_flutter/src/repository/domain/dw_repository_read_executor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    final endpointClient = _EndpointCapturingClient();
    _queryKeyCore = DwCore<_EndpointCapturingClient, _QueryLesson>(
      config: const DwConfig(),
      client: endpointClient,
      dwAlerts: DwAlerts.init(logErrors: false, logFunction: (_) {}),
      getUserId: (_) => null,
    );
    DwRepository.setupRepository(defaultModel: _QueryLesson());
  });

  late _CapturingReadExecutor readExecutor;

  setUp(() {
    readExecutor = _CapturingReadExecutor();
    DwRepository.readExecutor = readExecutor;
  });

  tearDown(() {
    DwRepository.readExecutor = const DwOnlineRepositoryReadExecutor();
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
    'modelList routes its exact paginated request through the read executor',
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
      );

      await container.read(
        DwRepository.modelListStateProvider<_QueryLesson>()(config).future,
      );

      final capturedKey =
          readExecutor.queryKeys.single as DwRepoQueryKey<_QueryLesson>;
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

      expect(readExecutor.queryKeys, [
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
      final executor = _CapturingOnlineReadExecutor();
      DwRepository.readExecutor = executor;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final config = DwModelListStateConfig<_QueryLesson>(
        apiGroupOverride: 'learning',
      );

      await container.read(
        DwRepository.modelListStateProvider<_QueryLesson>()(config).future,
      );

      expect(executor.queryKeys.single.apiGroup, 'learning');
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
      const DwRepo().modelList<_QueryLesson>(backendFilter: filter).future,
    );

    expect(
      const DwRepo().unpaginatedModelListQueryKey<_QueryLesson>(
        backendFilter: filter,
      ),
      readExecutor.queryKeys.single,
    );
    expect(
      const DwRepo().modelQueryKey<_QueryLesson>(id: 42),
      DwSingleModelStateConfig<_QueryLesson>(id: 42).queryKey,
    );
  });

  test(
    'single initial and forced reads route the same key through executor',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final config = DwSingleModelStateConfig<_QueryLesson>(
        id: 42,
        apiGroupOverride: 'learning',
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
      expect(readExecutor.queryKeys, [expectedKey, expectedKey]);
    },
  );

  test(
    'dw.repo.fetchList routes the imperative request through executor',
    () async {
      await const DwRepo().fetchList<_QueryLesson>(
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

      expect(readExecutor.queryKeys, [
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

class _CapturingReadExecutor implements DwRepositoryReadExecutor {
  final queryKeys = <Object>[];

  @override
  Future<Response> execute<Model, Response>({
    required DwRepoQueryKey<Model> queryKey,
    required Future<Response> Function() onlineRequest,
  }) async {
    queryKeys.add(queryKey);
    if (Response == DwApiResponse<List<DwModelWrapper>>) {
      return const DwApiResponse<List<DwModelWrapper>>(
            isOk: true,
            value: <DwModelWrapper>[],
          )
          as Response;
    }
    if (Response == DwApiResponse<DwModelWrapper>) {
      return const DwApiResponse<DwModelWrapper>(isOk: true, value: null)
          as Response;
    }
    throw StateError('Unexpected read response type $Response');
  }
}

class _CapturingOnlineReadExecutor implements DwRepositoryReadExecutor {
  final _onlineExecutor = const DwOnlineRepositoryReadExecutor();
  final queryKeys = <DwRepoQueryKey<Object?>>[];

  @override
  Future<Response> execute<Model, Response>({
    required DwRepoQueryKey<Model> queryKey,
    required Future<Response> Function() onlineRequest,
  }) {
    queryKeys.add(queryKey as DwRepoQueryKey<Object?>);
    return _onlineExecutor.execute(
      queryKey: queryKey,
      onlineRequest: onlineRequest,
    );
  }
}
