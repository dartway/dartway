# DartWay Router

A Flutter package that provides a convenient wrapper around Go Router with easy route configuration and navigation utilities. This package simplifies navigation setup and provides useful widgets for bottom navigation bars and menu items.

## Features

- **🚀 Easy Setup**: Simple configuration with builder pattern
- **🎯 Type-Safe Navigation**: Compile-time route checking with enums
- **📱 Bottom Navigation**: Ready-to-use bottom navigation bar widget
- **🎨 Flexible UI**: Support for Material icons, SVG icons, and custom widgets
- **🔄 State Management**: Built-in Riverpod integration
- **📊 Parameters**: Type-safe navigation parameters with automatic parsing
- **🎭 Transitions**: Multiple page transition options (material, fade, slide)
- **🛠️ Utilities**: Helper extensions and utilities for common navigation tasks
- **🏷️ Badges**: Flexible badge system for notifications and custom indicators

## Getting Started

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  dartway_router: ^0.0.1
  flutter_riverpod: ^2.4.10
```

## Quick Start

### 1. Define Your Routes

Create a router configuration file:


```dart
// Define your navigation parameters as a separate enum
enum AppParams with NavigationParamsMixin<int> {
  userId;
}

final appRouterProvider = dwRouterStateProvider(
  DwRouter.config()
    .addNavigationZones([AppNavigationZone.values])
);

enum AppNavigationZone implements NavigationZoneRoute {
  home(SimpleNavigationRouteDescriptor(page: HomePage())),
  profile(SimpleNavigationRouteDescriptor(page: ProfilePage())),
  messages(SimpleNavigationRouteDescriptor(page: MessagesPage())),
  settings(SimpleNavigationRouteDescriptor(page: SettingsPage())),
  userDetail(ParameterizedNavigationRouteDescriptor(
    page: UserDetailPage(),
    parameter: AppParams.userId,
  ));

  const AppNavigationZone(this.descriptor);

  @override
  final NavigationRouteDescriptor descriptor;

  @override
  String get root => '';
}
```

### 2. Create Your App


```dart
void main() {
  runApp(
    ProviderScope(
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'DartWay Router Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
```

### 3. Create Your Pages

```dart
// Example providers for notifications
final messageCountProvider = StateProvider<int>((ref) => 3);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to DartWay Router!'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.goTo(AppNavigationZone.profile),
              child: const Text('Go to Profile'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => context.pushTo(AppNavigationZone.userDetail,
                  pathParameters: AppParams.userId.set(123)),
              child: const Text('View User Detail'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Toggle message count for demo
                final current = ref.read(messageCountProvider);
                ref.read(messageCountProvider.notifier).state =
                    current > 0 ? 0 : 5;
              },
              child: const Text('Toggle Message Count'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DwBottomNavigationBar(
        menuItems: [
          DwMenuItem.icon(
            route: AppNavigationZone.home,
            displayTitle: 'Home',
            iconData: Icons.home,
            activeIconData: Icons.home_filled,
          ),
          DwMenuItem.icon(
            route: AppNavigationZone.profile,
            displayTitle: 'Profile',
            iconData: Icons.person_outline,
            activeIconData: Icons.person,
          ),
          DwMenuItem.icon(
            route: AppNavigationZone.messages,
            displayTitle: 'Messages',
            iconData: Icons.message_outlined,
            badge: NotificationBadge(
              notificationProvider: messageCountProvider,
              badgeColor: Colors.red,
              textColor: Colors.white,
            ),
          ),
          DwMenuItem.icon(
            route: AppNavigationZone.settings,
            displayTitle: 'Settings',
            iconData: Icons.settings_outlined,
            activeIconData: Icons.settings,
            badge: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

```dart
class UserDetailPage extends ConsumerWidget {
  const UserDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the user ID from navigation parameters
    final userId = ref.watchNavigationParam(AppParams.userId) ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text('User $userId')),
      body: Center(
        child: Text('User Detail for ID: $userId'),
      ),
    );
  }
}
```

### 4. Add Navigation

```dart
// Navigate to a route
context.goTo(AppNavigationZone.profile);

// Navigate with parameters using type-safe parameter setting
context.pushTo(AppNavigationZone.userDetail,
    pathParameters: AppParams.userId.set(123));

// Check current route
if (context.isCurrent(AppNavigationZone.home)) {
  // Do something
}
```

## Advanced Usage

### Using the Builder Pattern

```dart
final router = DwRouter.config()
  .addNavigationZones([AppNavigationZone.values])
  .setNotFoundPage(const NotFoundPage())
  .setPageFactory(DwPageBuilders.fade)
  .build();

// Or with Riverpod
final appRouterProvider = dwRouterStateProvider(
  DwRouter.config()
    .addNavigationZones([AppNavigationZone.values])
    .setNotFoundPage(const NotFoundPage())
    .setPageFactory(DwPageBuilders.fade)
);
```

### Type-Safe Parameters

```dart
// In your widget
final userId = ref.watchNavigationParam(AppParams.userId) ?? 0;

// Navigate with parameters using type-safe parameter setting
context.pushTo(AppNavigationZone.userDetail,
    pathParameters: AppParams.userId.set(123));
```

### Badges and Notifications

```dart
// Custom badge
DwMenuItem.icon(
  route: AppNavigationZone.settings,
  displayTitle: 'Settings',
  iconData: Icons.settings,
  badge: Container(
    width: 8,
    height: 8,
    decoration: const BoxDecoration(
      color: Colors.green,
      shape: BoxShape.circle,
    ),
  ),
)

// Notification badge using NotificationBadge widget
DwMenuItem.icon(
  route: AppNavigationZone.messages,
  displayTitle: 'Messages',
  iconData: Icons.message,
  badge: NotificationBadge(
    notificationProvider: messageCountProvider,
    badgeColor: Colors.red,
    textColor: Colors.white,
  ),
)
```

### Custom Page Transitions

```dart
// Use built-in transitions
DwRouter.config()
  .setPageFactory(DwPageBuilders.slide)
  .build();

// Or create your own
Page<dynamic> customPageFactory(BuildContext context, LocalKey key, Widget child) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(scale: animation, child: child);
    },
  );
}
```

## Project Structure

The recommended project structure for a DartWay Router app:

```
lib/
├── main.dart
├── router/
│   ├── app_router.dart          # Main router configuration
│   └── zones/
│       └── app_routes.dart      # Route definitions
├── pages/
│   ├── home_page.dart
│   ├── profile_page.dart
│   ├── settings_page.dart
│   └── user_detail_page.dart
└── widgets/
    └── custom_widgets.dart
```

## API Reference

### Core Classes

- **`DwRouter`**: Core router configuration
- **`DwRouterConfig`**: Builder pattern for router setup
- **`DwBottomNavigationBar`**: Bottom navigation widget
- **`DwMenuItem`**: Menu item configuration

### Utilities

- **`DwNavigationUtils`**: Static navigation utilities
- **`NavigationParamsMixin`**: Type-safe parameter handling
- **`DwNavigationContext`**: BuildContext extensions
- **`NotificationBadge`**: Reusable notification badge widget

## Examples

Check out the `/example` folder for complete working examples.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.
