library;

export 'src/analytics.dart';
export 'src/app_factory_firebase.dart';
export 'src/config.dart';
export 'src/crashlytics.dart';
export 'src/dio_performance.dart';
export 'src/fakes.dart';
export 'src/go_router_screen_tracking.dart';
export 'src/identity.dart';
export 'src/interaction_events.dart';
export 'src/performance.dart';
export 'src/providers.dart'
    show
        analyticsInitializerProvider,
        appAnalyticsProvider,
        appAnalyticsScreenContextProvider,
        appCrashReporterProvider,
        appFactoryFirebaseConfigProvider,
        appInteractionEventsProvider,
        appPerformanceTracerProvider,
        appScreenTrackerProvider,
        appScreenTrackingIssueReporterProvider,
        appScreenTrackingIssueSinkProvider,
        appTelemetryIdentityProvider,
        crashlyticsCollectionInitializerProvider,
        crashlyticsInitializerProvider,
        firebasePerformanceDioInterceptorsProvider,
        goRouterScreenResolverProvider,
        goRouterScreenTrackingProvider,
        performanceInitializerProvider;
export 'src/screen_context.dart';
export 'src/screen_tracking_issues.dart';
