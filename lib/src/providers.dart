import 'package:dio/dio.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

final Provider<AppFactoryFirebaseConfig> appFactoryFirebaseConfigProvider =
    Provider<AppFactoryFirebaseConfig>((Ref ref) {
      throw UnimplementedError(
        'AppFactoryFirebaseConfig must be injected with '
        'appFactoryFirebaseConfigProvider.overrideWithValue(...) before '
        'AppFactoryFirebase.initialize(container) is called.',
      );
    });

final Provider<FirebaseAnalytics> firebaseAnalyticsProvider =
    Provider<FirebaseAnalytics>((Ref ref) => FirebaseAnalytics.instance);

final Provider<FirebaseCrashlytics> firebaseCrashlyticsProvider =
    Provider<FirebaseCrashlytics>((Ref ref) => FirebaseCrashlytics.instance);

final Provider<FirebasePerformance> firebasePerformanceProvider =
    Provider<FirebasePerformance>((Ref ref) => FirebasePerformance.instance);

final Provider<AppAnalytics> appAnalyticsProvider = Provider<AppAnalytics>((
  Ref ref,
) {
  return FirebaseAppAnalytics(analytics: ref.watch(firebaseAnalyticsProvider));
});

final Provider<AppAnalyticsScreenContext> appAnalyticsScreenContextProvider =
    Provider<AppAnalyticsScreenContext>((Ref ref) {
      return AppAnalyticsScreenContext();
    });

final Provider<AppScreenTrackingIssueSink> appScreenTrackingIssueSinkProvider =
    Provider<AppScreenTrackingIssueSink>((Ref ref) {
      return (AppScreenTrackingIssue issue) {
        debugPrint(issue.toString());
        if (issue.stackTrace case final StackTrace stackTrace) {
          debugPrint(stackTrace.toString());
        }
      };
    });

final Provider<AppScreenTrackingIssueReporter>
appScreenTrackingIssueReporterProvider =
    Provider<AppScreenTrackingIssueReporter>((Ref ref) {
      return AppScreenTrackingIssueReporter(
        sink: ref.watch(appScreenTrackingIssueSinkProvider),
      );
    });

final Provider<AppScreenTracker> appScreenTrackerProvider =
    Provider<AppScreenTracker>((Ref ref) {
      return AppScreenTracker(
        analytics: ref.watch(appAnalyticsProvider),
        screenContext: ref.watch(appAnalyticsScreenContextProvider),
        issueReporter: ref.watch(appScreenTrackingIssueReporterProvider),
      );
    });

final goRouterScreenResolverProvider = Provider<AppGoRouterScreenResolver>((
  Ref ref,
) {
  return defaultAppGoRouterScreenResolver;
});

final goRouterScreenTrackingProvider = Provider.autoDispose
    .family<AppGoRouterScreenTracking, GoRouter>((Ref ref, GoRouter router) {
      final AppGoRouterScreenTracking tracking = AppGoRouterScreenTracking(
        router: router,
        screenTracker: ref.watch(appScreenTrackerProvider),
        issueReporter: ref.watch(appScreenTrackingIssueReporterProvider),
        screenResolver: ref.watch(goRouterScreenResolverProvider),
      );
      ref.onDispose(tracking.dispose);
      return tracking;
    });

final Provider<AppInteractionEvents> appInteractionEventsProvider =
    Provider<AppInteractionEvents>((Ref ref) {
      return AppInteractionEvents(
        analytics: ref.watch(appAnalyticsProvider),
        screenContext: ref.watch(appAnalyticsScreenContextProvider),
        issueReporter: ref.watch(appScreenTrackingIssueReporterProvider),
      );
    });

final Provider<AppCrashReporter> appCrashReporterProvider =
    Provider<AppCrashReporter>((Ref ref) {
      return FirebaseAppCrashReporter(
        crashlytics: ref.watch(firebaseCrashlyticsProvider),
      );
    });

final Provider<AppPerformanceTracer> appPerformanceTracerProvider =
    Provider<AppPerformanceTracer>((Ref ref) {
      return FirebaseAppPerformanceTracer(
        performance: ref.watch(firebasePerformanceProvider),
      );
    });

final Provider<AppTelemetryIdentity> appTelemetryIdentityProvider =
    Provider<AppTelemetryIdentity>((Ref ref) {
      return DefaultAppTelemetryIdentity(
        analytics: ref.watch(appAnalyticsProvider),
        crashReporter: ref.watch(appCrashReporterProvider),
      );
    });

final Provider<void> crashlyticsInitializerProvider = Provider<void>((Ref ref) {
  final AppFactoryFirebaseConfig config = ref.watch(
    appFactoryFirebaseConfigProvider,
  );
  if (!config.enableCrashlytics || !config.captureFlutterErrors) {
    return;
  }
  FirebaseCrashlyticsFlutterErrorInitializer.setup(
    ref.watch(appCrashReporterProvider),
  );
});

final FutureProvider<bool> crashlyticsCollectionInitializerProvider =
    FutureProvider<bool>((Ref ref) async {
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
    });

final FutureProvider<bool> analyticsInitializerProvider = FutureProvider<bool>((
  Ref ref,
) async {
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
});

final FutureProvider<bool> performanceInitializerProvider =
    FutureProvider<bool>((Ref ref) async {
      final AppFactoryFirebaseConfig config = ref.watch(
        appFactoryFirebaseConfigProvider,
      );
      if (!config.enablePerformance) {
        return false;
      }

      final bool enabled = config.resolvePerformanceCollectionEnabled();
      await ref
          .watch(appPerformanceTracerProvider)
          .setCollectionEnabled(enabled);
      return enabled;
    });

final Provider<List<Interceptor>> firebasePerformanceDioInterceptorsProvider =
    Provider<List<Interceptor>>((Ref ref) {
      final AppFactoryFirebaseConfig config = ref.watch(
        appFactoryFirebaseConfigProvider,
      );
      if (!config.enablePerformance) {
        return const <Interceptor>[];
      }
      return <Interceptor>[createFirebasePerformanceDioInterceptor()];
    });
