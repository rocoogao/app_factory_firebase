# app_factory_firebase

Riverpod-native Firebase bootstrap and telemetry helpers for Flutter apps.

This package keeps Firebase setup in one reusable layer while keeping your app
code dependent on small abstractions instead of directly depending on Firebase
SDK singletons. It is useful for teams that repeatedly build Flutter apps with
Firebase Analytics, Crashlytics, and Performance Monitoring.

## Features

- Firebase initialization from app-provided `FirebaseOptions`
- Configurable Analytics, Crashlytics, and Performance collection switches
- Release-only collection defaults to avoid polluting production dashboards
- Flutter and Dart error capture through Crashlytics
- Analytics event logging, screen tracking, user properties, and context properties
- Firebase-safe Analytics parameter sanitization
- Performance traces with attributes and metrics
- Firebase Performance helper for Dio
- Identity synchronization across Analytics and Crashlytics
- Fake implementations for tests
- Riverpod providers as the single source of truth

## What This Package Does Not Own

Each app still owns its own Firebase project and platform files:

- `firebase_options.dart`
- `google-services.json`
- `GoogleService-Info.plist`
- Firebase Console project setup
- Android and iOS native Firebase plugin configuration
- App-specific analytics event names
- Route naming and screen naming strategy

Do not put an app-specific `firebase_options.dart` file inside this package.
Pass `DefaultFirebaseOptions.currentPlatform` from the app instead.

## Installation

Add the dependency:

```yaml
dependencies:
  app_factory_firebase: ^0.0.1
```

Then run:

```bash
flutter pub get
```

Your app must also be configured for Firebase with the normal FlutterFire setup.
For example, Android still needs `google-services.json` and the Google Services
Gradle plugin, and iOS still needs `GoogleService-Info.plist`.

## Quick Start

Most apps can use `runAppWithFirebase`. It creates a `ProviderContainer`,
injects the Firebase config, initializes Firebase, wraps your app in
`UncontrolledProviderScope`, and calls `runApp`.

```dart
import 'package:app_factory_firebase/app_factory_firebase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  final result = await runAppWithFirebase(
    config: AppFactoryFirebaseConfig(
      options: DefaultFirebaseOptions.currentPlatform,
      enableAnalytics: true,
      enableCrashlytics: true,
      enablePerformance: true,
      captureFlutterErrors: true,
      collectionInReleaseOnly: true,
      defaultEventParameters: {
        'app_id': 'example_app',
        'app_channel': 'production',
      },
      contextProperties: {
        'product_family': 'consumer',
      },
      debugLogInitializeResult: true,
    ),
    child: const App(),
  );

  debugPrint(result.toString());
}
```

`collectionInReleaseOnly` defaults to `true`, which means collection is disabled
in debug builds and enabled in release builds unless overridden.

If your app has additional Riverpod overrides, pass them through:

```dart
await runAppWithFirebase(
  config: AppFactoryFirebaseConfig(
    options: DefaultFirebaseOptions.currentPlatform,
  ),
  overrides: [
    userRepositoryProvider.overrideWithValue(userRepository),
    settingsRepositoryProvider.overrideWithValue(settingsRepository),
  ],
  child: const App(),
);
```

Riverpod 3 does not publicly export the `Override` type from
`flutter_riverpod`, so the `overrides` parameter accepts the provider override
objects directly. Pass values such as `provider.overrideWithValue(...)` or
`provider.overrideWith(...)`.

## Advanced Bootstrap

If your app already owns a custom `ProviderContainer`, initialize Firebase
manually and keep using the same container.

```dart
import 'package:app_factory_firebase/app_factory_firebase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer(
    overrides: [
      appFactoryFirebaseConfigProvider.overrideWithValue(
        AppFactoryFirebaseConfig(
          options: DefaultFirebaseOptions.currentPlatform,
          enableAnalytics: true,
          enableCrashlytics: true,
          enablePerformance: true,
          captureFlutterErrors: true,
          collectionInReleaseOnly: true,
        ),
      ),
    ],
  );

  final result = await AppFactoryFirebase.initialize(container);
  debugPrint(result.toString());

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}
```

`appFactoryFirebaseConfigProvider` intentionally throws if it is not overridden.
This makes missing Firebase configuration fail during startup instead of silently
running without telemetry.

Firebase subsystem failures are treated as non-fatal. They are recorded in
`AppFactoryFirebaseInitializeResult.initializationErrors`, and your app can
continue to run.

## Screen Tracking

Add `firebaseAnalyticsObserverProvider` to your `MaterialApp` or `CupertinoApp`.

```dart
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Example App',
      navigatorObservers: [
        ref.watch(firebaseAnalyticsObserverProvider),
      ],
      home: const HomePage(),
    );
  }
}
```

Firebase screen tracking works best when your routes have meaningful names.
Keep app-specific route and screen naming rules in your app.

## Analytics Events

Keep event names in your app, not in this package:

```dart
class AppEvents {
  const AppEvents._();

  static const String signupComplete = 'signup_complete';
  static const String purchaseStart = 'purchase_start';
}
```

Log events through `appAnalyticsProvider`:

```dart
await ref.read(appAnalyticsProvider).logEvent(
  AppEvents.signupComplete,
  parameters: {
    'source': 'email',
    'has_invite_code': true,
    'created_at': DateTime.now(),
  },
);
```

Analytics parameters are sanitized before reaching Firebase:

