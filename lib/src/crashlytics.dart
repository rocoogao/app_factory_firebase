import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

abstract class AppCrashReporter {
  void log(String message);

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
  });

  Future<void> setUserIdentifier(String? userId);
}

class FirebaseAppCrashReporter implements AppCrashReporter {
  FirebaseAppCrashReporter({FirebaseCrashlytics? crashlytics})
    : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _crashlytics;

  @override
  void log(String message) {
    _crashlytics.log(message);
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
  }) {
    return _crashlytics.recordError(error, stackTrace, fatal: fatal);
  }

  @override
  Future<void> setUserIdentifier(String? userId) {
    return _crashlytics.setUserIdentifier(userId ?? '');
  }
}

class FirebaseCrashlyticsFlutterErrorInitializer {
  const FirebaseCrashlyticsFlutterErrorInitializer._();

  static void setup(AppCrashReporter crashReporter) {
    FlutterError.onError = (FlutterErrorDetails details) {
      crashReporter.recordError(
        details.exception,
        details.stack ?? StackTrace.empty,
        fatal: true,
      );

      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };

    PlatformDispatcher.instance.onError =
        (Object error, StackTrace stackTrace) {
          crashReporter.recordError(error, stackTrace, fatal: true);
          return kReleaseMode;
        };
  }
}
