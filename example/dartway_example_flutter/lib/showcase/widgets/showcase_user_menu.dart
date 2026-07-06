import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_flutter/core/user_profile_provider.dart';
import 'package:dartway_example_flutter/showcase/logic/showcase_persona.dart';
import 'package:dartway_example_flutter/showcase/logic/showcase_user_switcher.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// Persona switcher: signs in as a seeded demo user through the regular OTP
/// flow with the fixed dev code — the cheapest way to demo role-based UI.
class ShowcaseUserMenu extends ConsumerWidget {
  const ShowcaseUserMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final isBusy = ref.watch(showcaseUserSwitcherProvider);
    final switcher = ref.read(showcaseUserSwitcherProvider.notifier);

    return PopupMenuButton<ShowcasePersona?>(
      enabled: !isBusy,
      tooltip: 'Switch demo user',
      onSelected: (persona) => persona == null
          ? switcher.signOutCurrentUser()
          : switcher.switchTo(persona),
      itemBuilder: (context) => [
        for (final persona in ShowcasePersona.values)
          PopupMenuItem(
            value: persona,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: profile?.phone == persona.phone
                      ? const Icon(Icons.check, size: 16)
                      : null,
                ),
                Text(persona.displayLabel),
              ],
            ),
          ),
        if (profile != null) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(value: null, child: Text('Sign out')),
        ],
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ShowcaseChrome.chipColor,
          borderRadius: ShowcaseChrome.chipRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ShowcaseChrome.accentColor,
                ),
              )
            else
              const Icon(
                Icons.person_outline,
                size: 16,
                color: ShowcaseChrome.accentColor,
              ),
            const SizedBox(width: 8),
            Text(
              profile?.firstName ?? 'Signed out',
              style: ShowcaseChrome.chipLabel,
            ),
            const Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: ShowcaseChrome.mutedColor,
            ),
          ],
        ),
      ),
    );
  }
}
