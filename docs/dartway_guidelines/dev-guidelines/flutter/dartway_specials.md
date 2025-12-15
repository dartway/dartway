---
description: Rules for using UI Kit in DartWay Flutter projects
globs:
alwaysApply: true
---

# DartWay Specials

## Notifications

❌ Do not use ScaffoldMessenger, SnackBar, or any custom popups directly.

✅ Use DartWay built-in notification system:

```dart
dw.notify.success('Profile updated!');
dw.notify.warning('Data provided is not fully correct');
dw.notify.error('Failed to save changes');
dw.notify.info('Loading...');
```

This ensures a unified UI and centralized control over messages.

---

## User Profile Access

The current user profile has dedicated providers. Do not fetch it via generic CRUD watchers.

❌ Wrong:

```dart
final userProfile = ref.watchModel<UserProfile>();
```

✅ Correct:

```dart
final userProfile = ref.watchUserProfile();
final userProfile = ref.readUserProfile();
```

Why:
- UserProfile has its own provider and helpers.
- No CRUD config is required.
- Cleaner, simpler, and safer for frequent usage.

---

## DwCallback Wrapping

All actions triggered from UI (buttons, gestures, menu items) must be wrapped into DwCallback.create.

❌ Wrong:

```dart
onPressed: () => saveChanges(),
```

✅ Correct:

```dart
onPressed: DwCallback.create(saveChanges),
```

This ensures unified error handling, loading states, and consistent UX across the app.

## Sign Out

Always use the built-in ref.signOut method. If you need to log out from all sessions, explicitly pass the parameter.

✅ Example:
```dart
// Sign out only from current device
await ref.signOut();

// Sign out from all devices
await ref.signOut(allDevices: true);
```