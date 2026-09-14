import 'package:dartway_example_flutter/auth/profile_name_page.dart';
import 'package:dartway_example_flutter/shared/widgets/app_scaffold.dart';
import 'package:dartway_example_flutter/shared/widgets/load_failed_message.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../dw_core.dart';
import 'my_profile.dart';

/// Lets the app through once the signed-in user's profile is loaded and
/// complete, and hands it down as [SignedInProfile].
///
/// Signed in, the app is not built until the profile arrives: a screen reads
/// `context.profile` and never handles a loading state of its own. A profile
/// without a name — an account created by signing in with a phone that had
/// none — is asked for it first, whichever way the account came about.
///
/// Signed out, [child] is the auth zone. The last profile is still handed down
/// for the screen that is animating away after a sign-out: it was built
/// signed in and must not break in its last frames.
class SignedInGate extends HookConsumerWidget {
  const SignedInGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountId = ref.watch(dw.accountId);
    final profile = ref.watch(myProfileProvider);

    // The last profile let through, with the account it belongs to. Kept over
    // a failed refetch — the app does not vanish because a reconnect's re-run
    // failed — and dropped as soon as a different account signs in.
    final shown = useRef<({int accountId, UserProfile profile})?>(null);
    if (accountId != null) {
      if (profile.value case final loaded?) {
        shown.value = (accountId: accountId, profile: loaded);
      } else if (shown.value?.accountId != accountId) {
        shown.value = null;
      }
    }
    final current = shown.value;

    if (accountId == null) {
      return SignedInProfile(profile: current?.profile, child: child);
    }
    if (current == null) {
      return AppScaffold.inner(
        body: profile.isLoading
            ? const Center(child: CircularProgressIndicator())
            : LoadFailedMessage(
                onRetry: dw.action(
                  (_) => ref
                      .read(
                        dw.request(GetMyProfile(accountId: accountId)).notifier,
                      )
                      .refetch(),
                ),
              ),
      );
    }
    if (current.profile.firstName.isEmpty) return const ProfileNamePage();
    return SignedInProfile(profile: current.profile, child: child);
  }
}
