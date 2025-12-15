// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../dartway_serverpod_core_flutter.dart';

// /// A transitional scope that smooths out rebuilds when the signed-in user changes.
// ///
// /// Prevents UI flickering or null access errors during sign-out/sign-in flow
// /// by introducing a short loading delay when the user profile updates.
// ///
// /// [skipOnSignIn] — disables loading animation when a user signs in
// /// (useful if profile data is already instantly available).
// class DwSignedInUserScope<UserProfileClass extends SerializableModel>
//     extends ConsumerStatefulWidget {
//   final Widget child;
//   final Widget profileLoadingWidget;
//   final StateProvider<UserProfileClass?> userProfileProvider;

//   /// If true, loading animation will not be shown on sign-in.
//   final bool skipOnSignIn;

//   const DwSignedInUserScope({
//     super.key,
//     required this.child,
//     required this.userProfileProvider,
//     this.profileLoadingWidget = const Center(
//       child: CircularProgressIndicator(),
//     ),
//     this.skipOnSignIn = true,
//   });

//   @override
//   ConsumerState<DwSignedInUserScope<UserProfileClass>> createState() =>
//       _DwSignedInUserScopeState<UserProfileClass>();
// }

// class _DwSignedInUserScopeState<UserProfileClass extends SerializableModel>
//     extends ConsumerState<DwSignedInUserScope<UserProfileClass>> {
//   int? _currentUserId;
//   bool _isLoading = false;
//   bool _delayed = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadProfile(ref.read(DwCore.instance.sessionProvider!).signedInUserId);
//   }

//   void _loadProfile(int? newUserId, {bool skipDelay = false}) {
//     if (_isLoading) return;

//     final prevUserId = _currentUserId;
//     final isSignIn = prevUserId == null && newUserId != null;

//     // Skip transition when signing in and skipOnSignIn = true
//     if (widget.skipOnSignIn && isSignIn) {
//       _currentUserId = newUserId;
//       _updateProfileState();
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//       _delayed = true;
//       _currentUserId = newUserId;
//     });

//     // Small artificial delay to smooth UI transition
//     if (!skipDelay) {
//       unawaited(
//         Future.delayed(const Duration(milliseconds: 200)).then((_) {
//           if (mounted) setState(() => _delayed = false);
//         }),
//       );
//     }
//   }

//   void _updateProfileState() {
//     // Delay provider update to avoid "modifying provider during build"
//     Future.microtask(() {
//       if (!mounted) return;
//       ref.read(widget.userProfileProvider.notifier).state =
//           ref.read(DwCore.instance.sessionProvider!).signedInUserProfile
//               as UserProfileClass?;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     // React to changes in session (user ID)
//     ref.listen(DwCore.instance.sessionProvider!, (prev, next) {
//       final prevId = prev?.signedInUserId;
//       final nextId = next.signedInUserId;
//       if (prevId != nextId) _loadProfile(nextId);
//     });

//     // Sync profile state after user ID change
//     if (_isLoading) {
//       WidgetsBinding.instance.addPostFrameCallback((_) async {
//         _updateProfileState();
//         await Future.delayed(const Duration(milliseconds: 200));
//         if (mounted) setState(() => _isLoading = false);
//       });
//     }

//     // Display loading spinner during transition, otherwise show content
//     return AnimatedSwitcher(
//       duration: const Duration(milliseconds: 300),
//       switchInCurve: Curves.easeOut,
//       switchOutCurve: Curves.easeIn,
//       child:
//           (_isLoading || _delayed) ? widget.profileLoadingWidget : widget.child,
//     );
//   }
// }
