import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

abstract class AppAnalytics {
  void setContextProperties(Map<String, String> properties);

  void setContextProperty(String key, String value);

  Future<void> setDefaultEventParameters(Map<String, Object?> parameters);

  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const <String, Object?>{},
  });

  Future<void> logScreenView({required String screenName});

  Future<void> setUserProperty({required String name, required String? value});

  Future<void> setUserId(String? userId);
}

class FirebaseAppAnalytics implements AppAnalytics {
  FirebaseAppAnalytics({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;
  final Map<String, String> _contextProperties = <String, String>{};
  final Map<String, Object?> _defaultEventParameters = <String, Object?>{};

  @override
  void setContextProperties(Map<String, String> properties) {
    _contextProperties.addAll(properties);
  }

  @override
  void setContextProperty(String key, String value) {
    _contextProperties[key] = value;
  }

  @override
  Future<void> setDefaultEventParameters(
    Map<String, Object?> parameters,
  ) async {
    for (final MapEntry<String, Object?> entry in parameters.entries) {
      if (entry.value == null) {
        _defaultEventParameters.remove(entry.key);
      } else {
        _defaultEventParameters[entry.key] = entry.value;
      }
    }

    await _analytics.setDefaultEventParameters(
      sanitizeFirebaseParameters(_defaultEventParameters),
    );
  }

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) {
    final Map<String, Object?> mergedParameters = <String, Object?>{
      ..._contextProperties,
      ...parameters,
    };

    return _analytics.logEvent(
      name: name,
      parameters: sanitizeFirebaseParameters(mergedParameters),
    );
  }

  @override
  Future<void> logScreenView({required String screenName}) {
    return _analytics.logScreenView(
      screenName: screenName,
      parameters: sanitizeFirebaseParameters(_contextProperties),
    );
  }

  @override
  Future<void> setUserProperty({required String name, required String? value}) {
    return _analytics.setUserProperty(name: name, value: value);
  }

  @override
  Future<void> setUserId(String? userId) {
    return _analytics.setUserId(id: userId);
  }
}

Map<String, Object>? sanitizeFirebaseParameters(
  Map<String, Object?> parameters,
) {
  final Map<String, Object> sanitized = <String, Object>{};

  for (final MapEntry<String, Object?> entry in parameters.entries) {
    final Object? value = entry.value;
    switch (value) {
      case String():
        sanitized[entry.key] = value;
      case int():
        sanitized[entry.key] = value;
      case double():
        sanitized[entry.key] = value;
      case bool():
        sanitized[entry.key] = value ? 'true' : 'false';
      case DateTime():
        sanitized[entry.key] = value.toIso8601String();
      case null:
        break;
      default:
        assert(() {
          debugPrint(
            '[AppFactoryFirebase] Dropped unsupported Firebase Analytics '
            'parameter "${entry.key}" (${value.runtimeType}).',
          );
          return true;
        }());
    }
  }

  return sanitized.isEmpty ? null : sanitized;
}
