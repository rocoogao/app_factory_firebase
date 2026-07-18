## 0.0.4

- Migrated all package Provider declarations to `riverpod_generator` while
  preserving the existing provider names, lifecycles, and override API.

## 0.0.3

- Added `go_router` screen tracking with named-route and `StatefulShellRoute` support.
- Added shared screen context for `click_element` and `view_pop` events.
- Added resolver metadata, query-aware deduplication, popup exclusion, and router lifecycle handling.
- Added screen-name validation and an explicit `unknown` fallback for interactions without context.
- Added fail-open screen tracking issue reporting with app-overridable sinks and session deduplication.
- Added explicit tracked, ignored, and unmapped route resolution results.
- Made interaction uploads fail-open and report `interactionEventFailure` issues.
- Made performance trace startup fail-open so telemetry failures cannot skip business actions.
- Isolated asynchronous Crashlytics failures from the global Flutter and Dart error handlers.
- Made Analytics and Crashlytics identity synchronization fail-open.
- Assigned invalid tracked screen names to `AppScreenTracker` instead of resolver failures.
- Normalized screen-name whitespace when generating GoRouter tracking fingerprints.
- Preserved local Flutter error presentation in debug and profile builds.
- Documented Firebase automatic screen-reporting configuration and tracked `UnmappedRoute` fallbacks.
- Moved package documentation to the conventional `doc/` directory.

## 0.0.2

- Added `screenClass` and custom `parameters` support to `AppAnalytics.logScreenView`.
- Updated `FakeAppAnalytics` screen view records to include screen class and parameters.

## 0.0.1

Initial release.

- Added Riverpod-native Firebase bootstrap helpers.
- Added configurable Analytics, Crashlytics, and Performance collection setup.
- Added release-only collection defaults with explicit per-service overrides.
- Added non-fatal initialization result reporting.
- Added Flutter and Dart error capture through Crashlytics.
- Added Analytics event logging, screen tracking, user properties, context properties, and parameter sanitization.
- Added Performance tracing helpers with attributes and metrics.
- Added Firebase Performance Dio interceptor helper.
- Added telemetry identity synchronization for Analytics and Crashlytics.
- Added fake Analytics, CrashReporter, and PerformanceTracer implementations for tests.
