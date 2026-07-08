import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app_factory_firebase/app_factory_firebase.dart';

void main() {
  const FirebaseOptions options = FirebaseOptions(
    apiKey: 'api-key',
    appId: 'app-id',
    messagingSenderId: 'sender-id',
    projectId: 'project-id',
  );

  test('collection defaults to release-only', () {
    const AppFactoryFirebaseConfig config = AppFactoryFirebaseConfig(
      options: options,
    );

    expect(
      config.resolveAnalyticsCollectionEnabled(isReleaseMode: false),
      false,
    );
    expect(config.resolveAnalyticsCollectionEnabled(isReleaseMode: true), true);
    expect(
      config.resolveCrashlyticsCollectionEnabled(isReleaseMode: false),
      false,
    );
    expect(
      config.resolvePerformanceCollectionEnabled(isReleaseMode: true),
      true,
    );
  });

  test('explicit collection setting overrides release-only policy', () {
    const AppFactoryFirebaseConfig config = AppFactoryFirebaseConfig(
      options: options,
      analyticsCollectionEnabled: true,
      crashlyticsCollectionEnabled: false,
      performanceCollectionEnabled: true,
    );

    expect(
      config.resolveAnalyticsCollectionEnabled(isReleaseMode: false),
      true,
    );
    expect(
      config.resolveCrashlyticsCollectionEnabled(isReleaseMode: true),
      false,
    );
    expect(
      config.resolvePerformanceCollectionEnabled(isReleaseMode: false),
      true,
    );
  });

  test('sanitizes Firebase analytics parameters', () {
    final Map<String, Object>? parameters = sanitizeFirebaseParameters(
      <String, Object?>{
        'string': 'value',
        'int': 1,
        'double': 1.5,
        'bool': true,
        'date': DateTime.utc(2026, 7, 8, 1, 2, 3),
        'null': null,
        'unsupported': <String>['a'],
      },
    );

    expect(parameters, <String, Object>{
      'string': 'value',
      'int': 1,
      'double': 1.5,
      'bool': 'true',
      'date': '2026-07-08T01:02:03.000Z',
    });
  });

  test('config provider fails fast when not overridden', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(appFactoryFirebaseConfigProvider),
      throwsA(
        predicate<Object>(
          (Object error) =>
              error.toString().contains('AppFactoryFirebaseConfig') &&
              error.toString().contains('overrideWithValue'),
        ),
      ),
    );
  });

  test('Dio performance provider is empty when performance is disabled', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        appFactoryFirebaseConfigProvider.overrideWithValue(
          const AppFactoryFirebaseConfig(
            options: options,
            enablePerformance: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(firebasePerformanceDioInterceptorsProvider), isEmpty);
  });

  test('dynamic override items remain compatible with ProviderContainer', () {
    const AppFactoryFirebaseConfig config = AppFactoryFirebaseConfig(
      options: options,
      enableAnalytics: false,
    );
    final List<dynamic> additionalOverrides = <dynamic>[];
    final ProviderContainer container = ProviderContainer(
      overrides: [
        appFactoryFirebaseConfigProvider.overrideWithValue(config),
        ...additionalOverrides,
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(appFactoryFirebaseConfigProvider), same(config));
  });

  test('FakeAppAnalytics records events for assertions', () async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    analytics.setContextProperty('app_id', 'mx_expense');

    await analytics.logEvent(
      'expense_add_success',
      parameters: <String, Object?>{'source': 'manual'},
    );

    expect(analytics.events, hasLength(1));
    expect(analytics.events.single.name, 'expense_add_success');
    expect(analytics.events.single.parameters, <String, Object?>{
      'app_id': 'mx_expense',
      'source': 'manual',
    });
  });

  test('FakeAppPerformanceTracer records traces and stops them', () async {
    final FakeAppPerformanceTracer tracer = FakeAppPerformanceTracer();

    final int result = await tracer.traceAsync('sync_push', (trace) async {
      trace.putAttribute('source', 'manual');
      trace.incrementMetric('items', 2);
      return 42;
    });

    expect(result, 42);
    expect(tracer.traces, hasLength(1));
    expect(tracer.traces.single.name, 'sync_push');
    expect(tracer.traces.single.attributes['source'], 'manual');
    expect(tracer.traces.single.metrics['items'], 2);
    expect(tracer.traces.single.stopped, true);
  });

  test(
    'appTelemetryIdentityProvider fans identity out to analytics and crash',
    () async {
      final FakeAppAnalytics analytics = FakeAppAnalytics();
      final FakeAppCrashReporter crashReporter = FakeAppCrashReporter();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appFactoryFirebaseConfigProvider.overrideWithValue(
            const AppFactoryFirebaseConfig(options: options),
          ),
          appAnalyticsProvider.overrideWithValue(analytics),
          appCrashReporterProvider.overrideWithValue(crashReporter),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(appTelemetryIdentityProvider)
          .setIdentity('user-1', properties: <String, String>{'plan': 'plus'});

      expect(analytics.userIds, <String?>['user-1']);
      expect(crashReporter.userIdentifiers, <String?>['user-1']);
      expect(analytics.userProperties, hasLength(1));
      expect(analytics.userProperties.single.name, 'plan');
      expect(analytics.userProperties.single.value, 'plus');
    },
  );

  test('appTelemetryIdentityProvider clears identity on logout', () async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    final FakeAppCrashReporter crashReporter = FakeAppCrashReporter();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        appFactoryFirebaseConfigProvider.overrideWithValue(
          const AppFactoryFirebaseConfig(options: options),
        ),
        appAnalyticsProvider.overrideWithValue(analytics),
        appCrashReporterProvider.overrideWithValue(crashReporter),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(appTelemetryIdentityProvider)
        .clearIdentity(propertyNames: <String>['plan']);

    expect(analytics.userIds, <String?>[null]);
    expect(crashReporter.userIdentifiers, <String?>[null]);
    expect(analytics.userProperties, hasLength(1));
    expect(analytics.userProperties.single.name, 'plan');
    expect(analytics.userProperties.single.value, isNull);
  });
}
