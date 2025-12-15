// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dwChatStateHash() => r'fb10dbc65f6e0ddeb69b9cb9f173ca334c323d77';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$DwChatState
    extends BuildlessAutoDisposeNotifier<DwChatStateModel> {
  late final int chatId;

  DwChatStateModel build(
    int chatId,
  );
}

/// See also [DwChatState].
@ProviderFor(DwChatState)
const dwChatStateProvider = DwChatStateFamily();

/// See also [DwChatState].
class DwChatStateFamily extends Family<DwChatStateModel> {
  /// See also [DwChatState].
  const DwChatStateFamily();

  /// See also [DwChatState].
  DwChatStateProvider call(
    int chatId,
  ) {
    return DwChatStateProvider(
      chatId,
    );
  }

  @override
  DwChatStateProvider getProviderOverride(
    covariant DwChatStateProvider provider,
  ) {
    return call(
      provider.chatId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'dwChatStateProvider';
}

/// See also [DwChatState].
class DwChatStateProvider
    extends AutoDisposeNotifierProviderImpl<DwChatState, DwChatStateModel> {
  /// See also [DwChatState].
  DwChatStateProvider(
    int chatId,
  ) : this._internal(
          () => DwChatState()..chatId = chatId,
          from: dwChatStateProvider,
          name: r'dwChatStateProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$dwChatStateHash,
          dependencies: DwChatStateFamily._dependencies,
          allTransitiveDependencies:
              DwChatStateFamily._allTransitiveDependencies,
          chatId: chatId,
        );

  DwChatStateProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.chatId,
  }) : super.internal();

  final int chatId;

  @override
  DwChatStateModel runNotifierBuild(
    covariant DwChatState notifier,
  ) {
    return notifier.build(
      chatId,
    );
  }

  @override
  Override overrideWith(DwChatState Function() create) {
    return ProviderOverride(
      origin: this,
      override: DwChatStateProvider._internal(
        () => create()..chatId = chatId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        chatId: chatId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<DwChatState, DwChatStateModel>
      createElement() {
    return _DwChatStateProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DwChatStateProvider && other.chatId == chatId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, chatId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DwChatStateRef on AutoDisposeNotifierProviderRef<DwChatStateModel> {
  /// The parameter `chatId` of this provider.
  int get chatId;
}

class _DwChatStateProviderElement
    extends AutoDisposeNotifierProviderElement<DwChatState, DwChatStateModel>
    with DwChatStateRef {
  _DwChatStateProviderElement(super.provider);

  @override
  int get chatId => (origin as DwChatStateProvider).chatId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