- `String`, `int`, and `double` are kept as-is
- `bool` becomes `'true'` or `'false'`
- `DateTime` becomes an ISO-8601 string
- `null` is ignored
- unsupported values are dropped and reported with `debugPrint` in debug builds

Convert lists, maps, and custom objects into simple fields before logging.

## Crash Reporting

Global Flutter and Dart fatal errors can be connected during initialization with
`captureFlutterErrors: true`.

For errors you catch manually:

```dart
try {
  await repository.sync();
} catch (error, stackTrace) {
  await ref.read(appCrashReporterProvider).recordError(
    error,
    stackTrace,
    fatal: false,
  );
  rethrow;
}
```

You can also add Crashlytics breadcrumbs:

```dart
ref.read(appCrashReporterProvider).log('sync started');
```

## Performance Traces

Use `traceAsync` for critical async flows:

```dart
final result = await ref.read(appPerformanceTracerProvider).traceAsync(
  'sync_push',
  (trace) async {
    trace.putAttribute('source', 'manual');
    trace.incrementMetric('pending_items', 3);
    return syncPush();
  },
);
```

Or manually start and stop a trace:

```dart
final trace = await ref
    .read(appPerformanceTracerProvider)
    .startTrace('voice_parse');

try {
  trace.putAttribute('language', 'en-US');
  await parseVoice();
} finally {
  await trace.stop();
}
```

## Dio Performance Interceptor

Add the Firebase Performance interceptor to a Dio instance:

```dart
final dio = Dio();
dio.interceptors.addAll(
  ref.read(firebasePerformanceDioInterceptorsProvider),
);
```

If `enablePerformance` is `false`, the provider returns an empty list.

## Identity Synchronization

After login, set the telemetry identity once:

```dart
await ref.read(appTelemetryIdentityProvider).setIdentity(
  user.id,
  properties: {
    'plan': user.plan,
    'locale': user.locale,
  },
);
```

This updates:

- Analytics user id
- Analytics user properties
- Crashlytics user identifier

On logout, clear the identity:

```dart
await ref.read(appTelemetryIdentityProvider).clearIdentity(
  propertyNames: ['plan', 'locale'],
);
```

You can also pass `null` to `setIdentity`:

```dart
await ref.read(appTelemetryIdentityProvider).setIdentity(
  null,
  properties: {
    'plan': '',
    'locale': '',
  },
);
```

## Testing

The package includes fake implementations so tests can assert telemetry without
touching Firebase.

### Analytics

```dart
test('logs signup event', () async {
  final fakeAnalytics = FakeAppAnalytics();

  final container = ProviderContainer(
    overrides: [
      appFactoryFirebaseConfigProvider.overrideWithValue(
        AppFactoryFirebaseConfig(
          options: DefaultFirebaseOptions.currentPlatform,
          enableAnalytics: false,
          enableCrashlytics: false,
          enablePerformance: false,
        ),
      ),
      appAnalyticsProvider.overrideWithValue(fakeAnalytics),
    ],
  );
  addTearDown(container.dispose);

  await container.read(appAnalyticsProvider).logEvent(
    'signup_complete',
    parameters: {'source': 'email'},
  );

  expect(fakeAnalytics.events, hasLength(1));
  expect(fakeAnalytics.events.single.name, 'signup_complete');
  expect(fakeAnalytics.events.single.parameters['source'], 'email');
});
```

### Crash Reporting

```dart
final fakeCrashReporter = FakeAppCrashReporter();

final container = ProviderContainer(
  overrides: [
    appCrashReporterProvider.overrideWithValue(fakeCrashReporter),
  ],
);

await container.read(appCrashReporterProvider).recordError(
  Exception('boom'),
  StackTrace.current,
  fatal: false,
);

expect(fakeCrashReporter.errors.single.fatal, false);
```

### Performance

```dart
final fakeTracer = FakeAppPerformanceTracer();

final container = ProviderContainer(
  overrides: [
    appPerformanceTracerProvider.overrideWithValue(fakeTracer),
  ],
);

await container.read(appPerformanceTracerProvider).traceAsync(
  'sync_push',
  (trace) async {
    trace.putAttribute('source', 'manual');
  },
);

expect(fakeTracer.traces.single.name, 'sync_push');
expect(fakeTracer.traces.single.attributes['source'], 'manual');
expect(fakeTracer.traces.single.stopped, true);
```

Available fakes:

- `FakeAppAnalytics`
- `FakeAppCrashReporter`
- `FakeAppPerformanceTracer`

## FAQ

### Why not include `firebase_options.dart` in this package?

Each app uses a different Firebase project. The generated Firebase options and
platform files belong to the app, not to a reusable package.

### Why is collection disabled in debug by default?

The default `collectionInReleaseOnly: true` avoids polluting production
dashboards during development, testing, hot reload, and local debugging.

If you need collection in debug builds, explicitly override it:

```dart
AppFactoryFirebaseConfig(
  options: DefaultFirebaseOptions.currentPlatform,
  analyticsCollectionEnabled: true,
  crashlyticsCollectionEnabled: true,
  performanceCollectionEnabled: true,
)
```

### Can initialization failure block app startup?

Only a missing `AppFactoryFirebaseConfig` is treated as a setup error. Firebase
subsystem failures are recorded in `initializationErrors`, and the app can keep
running.

### Should app code use Firebase SDK singletons directly?

Prefer `appAnalyticsProvider`, `appCrashReporterProvider`, and
`appPerformanceTracerProvider`. That keeps business code testable and makes it
easy to replace implementations in tests.
