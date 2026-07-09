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
