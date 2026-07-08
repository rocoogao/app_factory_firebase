import 'analytics.dart';
import 'crashlytics.dart';

abstract class AppTelemetryIdentity {
  Future<void> setIdentity(
    String? userId, {
    Map<String, String> properties = const <String, String>{},
  });

  Future<void> clearIdentity({
    Iterable<String> propertyNames = const <String>[],
  });
}

class DefaultAppTelemetryIdentity implements AppTelemetryIdentity {
  DefaultAppTelemetryIdentity({
    required AppAnalytics analytics,
    required AppCrashReporter crashReporter,
  }) : _analytics = analytics,
       _crashReporter = crashReporter;

  final AppAnalytics _analytics;
  final AppCrashReporter _crashReporter;

  @override
  Future<void> setIdentity(
    String? userId, {
    Map<String, String> properties = const <String, String>{},
  }) async {
    if (userId == null) {
      await clearIdentity(propertyNames: properties.keys);
      return;
    }

    await Future.wait(<Future<void>>[
      _analytics.setUserId(userId),
      _crashReporter.setUserIdentifier(userId),
      for (final MapEntry<String, String> entry in properties.entries)
        _analytics.setUserProperty(name: entry.key, value: entry.value),
    ]);
  }

  @override
  Future<void> clearIdentity({
    Iterable<String> propertyNames = const <String>[],
  }) async {
    await Future.wait(<Future<void>>[
      _analytics.setUserId(null),
      _crashReporter.setUserIdentifier(null),
      for (final String propertyName in propertyNames)
        _analytics.setUserProperty(name: propertyName, value: null),
    ]);
  }
}
