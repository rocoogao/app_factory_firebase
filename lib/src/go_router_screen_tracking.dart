import 'dart:async';

import 'package:go_router/go_router.dart';

import 'screen_context.dart';
import 'screen_tracking_issues.dart';

class AppResolvedScreen {
  const AppResolvedScreen({
    required this.screenName,
    this.screenClass,
    this.parameters = const <String, Object?>{},
    this.trackingKey,
  });

  final String screenName;
  final String? screenClass;
  final Map<String, Object?> parameters;
  final String? trackingKey;
}

sealed class AppScreenResolution {
  const AppScreenResolution();
}

final class AppTrackedScreen extends AppScreenResolution {
  const AppTrackedScreen(this.screen);

  final AppResolvedScreen screen;
}

final class AppIgnoredScreen extends AppScreenResolution {
  const AppIgnoredScreen();
}

final class AppUnmappedScreen extends AppScreenResolution {
  const AppUnmappedScreen({this.reason});

  final String? reason;
}

typedef AppGoRouterScreenResolver =
    AppScreenResolution Function(GoRouterState state);

AppScreenResolution defaultAppGoRouterScreenResolver(GoRouterState state) {
  final String? screenName = state.name ?? state.fullPath;
  return screenName == null
      ? const AppUnmappedScreen(reason: 'Route has no name or fullPath.')
      : AppTrackedScreen(AppResolvedScreen(screenName: screenName));
}

class AppGoRouterScreenTracking {
  AppGoRouterScreenTracking({
    required GoRouter router,
    required AppScreenTracker screenTracker,
    AppScreenTrackingIssueReporter? issueReporter,
    AppGoRouterScreenResolver screenResolver = defaultAppGoRouterScreenResolver,
  }) : _router = router,
       _screenTracker = screenTracker,
       _issueReporter = issueReporter ?? AppScreenTrackingIssueReporter.debug(),
       _screenResolver = screenResolver {
    _router.routerDelegate.addListener(_syncScreen);
    _syncScreen();
  }

  final GoRouter _router;
  final AppScreenTracker _screenTracker;
  final AppScreenTrackingIssueReporter _issueReporter;
  final AppGoRouterScreenResolver _screenResolver;

  String? _lastFingerprint;

  void dispose() {
    _router.routerDelegate.removeListener(_syncScreen);
  }

  void _syncScreen() {
    final GoRouterState? state = _readState();
    if (state == null) {
      return;
    }
    final AppResolvedScreen? resolvedScreen = _resolveScreen(state);
    if (resolvedScreen == null) {
      return;
    }

    final String screenName = resolvedScreen.screenName;
    final String fingerprintScreenName = screenName.trim();
    final String? trackingKey = resolvedScreen.trackingKey;
    final String fingerprint = trackingKey == null
        ? '${state.uri.path}|${state.pageKey}|$fingerprintScreenName'
        : '$trackingKey|$fingerprintScreenName';
    if (_lastFingerprint == fingerprint) {
      return;
    }
    _lastFingerprint = fingerprint;

    unawaited(_trackScreenView(resolvedScreen));
  }

  AppResolvedScreen? _resolveScreen(GoRouterState state) {
    final AppScreenResolution resolution;
    try {
      resolution = _screenResolver(state);
    } catch (error, stackTrace) {
      _issueReporter.report(
        AppScreenTrackingIssue(
          type: AppScreenTrackingIssueType.resolverFailure,
          message: 'GoRouter screen resolver failed.',
          routeName: state.name ?? state.fullPath ?? state.uri.path,
          error: error,
          stackTrace: stackTrace,
        ),
      );
      return null;
    }

    switch (resolution) {
      case AppIgnoredScreen():
        return null;
      case AppUnmappedScreen(:final String? reason):
        _issueReporter.report(
          AppScreenTrackingIssue(
            type: AppScreenTrackingIssueType.unmappedRoute,
            message: reason ?? 'Route could not be mapped to a screen.',
            routeName: state.name ?? state.fullPath ?? state.uri.path,
          ),
        );
        return null;
      case AppTrackedScreen(:final AppResolvedScreen screen):
        return AppResolvedScreen(
          screenName: screen.screenName,
          screenClass: screen.screenClass,
          parameters: screen.parameters,
          trackingKey: _normalizeTrackingKey(screen.trackingKey),
        );
    }
  }

  String? _normalizeTrackingKey(String? trackingKey) {
    final String? normalized = trackingKey?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  GoRouterState? _readState() {
    try {
      return _router.state;
    } on StateError {
      return null;
    }
  }

  Future<void> _trackScreenView(AppResolvedScreen screen) async {
    await _screenTracker.trackScreenView(
      screenName: screen.screenName,
      screenClass: screen.screenClass,
      parameters: screen.parameters,
    );
  }
}
