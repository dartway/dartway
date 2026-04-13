import 'dart:async';

import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/private/dw_singleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

typedef DwAsyncProviderFactory =
    List<ProviderListenable<AsyncValue<dynamic>>> Function(
      WidgetRef ref,
      int? userProfileId,
    );

class DwUserAsyncScope<UserProfileClass extends SerializableModel>
    extends ConsumerStatefulWidget {
  final Widget child;
  final Widget profileLoadingWidget;
  final Function(UserProfileClass? userProfile) whenProfileReadyCallback;
  final Function(bool isLoading)? profileLoadingStateCallback;

  /// Function, which returns a list of async providers to subscribe to by `ref` and `userProfileId`.
  final DwAsyncProviderFactory? asyncProviderFactory;

  final FutureOr<void> Function(WidgetRef ref, UserProfileClass? userProfile)?
  postLoadTrigger;

  final bool skipOnSignIn;

  const DwUserAsyncScope({
    super.key,
    required this.child,
    required this.whenProfileReadyCallback,
    this.profileLoadingStateCallback,
    this.profileLoadingWidget = const Center(
      child: CircularProgressIndicator(),
    ),
    this.asyncProviderFactory,
    this.postLoadTrigger,
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
  bool _loadingCallbackScheduled = false;
  int? _postLoadTriggeredLastTimeForUserId;

  final List<ProviderSubscription<AsyncValue<dynamic>>> _subscriptions = [];
  final Map<ProviderSubscription<AsyncValue<dynamic>>, bool>
  _subscriptionLoadingStates = {};

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
    _subscriptionLoadingStates.clear();
    _setAsyncLoading(false);

    if (widget.asyncProviderFactory == null) return;

    final providers = widget.asyncProviderFactory!(ref, userProfileId);
    for (final provider in providers) {
      late final ProviderSubscription<AsyncValue<dynamic>> sub;
      sub = ref.listenManual(provider, (_, next) {
        _subscriptionLoadingStates[sub] = next.isLoading;
        _syncAsyncLoadingState();
      });
      _subscriptions.add(sub);
    }
  }

  void _loadProfile(int? newUserId, {bool skipDelay = false}) {
    if (_isLoading) return;

    _updateProfileLoadingState(true);

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

  void _updateProfileState({bool withPostLoadTrigger = true}) {
    Future.microtask(() {
      if (!mounted) return;

      final profile =
          ref.read(dw.sessionProvider!).signedInUserProfile
              as UserProfileClass?;

      widget.whenProfileReadyCallback(profile);
      _updateProfileLoadingState(false);

      if (withPostLoadTrigger && widget.postLoadTrigger != null) {
        if (_postLoadTriggeredLastTimeForUserId != _currentUserId) {
          _postLoadTriggeredLastTimeForUserId = _currentUserId;
          final result = widget.postLoadTrigger!(ref, profile);
          if (result is Future<void>) {
            unawaited(result);
          }
        }
      }
    });
  }

  void _updateProfileLoadingState(bool isLoading) {
    Future.microtask(() {
      if (!mounted) return;
      widget.profileLoadingStateCallback?.call(isLoading);
    });
  }

  void _syncAsyncLoadingState() {
    _setAsyncLoading(_subscriptionLoadingStates.values.any((e) => e));
  }

  void _setAsyncLoading(bool isLoading) {
    if (_isAsyncLoading == isLoading) return;
    setState(() => _isAsyncLoading = isLoading);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dw.sessionProvider!, (prev, next) {
      final prevId = prev?.signedInUserId;
      final nextId = next.signedInUserId;
      if (prevId != nextId) {
        _loadProfile(nextId);
      } else {
        _updateProfileState(withPostLoadTrigger: false);
      }
    });

    if (_isLoading && !_loadingCallbackScheduled) {
      _loadingCallbackScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _updateProfileState();
        await Future.delayed(const Duration(milliseconds: 200));
        _loadingCallbackScheduled = false;
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
