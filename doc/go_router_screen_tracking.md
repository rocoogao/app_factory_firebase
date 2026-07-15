# GoRouter Screen Tracking

This document describes the screen-tracking architecture used by
`app_factory_firebase`. The package treats `go_router` as the navigation source,
`AppScreenTracker` as the single screen-view entry point, and
`AppAnalyticsScreenContext` as the current screen context for interaction
events.

```text
GoRouterState -> Resolver -> AppScreenTracker -> Firebase Analytics
                                  |
                                  v
                       AppAnalyticsScreenContext
                                  |
                                  v
                      click_element / view_pop
```

## Setup

Keep the `GoRouter` instance stable and watch its tracking provider from the app
root.

```dart
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        name: 'home',
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
    ],
  );
});

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    ref.watch(goRouterScreenTrackingProvider(router));

    return MaterialApp.router(routerConfig: router);
  }
}
```

The tracking provider is auto-disposed and removes its Router listener when it
is no longer watched.

The package reports screen views manually. Disable Firebase automatic screen
reporting on both platforms to prevent duplicate `screen_view` events.

```xml
<!-- android/app/src/main/AndroidManifest.xml, inside <application> -->
<meta-data
    android:name="google_analytics_automatic_screen_reporting_enabled"
    android:value="false" />
```

```xml
<!-- ios/Runner/Info.plist -->
<key>FirebaseAutomaticScreenReportingEnabled</key>
<false/>
```

Do not register `FirebaseAnalyticsObserver` on navigators already covered by
the GoRouter tracking provider.

## Screen Resolution

Production apps should keep navigation route names separate from Analytics
screen names. Override `goRouterScreenResolverProvider` with a stable mapping.

```dart
AppScreenResolution resolveAppScreen(GoRouterState state) {
  return switch (state.name) {
    'home' => const AppTrackedScreen(
        AppResolvedScreen(screenName: 'Home'),
      ),
    'historyDetail' => const AppTrackedScreen(
        AppResolvedScreen(screenName: 'HistoryDetail'),
      ),
    'deleteConfirmDialog' => const AppIgnoredScreen(),
    _ => AppTrackedScreen(
        AppResolvedScreen(
          screenName: 'UnmappedRoute',
          parameters: {'route_name': state.name ?? 'unnamed'},
        ),
      ),
  };
}

final screenResolverOverride =
    goRouterScreenResolverProvider.overrideWithValue(resolveAppScreen);
```

Pass this override to the same ProviderContainer used during Firebase
bootstrap.

The three resolution results have different meanings:

- `AppTrackedScreen`: save the screen context and send `screen_view`.
- `AppIgnoredScreen`: intentionally keep the previous screen without reporting
  an issue, typically for dialogs.
- `AppUnmappedScreen`: the route should represent a screen but has no mapping;
  report an `unmappedRoute` issue and preserve the previous screen context.

Because preserving the previous context can attribute interactions on a real
page to the wrong screen, production resolvers should use a tracked
`UnmappedRoute` fallback for page routes. Keep `AppUnmappedScreen` for explicit
diagnostics where retaining the previous context is understood.

Without an override, the default resolver uses `GoRouterState.name` and falls
back to `GoRouterState.fullPath`.

## Screen Metadata

`AppResolvedScreen` can provide additional Firebase screen metadata.

```dart
AppTrackedScreen(
  AppResolvedScreen(
    screenName: 'HistoryDetail',
    screenClass: 'GoRoute',
    parameters: {
      'route_name': state.name ?? 'unnamed',
      'route_path': state.fullPath,
    },
  ),
);
```

Screen names are trimmed. Empty and whitespace-only names are rejected and
reported without interrupting navigation.

## Routing Behavior

The Router binding tracks:

- initial location;
- regular route changes;
- nested routes;
- back navigation;
- `StatefulShellRoute` branch changes;
- Router replacement when the old binding is disposed and a new one is watched.

The current screen context is updated synchronously before the Firebase screen
view completes, so interaction events can immediately use the new screen.

## Deduplication and Query Parameters

The default fingerprint uses the URI path, page key, and trimmed screen name.
Query and fragment-only changes do not send another screen view.

Use `trackingKey` when selected query parameters represent a distinct view.

```dart
AppTrackedScreen(
  AppResolvedScreen(
    screenName: 'Search',
    trackingKey: state.uri.queryParameters['filter'],
  ),
);
```

The screen name remains stable while the tracking key controls whether another
view is emitted.

## Dialogs and Popups

`showDialog` and other Navigator popup routes do not change GoRouter state, so
they keep the underlying screen context. Use `view_pop` for popup exposure and
`click_element` for interactions inside popup content.

If a dialog is modeled as a `GoRoute`, resolve it as `AppIgnoredScreen` when it
must not replace the underlying screen.

```dart
if (state.name == 'deleteConfirmDialog') {
  return const AppIgnoredScreen();
}
```

Do not use `AppUnmappedScreen` for intentional popup exclusion.

## Non-Router Screens

Widgets that are not represented in `go_router`, such as an app-specific
`PageView`, must call the shared tracker when they become active.

```dart
await ref.read(appScreenTrackerProvider).trackScreenView(
  screenName: 'StatisticsOverview',
  screenClass: 'PageView',
);
```

All subsequent interaction events read that screen from
`AppAnalyticsScreenContext`.

## Screen Tracking Issues

Screen tracking is fail-open: resolver, upload, and issue-sink failures never
interrupt navigation or user interactions. The shared Reporter deduplicates
identical issues for its lifetime.

Issue ownership is singular:

- GoRouter tracking reports `resolverFailure` and `unmappedRoute`.
- `AppScreenTracker` reports `invalidScreenName` and `screenViewFailure`.
- interaction events report `missingScreenContext` or
  `interactionEventFailure`; missing context uses `screen_name: unknown`.
- Reporter Sink failures only fall back to debug output and are never reported
  recursively.

Override the Sink to connect issues to the app's logging or crash-reporting
system.

```dart
appScreenTrackingIssueSinkProvider.overrideWith((ref) {
  final AppCrashReporter crashReporter = ref.watch(appCrashReporterProvider);
  return (AppScreenTrackingIssue issue) {
    return crashReporter.recordError(
      issue.error ?? StateError(issue.message),
      issue.stackTrace ?? StackTrace.current,
    );
  };
});
```

Do not send these issues through the same Analytics event pipeline, because a
tracking failure could otherwise report itself recursively.
