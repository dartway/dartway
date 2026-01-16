# DartWay Router

A powerful, type-safe navigation package for Flutter that wraps Go Router with an intuitive enum-based API. Build navigation systems with compile-time safety, route guards, and flexible page transitions.

## Features

- **🎯 Type-Safe Navigation**: Enum-based routes with compile-time checking
- **🔄 State Management Agnostic**: Works with any `Listenable` (ChangeNotifier, ValueNotifier, Riverpod, etc.)
- **🛡️ Route Guards**: Protect routes with authentication/authorization guards
- **📊 Type-Safe Parameters**: Extract navigation parameters with full type safety
- **🎭 Flexible Transitions**: Built-in page transitions (material, fade, slide, scale)
- **🏗️ Navigation Zones**: Group routes into logical zones (authenticated, public, admin, etc.)
- **🐚 Shell Routes**: Easy shell route configuration for common UI patterns
- **✅ Comprehensive Validation**: Automatic validation of route configuration
- **📱 Zero Dependencies**: Only depends on Flutter and Go Router

## Installation

```bash
flutter pub add dartway_router
```

## Quick Start

### 1. Define Your Router State

Create a state class that extends `Listenable` (or use `ChangeNotifier`, `ValueNotifier`, etc.):

```dart
import 'package:flutter/material.dart';

class AppSession extends ChangeNotifier {
  bool _isAuthenticated = false;
  
  bool get isAuthenticated => _isAuthenticated;
  
  void login() {
    _isAuthenticated = true;
    notifyListeners();
  }
  
  void logout() {
    _isAuthenticated = false;
    notifyListeners();
  }
}
```

### 2. Define Navigation Parameters

Create an enum for your navigation parameters:

```dart
enum AppParams<T> with DwNavigationParamsMixin<T> {
  userId<int>(),
  userName<String>(),
  itemId<int>(),
}
```

### 3. Define Your Routes

Create route enums that implement `DwNavigationRoute`:

```dart
import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';

enum AppRoutes implements DwNavigationRoute<AppSession> {
  // Zone root route (entry point of the zone)
  home(
    DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage()),
  ),
  
  // Simple route without parameters
  profile(
    DwNavigationRouteDescriptor.simple(pageWidget: ProfilePage()),
  ),
  
  // Parameterized route with a path parameter
  userDetail(
    DwNavigationRouteDescriptor.parameterized(
      pageWidget: UserDetailPage(),
      parameter: AppParams.userId,
      parent: home,
      extraPathSegment: 'users', // Optional: adds 'users' prefix
    ),
  );

  const AppRoutes(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<AppSession> descriptor;

  @override
  String get zoneRoot => '';

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  List<DwNavigationGuard<AppSession>> get zoneGuards => [];
}
```

### 4. Create the Router

```dart
final appSession = AppSession();

final router = DwRouter<AppSession>(
  routerState: appSession,
  navigationZones: [
    AppRoutes.values,
  ],
  pageBuilder: DwPageBuilder.material,
  options: DwGoRouterOptions(
    initialLocation: AppRoutes.home.fullPath,
    debugLogDiagnostics: true,
  ),
);
```

### 5. Use in Your App

```dart
import 'package:flutter/material.dart';
import 'router/app_router.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DartWay Router Example',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      routerConfig: router.router,
    );
  }
}
```

### 6. Navigate and Extract Parameters

```dart
// Navigate to a route
context.goNamed(AppRoutes.profile.name);

// Navigate with parameters
context.goNamed(
  AppRoutes.userDetail.name,
  pathParameters: AppParams.userId.set(123),
);

// Extract parameters in a widget
class UserDetailPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userId = AppParams.userId.fromPath(context);
    return Text('User ID: $userId');
  }
}
```

## Core Concepts

### Navigation Zones

Navigation zones allow you to group related routes together. Each zone can have:
- A shared shell route builder (e.g., bottom navigation bar)
- Common route guards (e.g., authentication checks)
- A zone root route

