import 'dart:async';

import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/private/dw_singleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef DwAsyncProviderFactory =
    List<ProviderListenable<AsyncValue>> Function(
      WidgetRef ref,
      int? userProfileId,
    );

class DwUserAsyncScope<UserProfileClass extends SerializableModel>
    extends ConsumerStatefulWidget {
  final Widget child;
  final Widget profileLoadingWidget;
  final StateProvider<UserProfileClass?> userProfileProvider;

  /// Function, which returns a list of async providers to subscribe to by `ref` and `userProfileId`.
  final DwAsyncProviderFactory? asyncProviderFactory;

  final bool skipOnSignIn;

  const DwUserAsyncScope({
    super.key,
    required this.child,
    required this.userProfileProvider,
    this.profileLoadingWidget = const Center(
      child: CircularProgressIndicator(),
    ),
    this.asyncProviderFactory,
    this.skipOnSignIn = true,
  });

  @override
  ConsumerState<DwUserAsyncScope<UserProfileClass>> createState() =>
      _DwSignedInUserScopeState<UserProfileClass>();
}

class _DwSignedInUserScopeState<UserProfileClass extends SerializableModel>
    extends ConsumerState<DwUserAsyncScope<UserProfileClass>> {
  int? _currentUserId;
  bool _isLoading = false;
  bool _delayed = false;
  bool _isAsyncLoading = false;

  final List<ProviderSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    final userId = ref.read(dw.sessionProvider!).signedInUserId;
    _loadProfile(userId);
    _attachAsyncListeners(userId);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.close();
    }
    super.dispose();
  }

  void _attachAsyncListeners(int? userProfileId) {
    for (final sub in _subscriptions) {
      sub.close();
    }
    _subscriptions.clear();

    if (widget.asyncProviderFactory == null) return;

    final providers = widget.asyncProviderFactory!(ref, userProfileId);
    for (final provider in providers) {
      final sub = ref.listenManual(provider, (_, next) {
        final isLoadingNow = next.isLoading;
        if (isLoadingNow != _isAsyncLoading) {
          setState(() => _isAsyncLoading = isLoadingNow);
        }
      });
      _subscriptions.add(sub);
    }
  }

  void _loadProfile(int? newUserId, {bool skipDelay = false}) {
    if (_isLoading) return;

    final prevUserId = _currentUserId;
    final isSignIn = prevUserId == null && newUserId != null;

    if (widget.skipOnSignIn && isSignIn) {
      _currentUserId = newUserId;
      _updateProfileState();
      _attachAsyncListeners(newUserId);
      return;
    }

    setState(() {
      _isLoading = true;
      _delayed = true;
      _currentUserId = newUserId;
    });

    _attachAsyncListeners(newUserId);

    if (!skipDelay) {
      unawaited(
        Future.delayed(const Duration(milliseconds: 200)).then((_) {
          if (mounted) setState(() => _delayed = false);
        }),
      );
    }
  }

  void _updateProfileState() {
    Future.microtask(() {
      if (!mounted) return;
      ref.read(widget.userProfileProvider.notifier).state =
          ref.read(dw.sessionProvider!).signedInUserProfile
              as UserProfileClass?;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dw.sessionProvider!, (prev, next) {
      final prevId = prev?.signedInUserId;
      final nextId = next.signedInUserId;
      if (prevId != nextId) {
        _loadProfile(nextId);
      } else {
        _updateProfileState();
      }
    });

    if (_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _updateProfileState();
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) setState(() => _isLoading = false);
      });
    }

    final showLoader = _isLoading || _delayed || _isAsyncLoading;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: showLoader ? widget.profileLoadingWidget : widget.child,
    );
  }
}
