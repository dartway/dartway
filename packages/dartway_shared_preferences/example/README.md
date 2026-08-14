# Example — a reactive preference

Declare the plugin once:

```dart
DwFlutter(
  config: DwConfig(/* ... */),
  plugins: [DwSharedPreferences()],
);
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

## A value per entity

`darkMode` is one setting for the whole app. A sort order belongs to *this* project, so the key has
to carry its id — that is `providerFamily`, and the family (not the provider it returns) is the
top-level `final`:

```dart
final projectSortProvider = dw.plugins.prefs.providerFamily<String, int>(
  keyFor: (projectId) => 'project.$projectId.sort',
  defaultValue: 'name',
);

class ProjectSortButton extends ConsumerWidget {
  const ProjectSortButton({required this.projectId, super.key});

  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(projectSortProvider(projectId));
    return DropdownButton<String>(
      value: sort,
      items: const [
        DropdownMenuItem(value: 'name', child: Text('Name')),
        DropdownMenuItem(value: 'createdAt', child: Text('Newest')),
      ],
      onChanged: (value) => value == null
          ? null
          : ref.read(projectSortProvider(projectId).notifier).update(value),
    );
  }
}
```

Riverpod holds one provider per argument value, so anything else on the screen that watches
`projectSortProvider(projectId)` — the list itself, a "reset" button in another panel — rebuilds on
that write, and a different project keeps its own stored order. Calling `provider` per id instead
would give each of those readers a provider of its own, blind to the others' writes.

For an enum or a custom type, `mappedProviderFamily(keyFor:, mapFrom:, mapTo:)`.