Example with multiple zones:

```dart
final router = DwRouter<AppSession>(
  routerState: appSession,
  navigationZones: [
    AppRoutes.values,      // Authenticated zone
    AuthRoutes.values,      // Public/auth zone
    AdminRoutes.values,     // Admin zone
  ],
  pageBuilder: DwPageBuilder.material,
);
```

### Route Types

#### Zone Root Route

The entry point of a navigation zone. Contributes an empty path segment.

```dart
home(
  DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage()),
)
```

Accessible at `/` (assuming `zoneRoot` is empty).

#### Simple Route

A route without parameters. Contributes its enum name as the path.

```dart
profile(
  DwNavigationRouteDescriptor.simple(pageWidget: ProfilePage()),
)
```

Accessible at `/profile`.

#### Parameterized Route

A route with path parameters. Must have a parent route.

```dart
userDetail(
  DwNavigationRouteDescriptor.parameterized(
    pageWidget: UserDetailPage(),
    parameter: AppParams.userId,
    parent: home,
  ),
)
```

Accessible at `/:userId` (relative to parent).

With `extraPathSegment`:

```dart
userDetail(
  DwNavigationRouteDescriptor.parameterized(
    pageWidget: UserDetailPage(),
    parameter: AppParams.userId,
    parent: home,
    extraPathSegment: 'users',
  ),
)
```

Accessible at `/users/:userId`.

### Route Guards

Guards allow you to protect routes with authentication or authorization checks. Guards are executed in order, and if any guard returns a redirect path, navigation is redirected.

```dart
enum AppRoutes implements DwNavigationRoute<AppSession> {
  // ... routes ...

  @override
  List<DwNavigationGuard<AppSession>> get zoneGuards => [
    (session) {
      if (!session.isAuthenticated) {
        return AuthRoutes.login.fullPath;
      }
      return null; // Allow navigation
    },
  ];
}
```

**Important**: When using guards, you must provide `routerState` to `DwRouter`:

```dart
final router = DwRouter<AppSession>(
  routerState: appSession, // Required when using guards
  navigationZones: [AppRoutes.values],
  pageBuilder: DwPageBuilder.material,
);
```

### Shell Routes

Shell routes allow you to wrap routes in a common UI shell, such as a scaffold with a bottom navigation bar.

```dart
enum AppRoutes implements DwNavigationRoute<AppSession> {
  // ... routes ...

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder =>
      (context, state, child) {
        final currentRoot = router.rootRouteFromState(state);
        final currentIndex = currentRoot == AppRoutes.profile ? 1 : 0;

        return MaterialPage(
          child: Scaffold(
            body: child,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (index) {
                switch (index) {
                  case 0:
                    context.goNamed(AppRoutes.home.name);
                    break;
                  case 1:
                    context.goNamed(AppRoutes.profile.name);
                    break;
                }
              },
              items: [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
              ],
            ),
          ),
        );
      };
}
```

### Type-Safe Parameters

Navigation parameters are defined using enums with `DwNavigationParamsMixin`:

```dart
enum AppParams<T> with DwNavigationParamsMixin<T> {
  userId<int>(),
  userName<String>(),
  price<double>(),
  isActive<bool>(),
}
```

#### Extracting Parameters

```dart
// From path parameters (required)
final userId = AppParams.userId.fromPath(context);

// From path parameters (nullable)
final userId = AppParams.userId.fromPathOrNull(context);

// From query parameters (nullable)
final searchQuery = AppParams.userName.fromQueryOrNull(context);

// From query parameters (required)
final searchQuery = AppParams.userName.fromQuery(context);

// From extra data (nullable)
final data = AppParams.userId.fromExtra(context);
```

#### Setting Parameters for Navigation

```dart
// Navigate with path parameter
context.goNamed(
  AppRoutes.userDetail.name,
  pathParameters: AppParams.userId.set(123),
);

// Navigate with query parameter
context.go(
  '/search?${AppParams.userName.set('flutter').entries.first.key}=${AppParams.userName.set('flutter').entries.first.value}',
);
```

