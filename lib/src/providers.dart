import 'package:dio/dio.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'analytics.dart';
import 'config.dart';
import 'crashlytics.dart';
import 'dio_performance.dart';
import 'go_router_screen_tracking.dart';
import 'identity.dart';
import 'interaction_events.dart';
import 'performance.dart';
import 'screen_context.dart';
import 'screen_tracking_issues.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
AppFactoryFirebaseConfig appFactoryFirebaseConfig(Ref ref) {
  throw UnimplementedError(
    'AppFactoryFirebaseConfig must be injected with '
    'appFactoryFirebaseConfigProvider.overrideWithValue(...) before '
    'AppFactoryFirebase.initialize(container) is called.',
  );
}

@Riverpod(keepAlive: true)
FirebaseAnalytics firebaseAnalytics(Ref ref) => FirebaseAnalytics.instance;

@Riverpod(keepAlive: true)
FirebaseCrashlytics firebaseCrashlytics(Ref ref) =>
    FirebaseCrashlytics.instance;

@Riverpod(keepAlive: true)
FirebasePerformance firebasePerformance(Ref ref) =>
    FirebasePerformance.instance;

@Riverpod(keepAlive: true)
AppAnalytics appAnalytics(Ref ref) {
  return FirebaseAppAnalytics(analytics: ref.watch(firebaseAnalyticsProvider));
}

@Riverpod(keepAlive: true)
AppAnalyticsScreenContext appAnalyticsScreenContext(Ref ref) {
  return AppAnalyticsScreenContext();
}

@Riverpod(keepAlive: true)
AppScreenTrackingIssueSink appScreenTrackingIssueSink(Ref ref) {
  return (AppScreenTrackingIssue issue) {
    debugPrint(issue.toString());
    if (issue.stackTrace case final StackTrace stackTrace) {
      debugPrint(stackTrace.toString());
    }
  };
}

@Riverpod(keepAlive: true)
AppScreenTrackingIssueReporter appScreenTrackingIssueReporter(Ref ref) {
  return AppScreenTrackingIssueReporter(
    sink: ref.watch(appScreenTrackingIssueSinkProvider),
  );
}

@Riverpod(keepAlive: true)
AppScreenTracker appScreenTracker(Ref ref) {
  return AppScreenTracker(
    analytics: ref.watch(appAnalyticsProvider),
    screenContext: ref.watch(appAnalyticsScreenContextProvider),
    issueReporter: ref.watch(appScreenTrackingIssueReporterProvider),
  );
}

@Riverpod(keepAlive: true)
AppGoRouterScreenResolver goRouterScreenResolver(Ref ref) {
  return defaultAppGoRouterScreenResolver;
}

@riverpod
AppGoRouterScreenTracking goRouterScreenTracking(Ref ref, GoRouter router) {
  final AppGoRouterScreenTracking tracking = AppGoRouterScreenTracking(
    router: router,
    screenTracker: ref.watch(appScreenTrackerProvider),
    issueReporter: ref.watch(appScreenTrackingIssueReporterProvider),
    screenResolver: ref.watch(goRouterScreenResolverProvider),
  );
  ref.onDispose(tracking.dispose);
  return tracking;
}

@Riverpod(keepAlive: true)
AppInteractionEvents appInteractionEvents(Ref ref) {
  return AppInteractionEvents(
    analytics: ref.watch(appAnalyticsProvider),
    screenContext: ref.watch(appAnalyticsScreenContextProvider),
    issueReporter: ref.watch(appScreenTrackingIssueReporterProvider),
  );
}

@Riverpod(keepAlive: true)
AppCrashReporter appCrashReporter(Ref ref) {
  return FirebaseAppCrashReporter(
    crashlytics: ref.watch(firebaseCrashlyticsProvider),
  );
}

@Riverpod(keepAlive: true)
AppPerformanceTracer appPerformanceTracer(Ref ref) {
  return FirebaseAppPerformanceTracer(
    performance: ref.watch(firebasePerformanceProvider),
  );
}

@Riverpod(keepAlive: true)
AppTelemetryIdentity appTelemetryIdentity(Ref ref) {
  return DefaultAppTelemetryIdentity(
    analytics: ref.watch(appAnalyticsProvider),
    crashReporter: ref.watch(appCrashReporterProvider),
  );
}

@Riverpod(keepAlive: true)
void crashlyticsInitializer(Ref ref) {
  final AppFactoryFirebaseConfig config = ref.watch(
    appFactoryFirebaseConfigProvider,
  );
  if (!config.enableCrashlytics || !config.captureFlutterErrors) {
    return;
  }
  FirebaseCrashlyticsFlutterErrorInitializer.setup(
    ref.watch(appCrashReporterProvider),
  );
}

@Riverpod(keepAlive: true)
Future<bool> crashlyticsCollectionInitializer(Ref ref) async {
  final AppFactoryFirebaseConfig config = ref.watch(
    appFactoryFirebaseConfigProvider,
  );
  if (!config.enableCrashlytics) {
    return false;
  }

  final bool enabled = config.resolveCrashlyticsCollectionEnabled();
  await ref
      .watch(firebaseCrashlyticsProvider)
      .setCrashlyticsCollectionEnabled(enabled);
  return enabled;
}

@Riverpod(keepAlive: true)
Future<bool> analyticsInitializer(Ref ref) async {
  final AppFactoryFirebaseConfig config = ref.watch(
    appFactoryFirebaseConfigProvider,
  );
  if (!config.enableAnalytics) {
    return false;
  }

  final bool enabled = config.resolveAnalyticsCollectionEnabled();
  await ref
      .watch(firebaseAnalyticsProvider)
      .setAnalyticsCollectionEnabled(enabled);

  final AppAnalytics analytics = ref.watch(appAnalyticsProvider);
  if (config.contextProperties.isNotEmpty) {
    analytics.setContextProperties(config.contextProperties);
  }
  if (config.defaultEventParameters.isNotEmpty) {
    await analytics.setDefaultEventParameters(config.defaultEventParameters);
  }
  return enabled;
}

@Riverpod(keepAlive: true)
Future<bool> performanceInitializer(Ref ref) async {
  final AppFactoryFirebaseConfig config = ref.watch(
    appFactoryFirebaseConfigProvider,
  );
  if (!config.enablePerformance) {
    return false;
  }

  final bool enabled = config.resolvePerformanceCollectionEnabled();
  await ref.watch(appPerformanceTracerProvider).setCollectionEnabled(enabled);
  return enabled;
}

@Riverpod(keepAlive: true)
List<Interceptor> firebasePerformanceDioInterceptors(Ref ref) {
  final AppFactoryFirebaseConfig config = ref.watch(
    appFactoryFirebaseConfigProvider,
  );
  if (!config.enablePerformance) {
    return const <Interceptor>[];
  }
  return <Interceptor>[createFirebasePerformanceDioInterceptor()];
}
