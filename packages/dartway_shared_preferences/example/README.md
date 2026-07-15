# Example — a reactive preference

Declare the plugin once:

```dart
DwCore(plugins: [DwSharedPreferencesPlugin()]);
```

Then a stored value is a provider the UI watches like any other:

```dart
final darkModeProvider = dw.plugins.prefs.provider<bool>(
  key: 'darkMode',
  defaultValue: false,
);

class DarkModeSwitch extends ConsumerWidget {
  const DarkModeSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(darkModeProvider);
    return Switch(
      value: darkMode,
      onChanged: (value) =>
          ref.read(darkModeProvider.notifier).update(value),
    );
  }
}
```

The switch reflects storage and writes to it; no manual read/write, no reload. For a value that
isn't a primitive, `mappedProvider` maps it to and from a `String`; for a one-off read, reach the
underlying store with `dw.plugins.prefs.raw`.