### Page Transitions

Choose from built-in transitions or create custom ones:

```dart
// Material (no transition)
pageBuilder: DwPageBuilder.material

// Fade transition
pageBuilder: DwPageBuilder.fade

// Slide transition (from right by default)
pageBuilder: DwPageBuilder.slide

// Slide from bottom
pageBuilder: (context, key, child) =>
    DwPageBuilder.slide(context, key, child, from: AxisDirection.bottom)

// Scale transition
pageBuilder: DwPageBuilder.scale

// Custom transition
pageBuilder: (context, key, child) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: Duration(milliseconds: 500),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return RotationTransition(
        turns: animation,
        child: child,
      );
    },
  );
}
```

## Advanced Usage

### Multiple Navigation Zones

Organize your app into multiple navigation zones:

```dart
enum AppRoutes implements DwNavigationRoute<AppSession> {
  home(DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage())),
  profile(DwNavigationRouteDescriptor.simple(pageWidget: ProfilePage()));
  
  // ... implementation ...
}

enum AuthRoutes implements DwNavigationRoute<AppSession> {
  login(DwNavigationRouteDescriptor.simple(pageWidget: LoginPage())),
  signup(DwNavigationRouteDescriptor.simple(pageWidget: SignupPage()));
  
  // ... implementation ...
}

final router = DwRouter<AppSession>(
  routerState: appSession,
  navigationZones: [
    AppRoutes.values,   // Authenticated zone
    AuthRoutes.values,  // Public zone
  ],
  pageBuilder: DwPageBuilder.material,
);
```

### Nested Routes

Create nested route hierarchies:

```dart
enum AppRoutes implements DwNavigationRoute<AppSession> {
  home(DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage())),
  
  // Child route
  settings(
    DwNavigationRouteDescriptor.simple(
      pageWidget: SettingsPage(),
      parent: home,
    ),
  ),
  
  // Nested child route
  profileSettings(
    DwNavigationRouteDescriptor.simple(
      pageWidget: ProfileSettingsPage(),
      parent: settings,
    ),
  ),
}
```

### Route Paths

Understanding route paths:

- **`routePath`**: The path segment for this route
  - Root routes: Full path from zone root (e.g., `/profile`)
  - Child routes: Relative path segment only (e.g., `:userId`)

- **`fullPath`**: The complete path from root
  - Always includes the full hierarchy (e.g., `/users/:userId`)

```dart
// For a child route with parent
print(AppRoutes.userDetail.routePath);  // ':userId'
print(AppRoutes.userDetail.fullPath);   // '/:userId' (includes parent)
```

### Route Resolution

Get the current route from navigation state:

```dart
// Get the top route (the route at the top of the stack)
final topRoute = router.topRouteFromState(GoRouterState.of(context));

// Get the root route (the zone root)
final rootRoute = router.rootRouteFromState(GoRouterState.of(context));

// Check if a route is active
if (AppRoutes.profile.isActive(context)) {
  // Route is currently active
}
```

### Custom Router Options

Configure GoRouter behavior:

```dart
final router = DwRouter<AppSession>(
  routerState: appSession,
  navigationZones: [AppRoutes.values],
  pageBuilder: DwPageBuilder.material,
  options: DwGoRouterOptions(
    initialLocation: '/home',
    debugLogDiagnostics: true,
    redirectLimit: 10,
    errorBuilder: (context, state) => ErrorPage(),
    redirect: (context, state) {
      // Custom redirect logic
      return null;
    },
  ),
);
```

## API Reference

### Core Classes

#### `DwRouter<RouterState>`

Main router class that wraps GoRouter.

**Properties:**
- `routerState` - Optional router state for refresh notifications
- `navigationZones` - List of navigation zone route lists
- `pageBuilder` - Function to build pages with transitions
- `options` - GoRouter configuration options
- `router` - The underlying GoRouter instance

