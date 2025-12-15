// // GENERATED CODE - DO NOT MODIFY BY HAND

// part of 'dw_router_state.dart';

// // **************************************************************************
// // RiverpodGenerator
// // **************************************************************************

// String _$dwRouterStateHash() => r'903bbff94f7ad7d4b44d6ea328d059b90f64a64d';

// /// Copied from Dart SDK
// class _SystemHash {
//   _SystemHash._();

//   static int combine(int hash, int value) {
//     // ignore: parameter_assignments
//     hash = 0x1fffffff & (hash + value);
//     // ignore: parameter_assignments
//     hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
//     return hash ^ (hash >> 6);
//   }

//   static int finish(int hash) {
//     // ignore: parameter_assignments
//     hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
//     // ignore: parameter_assignments
//     hash = hash ^ (hash >> 11);
//     return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
//   }
// }

// abstract class _$DwRouterState extends BuildlessAutoDisposeNotifier<GoRouter> {
//   late final DwRouterConfig config;

//   GoRouter build(
//     DwRouterConfig config,
//   );
// }

// /// See also [DwRouterState].
// @ProviderFor(DwRouterState)
// const dwRouterStateProvider = DwRouterStateFamily();

// /// See also [DwRouterState].
// class DwRouterStateFamily extends Family<GoRouter> {
//   /// See also [DwRouterState].
//   const DwRouterStateFamily();

//   /// See also [DwRouterState].
//   DwRouterStateProvider call(
//     DwRouterConfig config,
//   ) {
//     return DwRouterStateProvider(
//       config,
//     );
//   }

//   @override
//   DwRouterStateProvider getProviderOverride(
//     covariant DwRouterStateProvider provider,
//   ) {
//     return call(
//       provider.config,
//     );
//   }

//   static const Iterable<ProviderOrFamily>? _dependencies = null;

//   @override
//   Iterable<ProviderOrFamily>? get dependencies => _dependencies;

//   static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

//   @override
//   Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
//       _allTransitiveDependencies;

//   @override
//   String? get name => r'dwRouterStateProvider';
// }

// /// See also [DwRouterState].
// class DwRouterStateProvider
//     extends AutoDisposeNotifierProviderImpl<DwRouterState, GoRouter> {
//   /// See also [DwRouterState].
//   DwRouterStateProvider(
//     DwRouterConfig config,
//   ) : this._internal(
//           () => DwRouterState()..config = config,
//           from: dwRouterStateProvider,
//           name: r'dwRouterStateProvider',
//           debugGetCreateSourceHash:
//               const bool.fromEnvironment('dart.vm.product')
//                   ? null
//                   : _$dwRouterStateHash,
//           dependencies: DwRouterStateFamily._dependencies,
//           allTransitiveDependencies:
//               DwRouterStateFamily._allTransitiveDependencies,
//           config: config,
//         );

//   DwRouterStateProvider._internal(
//     super._createNotifier, {
//     required super.name,
//     required super.dependencies,
//     required super.allTransitiveDependencies,
//     required super.debugGetCreateSourceHash,
//     required super.from,
//     required this.config,
//   }) : super.internal();

//   final DwRouterConfig config;

//   @override
//   GoRouter runNotifierBuild(
//     covariant DwRouterState notifier,
//   ) {
//     return notifier.build(
//       config,
//     );
//   }

//   @override
//   Override overrideWith(DwRouterState Function() create) {
//     return ProviderOverride(
//       origin: this,
//       override: DwRouterStateProvider._internal(
//         () => create()..config = config,
//         from: from,
//         name: null,
//         dependencies: null,
//         allTransitiveDependencies: null,
//         debugGetCreateSourceHash: null,
//         config: config,
//       ),
//     );
//   }

//   @override
//   AutoDisposeNotifierProviderElement<DwRouterState, GoRouter> createElement() {
//     return _DwRouterStateProviderElement(this);
//   }

//   @override
//   bool operator ==(Object other) {
//     return other is DwRouterStateProvider && other.config == config;
//   }

//   @override
//   int get hashCode {
//     var hash = _SystemHash.combine(0, runtimeType.hashCode);
//     hash = _SystemHash.combine(hash, config.hashCode);

//     return _SystemHash.finish(hash);
//   }
// }

// @Deprecated('Will be removed in 3.0. Use Ref instead')
// // ignore: unused_element
// mixin DwRouterStateRef on AutoDisposeNotifierProviderRef<GoRouter> {
//   /// The parameter `config` of this provider.
//   DwRouterConfig get config;
// }

// class _DwRouterStateProviderElement
//     extends AutoDisposeNotifierProviderElement<DwRouterState, GoRouter>
//     with DwRouterStateRef {
//   _DwRouterStateProviderElement(super.provider);

//   @override
//   DwRouterConfig get config => (origin as DwRouterStateProvider).config;
// }
// // ignore_for_file: type=lint
// // ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
