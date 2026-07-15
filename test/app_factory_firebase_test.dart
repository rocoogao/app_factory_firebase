import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  test('FakeAppAnalytics records screen views for assertions', () async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    analytics.setContextProperty('app_id', 'mx_expense');

    await analytics.logScreenView(
      screenName: 'Home',
      screenClass: 'BottomTab',
      parameters: <String, Object?>{'language': 'es-MX', 'currency': 'MXN'},
    );

    expect(analytics.screenViews, hasLength(1));
    expect(analytics.screenViews.single.screenName, 'Home');
    expect(analytics.screenViews.single.screenClass, 'BottomTab');
    expect(analytics.screenViews.single.parameters, <String, Object?>{
      'app_id': 'mx_expense',
      'language': 'es-MX',
      'currency': 'MXN',
    });
  });

  test('interaction events include the current screen name', () async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    final AppAnalyticsScreenContext screenContext = AppAnalyticsScreenContext();
    final AppScreenTracker screenTracker = AppScreenTracker(
      analytics: analytics,
      screenContext: screenContext,
    );
    final AppInteractionEvents events = AppInteractionEvents(
      analytics: analytics,
      screenContext: screenContext,
    );

    await screenTracker.trackScreenView(
      screenName: 'expense_home',
      screenClass: 'BottomTab',
    );
    await events.clickElement(
      elementId: 'add_expense_button',
      elementName: 'add_expense',
    );
    await events.viewPop(
      popId: 'delete_expense_confirm',
      popName: 'delete_expense_confirm',
    );

    expect(analytics.events, hasLength(2));
    expect(analytics.events[0].name, AppInteractionEventNames.clickElement);
    expect(analytics.events[0].parameters, <String, Object?>{
      'screen_name': 'expense_home',
      'element_id': 'add_expense_button',
      'element_name': 'add_expense',
    });
    expect(analytics.events[1].name, AppInteractionEventNames.viewPop);
    expect(analytics.events[1].parameters, <String, Object?>{
      'screen_name': 'expense_home',
      'pop_id': 'delete_expense_confirm',
      'pop_name': 'delete_expense_confirm',
    });
    expect(analytics.screenViews.single.screenName, 'expense_home');
    expect(analytics.screenViews.single.screenClass, 'BottomTab');
  });

  test('interaction events allow a screen name override', () async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    final AppAnalyticsScreenContext screenContext = AppAnalyticsScreenContext();
    final AppInteractionEvents events = AppInteractionEvents(
      analytics: analytics,
      screenContext: screenContext,
    );

    screenContext.update('expense_home');
    await events.clickElement(
      screenName: 'expense_edit_sheet',
      elementId: 'save_button',
      elementName: 'save_expense',
    );

    expect(
      analytics.events.single.parameters['screen_name'],
      'expense_edit_sheet',
    );
  });

  test('interaction events use unknown when no screen is tracked', () async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    final List<AppScreenTrackingIssue> issues = <AppScreenTrackingIssue>[];
    final AppInteractionEvents events = AppInteractionEvents(
      analytics: analytics,
      screenContext: AppAnalyticsScreenContext(),
      issueReporter: AppScreenTrackingIssueReporter(sink: issues.add),
    );

    await events.clickElement(
      elementId: 'add_expense_button',
      elementName: 'add_expense',
    );

    expect(
      analytics.events.single.parameters['screen_name'],
      AppAnalyticsScreenNames.unknown,
    );
    expect(issues.single.type, AppScreenTrackingIssueType.missingScreenContext);
  });

  test(
    'interaction event upload failures are reported and fail-open',
    () async {
      final List<AppScreenTrackingIssue> issues = <AppScreenTrackingIssue>[];
      final AppInteractionEvents events = AppInteractionEvents(
        analytics: _ThrowingEventAnalytics(),
        screenContext: AppAnalyticsScreenContext()..update('Home'),
        issueReporter: AppScreenTrackingIssueReporter(sink: issues.add),
      );

      await expectLater(
        events.clickElement(elementId: 'save', elementName: 'save'),
        completes,
      );
      await expectLater(
        events.viewPop(popId: 'confirm', popName: 'confirm'),
        completes,
      );

      expect(
        issues.map((AppScreenTrackingIssue issue) => issue.type),
        <AppScreenTrackingIssueType>[
          AppScreenTrackingIssueType.interactionEventFailure,
          AppScreenTrackingIssueType.interactionEventFailure,
        ],
      );
    },
  );

  test('screen tracker reports and ignores empty screen names', () async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    final List<AppScreenTrackingIssue> issues = <AppScreenTrackingIssue>[];
    final AppScreenTracker tracker = AppScreenTracker(
      analytics: analytics,
      screenContext: AppAnalyticsScreenContext(),
      issueReporter: AppScreenTrackingIssueReporter(sink: issues.add),
    );

    await tracker.trackScreenView(screenName: '   ');

    expect(analytics.screenViews, isEmpty);
    expect(issues.single.type, AppScreenTrackingIssueType.invalidScreenName);
  });

  test('screen tracker reports upload failures once', () async {
    final List<AppScreenTrackingIssue> issues = <AppScreenTrackingIssue>[];
    final AppScreenTracker tracker = AppScreenTracker(
      analytics: _ThrowingScreenAnalytics(),
      screenContext: AppAnalyticsScreenContext(),
      issueReporter: AppScreenTrackingIssueReporter(sink: issues.add),
    );

    await tracker.trackScreenView(screenName: 'home');
    await tracker.trackScreenView(screenName: 'home');

    expect(issues, hasLength(1));
    expect(issues.single.type, AppScreenTrackingIssueType.screenViewFailure);
  });

  test(
    'issue reporter deduplicates and isolates synchronous sink failures',
    () {
      int sinkCalls = 0;
      final AppScreenTrackingIssueReporter reporter =
          AppScreenTrackingIssueReporter(
            sink: (AppScreenTrackingIssue issue) {
              sinkCalls++;
              throw StateError('sink failed');
            },
          );
      const AppScreenTrackingIssue issue = AppScreenTrackingIssue(
        type: AppScreenTrackingIssueType.unmappedRoute,
        message: 'unmapped',
        routeName: '/unknown',
      );

      expect(() => reporter.report(issue), returnsNormally);
      expect(() => reporter.report(issue), returnsNormally);
      expect(sinkCalls, 1);
    },
  );

  test('issue reporter isolates asynchronous sink failures', () async {
    final AppScreenTrackingIssueReporter reporter =
        AppScreenTrackingIssueReporter(
          sink: (AppScreenTrackingIssue issue) async {
            throw StateError('async sink failed');
          },
        );

    expect(
      () => reporter.report(
        const AppScreenTrackingIssue(
          type: AppScreenTrackingIssueType.resolverFailure,
          message: 'resolver failed',
        ),
      ),
      returnsNormally,
    );
    await Future<void>.delayed(Duration.zero);
  });

  test('issue sink provider is shared by tracking components', () async {
    final List<AppScreenTrackingIssue> issues = <AppScreenTrackingIssue>[];
    final ProviderContainer container = ProviderContainer(
      overrides: [
        appAnalyticsProvider.overrideWithValue(FakeAppAnalytics()),
        appScreenTrackingIssueSinkProvider.overrideWithValue(issues.add),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(appInteractionEventsProvider)
        .clickElement(elementId: 'add_button', elementName: 'add');
    await container
        .read(appScreenTrackerProvider)
        .trackScreenView(screenName: '   ');

    expect(
      issues.map((AppScreenTrackingIssue issue) => issue.type),
      <AppScreenTrackingIssueType>[
        AppScreenTrackingIssueType.missingScreenContext,
        AppScreenTrackingIssueType.invalidScreenName,
      ],
    );
  });

  testWidgets('go_router tracking follows StatefulShellRoute tabs', (
    WidgetTester tester,
  ) async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    final GoRouter router = GoRouter(
      initialLocation: '/home',
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder:
              (
                BuildContext context,
                GoRouterState state,
                StatefulNavigationShell navigationShell,
              ) {
                return Scaffold(body: navigationShell);
              },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  name: 'home_tab',
                  path: '/home',
                  builder: (_, _) => const SizedBox(key: Key('home_tab')),
                  routes: <RouteBase>[
                    GoRoute(
                      name: 'expense_detail',
                      path: 'expense/:id',
                      builder: (_, _) => const SizedBox(),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  name: 'statistics_tab',
                  path: '/statistics',
                  builder: (_, _) => const SizedBox(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [appAnalyticsProvider.overrideWithValue(analytics)],
    );
    final AppAnalyticsScreenContext screenContext = container.read(
      appAnalyticsScreenContextProvider,
    );
    final subscription = container.listen(
      goRouterScreenTrackingProvider(router),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(() {
      subscription.close();
      container.dispose();
      router.dispose();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(screenContext.screenName, 'home_tab');
    expect(analytics.screenViews.last.screenName, 'home_tab');

    final int screenViewCount = analytics.screenViews.length;
    final BuildContext homeContext = tester.element(
      find.byKey(const Key('home_tab')),
    );
    unawaited(
      showDialog<void>(
        context: homeContext,
        builder: (_) => const AlertDialog(title: Text('Confirm')),
      ),
    );
    await tester.pumpAndSettle();

    expect(screenContext.screenName, 'home_tab');
    expect(analytics.screenViews, hasLength(screenViewCount));

    Navigator.of(homeContext, rootNavigator: true).pop();
    await tester.pumpAndSettle();

    unawaited(
      router.pushNamed(
        'expense_detail',
        pathParameters: <String, String>{'id': '42'},
      ),
    );
    await tester.pumpAndSettle();

    expect(screenContext.screenName, 'expense_detail');
    expect(analytics.screenViews.last.screenName, 'expense_detail');

    router.pop();
    await tester.pumpAndSettle();

    expect(screenContext.screenName, 'home_tab');
    expect(analytics.screenViews.last.screenName, 'home_tab');

    router.goNamed('statistics_tab');
    await tester.pumpAndSettle();

    expect(screenContext.screenName, 'statistics_tab');
    expect(analytics.screenViews.last.screenName, 'statistics_tab');
  });

  testWidgets('go_router tracking ignores query-only changes', (
    WidgetTester tester,
  ) async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    final GoRouter router = GoRouter(
      initialLocation: '/search?filter=open',
      routes: <RouteBase>[
        GoRoute(
          name: 'search',
          path: '/search',
          builder: (_, _) => const SizedBox(),
        ),
      ],
    );
    final AppGoRouterScreenTracking tracking = AppGoRouterScreenTracking(
      router: router,
      screenTracker: AppScreenTracker(
        analytics: analytics,
        screenContext: AppAnalyticsScreenContext(),
      ),
    );
    addTearDown(() {
      tracking.dispose();
      router.dispose();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(analytics.screenViews, hasLength(1));

    router.go('/search?filter=closed');
    await tester.pumpAndSettle();

    expect(analytics.screenViews, hasLength(1));
  });

  testWidgets('go_router fingerprint normalizes screen name whitespace', (
    WidgetTester tester,
  ) async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    final GoRouter router = GoRouter(
      initialLocation: '/home?format=padded',
      routes: <RouteBase>[
        GoRoute(
          name: 'home',
          path: '/home',
          builder: (_, _) => const SizedBox(),
        ),
      ],
    );
    final AppGoRouterScreenTracking tracking = AppGoRouterScreenTracking(
      router: router,
      screenTracker: AppScreenTracker(
        analytics: analytics,
        screenContext: AppAnalyticsScreenContext(),
      ),
      screenResolver: (GoRouterState state) {
        final bool padded = state.uri.queryParameters['format'] == 'padded';
        return AppTrackedScreen(
          AppResolvedScreen(screenName: padded ? ' Home ' : 'Home'),
        );
      },
    );
    addTearDown(() {
      tracking.dispose();
      router.dispose();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(analytics.screenViews.single.screenName, 'Home');

    router.go('/home?format=plain');
    await tester.pumpAndSettle();

    expect(analytics.screenViews, hasLength(1));
  });

  testWidgets('go_router trackingKey can include selected query changes', (
    WidgetTester tester,
  ) async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    final GoRouter router = GoRouter(
      initialLocation: '/search?filter=open',
      routes: <RouteBase>[
        GoRoute(
          name: 'search',
          path: '/search',
          builder: (_, _) => const SizedBox(),
        ),
      ],
    );
    final AppGoRouterScreenTracking tracking = AppGoRouterScreenTracking(
      router: router,
      screenTracker: AppScreenTracker(
        analytics: analytics,
        screenContext: AppAnalyticsScreenContext(),
      ),
      screenResolver: (GoRouterState state) {
        return AppTrackedScreen(
          AppResolvedScreen(
            screenName: state.name!,
            trackingKey: state.uri.queryParameters['filter'],
          ),
        );
      },
    );
    addTearDown(() {
      tracking.dispose();
      router.dispose();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go('/search?filter=closed');
    await tester.pumpAndSettle();

    expect(
      analytics.screenViews.map((FakeScreenView view) => view.screenName),
      <String>['search', 'search'],
    );
  });

  testWidgets('go_router resolver isolates invalid and popup routes', (
    WidgetTester tester,
  ) async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    final List<AppScreenTrackingIssue> issues = <AppScreenTrackingIssue>[];
    final AppAnalyticsScreenContext screenContext = AppAnalyticsScreenContext();
    final AppScreenTrackingIssueReporter issueReporter =
        AppScreenTrackingIssueReporter(sink: issues.add);
    final GoRouter router = GoRouter(
      initialLocation: '/home',
      routes: <RouteBase>[
        for (final String routeName in <String>[
          'home',
          'dialog',
          'unmapped',
          'empty',
          'failure',
        ])
          GoRoute(
            name: routeName,
            path: '/$routeName',
            builder: (_, _) => const SizedBox(),
          ),
      ],
    );
    final AppGoRouterScreenTracking tracking = AppGoRouterScreenTracking(
      router: router,
      screenTracker: AppScreenTracker(
        analytics: analytics,
        screenContext: screenContext,
        issueReporter: issueReporter,
      ),
      issueReporter: issueReporter,
      screenResolver: (GoRouterState state) {
        switch (state.name) {
          case 'dialog':
            return const AppIgnoredScreen();
          case 'unmapped':
            return const AppUnmappedScreen(reason: 'No screen mapping.');
          case 'empty':
            return const AppTrackedScreen(AppResolvedScreen(screenName: '   '));
          case 'failure':
            throw StateError('resolver failed');
          default:
            return AppTrackedScreen(
              AppResolvedScreen(
                screenName: state.name!,
                screenClass: 'GoRoute',
                parameters: <String, Object?>{'route_name': state.name},
              ),
            );
        }
      },
    );
    addTearDown(() {
      tracking.dispose();
      router.dispose();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(screenContext.screenName, 'home');
    expect(analytics.screenViews.single.screenClass, 'GoRoute');
    expect(analytics.screenViews.single.parameters['route_name'], 'home');

    for (final String routeName in <String>[
      'dialog',
      'unmapped',
      'empty',
      'failure',
    ]) {
      router.goNamed(routeName);
      await tester.pumpAndSettle();
      expect(screenContext.screenName, 'home');
      expect(analytics.screenViews, hasLength(1));
    }

    expect(
      issues.map((AppScreenTrackingIssue issue) => issue.type),
      <AppScreenTrackingIssueType>[
        AppScreenTrackingIssueType.unmappedRoute,
        AppScreenTrackingIssueType.invalidScreenName,
        AppScreenTrackingIssueType.resolverFailure,
      ],
    );
  });

  testWidgets('go_router tracking releases a replaced router', (
    WidgetTester tester,
  ) async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    final AppScreenTracker screenTracker = AppScreenTracker(
      analytics: analytics,
      screenContext: AppAnalyticsScreenContext(),
    );
    final GoRouter firstRouter = GoRouter(
      initialLocation: '/home',
      routes: <RouteBase>[
        GoRoute(
          name: 'home',
          path: '/home',
          builder: (_, _) => const SizedBox(),
        ),
        GoRoute(
          name: 'detail',
          path: '/detail',
          builder: (_, _) => const SizedBox(),
        ),
      ],
    );
    final AppGoRouterScreenTracking firstTracking = AppGoRouterScreenTracking(
      router: firstRouter,
      screenTracker: screenTracker,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: firstRouter));
    await tester.pumpAndSettle();
    expect(analytics.screenViews.last.screenName, 'home');

    firstTracking.dispose();
    final int screenViewCount = analytics.screenViews.length;
    firstRouter.goNamed('detail');
    await tester.pumpAndSettle();
    expect(analytics.screenViews, hasLength(screenViewCount));

    await tester.pumpWidget(const SizedBox());
    firstRouter.dispose();

    final GoRouter secondRouter = GoRouter(
      initialLocation: '/statistics',
      routes: <RouteBase>[
        GoRoute(
          name: 'statistics',
          path: '/statistics',
          builder: (_, _) => const SizedBox(),
        ),
      ],
    );
    final AppGoRouterScreenTracking secondTracking = AppGoRouterScreenTracking(
      router: secondRouter,
      screenTracker: screenTracker,
    );
    addTearDown(() {
      secondTracking.dispose();
      secondRouter.dispose();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: secondRouter));
    await tester.pumpAndSettle();

    expect(analytics.screenViews.last.screenName, 'statistics');
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

  test('performance trace start failures do not skip the action', () async {
    final _FailingStartPerformanceTracer tracer =
        _FailingStartPerformanceTracer();
    bool actionRan = false;

    final int result = await tracer.traceAsync('sync_push', (trace) async {
      actionRan = true;
      trace.putAttribute('source', 'manual');
      return 42;
    });

    expect(actionRan, true);
    expect(result, 42);
  });

  test('global crash handlers isolate asynchronous upload failures', () async {
    final previousFlutterErrorHandler = FlutterError.onError;
    final previousPlatformErrorHandler = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = previousFlutterErrorHandler;
      PlatformDispatcher.instance.onError = previousPlatformErrorHandler;
    });
    final _ThrowingCrashReporter crashReporter = _ThrowingCrashReporter();
    FirebaseCrashlyticsFlutterErrorInitializer.setup(crashReporter);

    expect(
      () => FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('flutter failure')),
      ),
      returnsNormally,
    );
    expect(
      () => PlatformDispatcher.instance.onError!(
        StateError('platform failure'),
        StackTrace.current,
      ),
      returnsNormally,
    );
    await Future<void>.delayed(Duration.zero);

    expect(crashReporter.recordErrorCalls, 2);
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

  test(
    'telemetry identity failures do not interrupt synchronization',
    () async {
      final _ThrowingIdentityAnalytics analytics = _ThrowingIdentityAnalytics();
      final _ThrowingIdentityCrashReporter crashReporter =
          _ThrowingIdentityCrashReporter();
      final DefaultAppTelemetryIdentity identity = DefaultAppTelemetryIdentity(
        analytics: analytics,
        crashReporter: crashReporter,
      );

      await expectLater(
        identity.setIdentity(
          'user-1',
          properties: <String, String>{'plan': 'plus'},
        ),
        completes,
      );
      await expectLater(
        identity.clearIdentity(propertyNames: <String>['plan']),
        completes,
      );

      expect(
        analytics.userProperties.map(
          (FakeUserProperty property) => property.value,
        ),
        <String?>['plus', null],
      );
    },
  );
}

class _ThrowingScreenAnalytics extends FakeAppAnalytics {
  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object?> parameters = const <String, Object?>{},
  }) async {
    throw StateError('screen upload failed');
  }
}

class _ThrowingEventAnalytics extends FakeAppAnalytics {
  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) async {
    throw StateError('event upload failed');
  }
}

class _FailingStartPerformanceTracer extends AppPerformanceTracer {
  @override
  Future<void> setCollectionEnabled(bool enabled) async {}

  @override
  Future<AppTraceHandle> startTrace(String name) async {
    throw StateError('trace start failed');
  }
}

class _ThrowingCrashReporter implements AppCrashReporter {
  int recordErrorCalls = 0;

  @override
  void log(String message) {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
  }) {
    recordErrorCalls++;
    return Future<void>.error(StateError('crash upload failed'));
  }

  @override
  Future<void> setUserIdentifier(String? userId) async {}
}

class _ThrowingIdentityAnalytics extends FakeAppAnalytics {
  @override
  Future<void> setUserId(String? userId) {
    throw StateError('analytics identity failed');
  }
}

class _ThrowingIdentityCrashReporter extends FakeAppCrashReporter {
  @override
  Future<void> setUserIdentifier(String? userId) {
    return Future<void>.error(StateError('crash identity failed'));
  }
}
