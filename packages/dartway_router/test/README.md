# Tests for dartway_router

This directory contains tests for the dartway_router package.

## Test Structure

- `test_helpers.dart` - Helper functions and mock objects for testing
- `dw_navigation_params_mixin_test.dart` - Tests for navigation parameters handling
- `dw_navigation_route_extension_test.dart` - Tests for route extensions
- `dw_router_test.dart` - Tests for the main DwRouter class
- `dw_page_builder_test.dart` - Tests for page builders
- `dw_navigation_route_descriptor_test.dart` - Tests for route descriptors

## Running Tests

```bash
flutter test
```

or

```bash
dart test
```

## Test Coverage

Tests cover:
- ✅ Router configuration validation
- ✅ Navigation parameters handling (path, query, extra)
- ✅ Route path computation
- ✅ Page building with transitions
- ✅ Guards and redirects functionality
- ✅ Route descriptor creation