**Methods:**
- `topRouteFromState(state)` - Get top route from navigation state
- `rootRouteFromState(state)` - Get root route from navigation state

#### `DwNavigationRoute<RouterState>`

Abstract interface for navigation routes. Routes are defined as enums implementing this interface.

**Required Properties:**
- `descriptor` - Route descriptor defining path and page
- `zoneRoot` - Root path segment for the navigation zone
- `shellRouteBuilder` - Optional shell route builder
- `zoneGuards` - List of navigation guards

#### `DwNavigationRouteDescriptor<RouterState>`

Describes how a route contributes to the URL path.

**Factory Constructors:**
- `zoneRoot({required pageWidget})` - Zone root route
- `simple({required pageWidget, parent, extraPathSegment})` - Simple route
- `parameterized({required pageWidget, required parameter, required parent, extraPathSegment})` - Parameterized route

#### `DwNavigationParamsMixin<T>`

Mixin for type-safe navigation parameters.

**Methods:**
- `set(value)` - Create parameter map for navigation
- `fromPath(context)` - Extract from path parameters (required)
- `fromPathOrNull(context)` - Extract from path parameters (nullable)
- `fromQuery(context)` - Extract from query parameters (required)
- `fromQueryOrNull(context)` - Extract from query parameters (nullable)
- `fromExtra(context)` - Extract from extra data (nullable)

#### `DwPageBuilder`

Collection of predefined page builders.

**Static Methods:**
- `material(context, key, child)` - Material page (no transition)
- `fade(context, key, child, {curve, duration})` - Fade transition
- `slide(context, key, child, {from, curve, duration})` - Slide transition
- `scale(context, key, child, {curve, duration})` - Scale transition

#### `DwGoRouterOptions`

Configuration options for GoRouter.

**Properties:**
- `navigatorKey` - Navigator key
- `initialLocation` - Initial route path
- `errorBuilder` - Custom error page builder
- `redirect` - Custom redirect function
- `debugLogDiagnostics` - Enable debug logging
- And more...

### Extensions

#### `DwNavigationRouteExtension`

Extension on `DwNavigationRoute` providing:

- `routePath` - Route path (relative for child routes)
- `fullPath` - Full path from root
- `isActive(context)` - Check if route is currently active

## Examples

Complete working examples are available in the `/examples` directory:

- **change_notifier_example** - Example using ChangeNotifier for state management
- **riverpod_example** - Example using Riverpod for state management

## Project Structure

Recommended project structure:

```
lib/
├── main.dart
├── router/
│   ├── app_router.dart          # Router configuration
│   └── zones/
│       ├── app_routes.dart      # App routes enum
│       └── auth_routes.dart     # Auth routes enum
├── pages/
│   ├── home_page.dart
│   ├── profile_page.dart
│   └── user_detail_page.dart
└── core/
    └── app_session.dart         # Router state (ChangeNotifier, etc.)
```

## Best Practices

1. **Use enums for routes**: Provides compile-time safety and autocomplete
2. **Group related routes**: Use navigation zones to organize routes logically
3. **Use guards for protection**: Protect routes with guards rather than checking in widgets
4. **Type-safe parameters**: Always use `DwNavigationParamsMixin` for parameters
5. **Consistent naming**: Use consistent naming conventions for routes and parameters
6. **Shell routes for common UI**: Use shell routes for bottom nav, sidebars, etc.

## Troubleshooting

### Routes not found

- Ensure all routes are included in `navigationZones`
- Check that route names are unique
- Verify that paths don't conflict

### Guards not working

- Ensure `routerState` is provided to `DwRouter`
- Check that guards return `null` to allow navigation
- Verify guard logic is correct

### Parameters not extracted

- Ensure parameter name matches the route path parameter
- Check parameter type matches the mixin type
- Use `fromPathOrNull` if parameter might be missing

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.
