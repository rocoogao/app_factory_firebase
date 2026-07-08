import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AppFactoryFirebaseConfig {
  const AppFactoryFirebaseConfig({
    required this.options,
    this.enableAnalytics = true,
    this.enableCrashlytics = true,
    this.enablePerformance = true,
    this.captureFlutterErrors = true,
    this.collectionInReleaseOnly = true,
    this.analyticsCollectionEnabled,
    this.crashlyticsCollectionEnabled,
    this.performanceCollectionEnabled,
    this.defaultEventParameters = const <String, Object?>{},
    this.contextProperties = const <String, String>{},
    this.debugLogInitializeResult = false,
  });

  final FirebaseOptions options;
  final bool enableAnalytics;
  final bool enableCrashlytics;
  final bool enablePerformance;
  final bool captureFlutterErrors;
  final bool collectionInReleaseOnly;
  final bool? analyticsCollectionEnabled;
  final bool? crashlyticsCollectionEnabled;
  final bool? performanceCollectionEnabled;
  final Map<String, Object?> defaultEventParameters;
  final Map<String, String> contextProperties;
  final bool debugLogInitializeResult;

  bool resolveAnalyticsCollectionEnabled({bool isReleaseMode = kReleaseMode}) {
    return _resolveCollectionEnabled(
      explicitValue: analyticsCollectionEnabled,
      isReleaseMode: isReleaseMode,
    );
  }

  bool resolveCrashlyticsCollectionEnabled({
    bool isReleaseMode = kReleaseMode,
  }) {
    return _resolveCollectionEnabled(
      explicitValue: crashlyticsCollectionEnabled,
      isReleaseMode: isReleaseMode,
    );
  }

  bool resolvePerformanceCollectionEnabled({
    bool isReleaseMode = kReleaseMode,
  }) {
    return _resolveCollectionEnabled(
      explicitValue: performanceCollectionEnabled,
      isReleaseMode: isReleaseMode,
    );
  }

  bool _resolveCollectionEnabled({
    required bool? explicitValue,
    required bool isReleaseMode,
  }) {
    if (explicitValue != null) {
      return explicitValue;
    }
    return collectionInReleaseOnly ? isReleaseMode : true;
  }
}

class AppFactoryFirebaseInitializeResult {
  const AppFactoryFirebaseInitializeResult({
    required this.firebaseInitialized,
    required this.usedExistingFirebaseApp,
    required this.analyticsEnabled,
    required this.crashlyticsEnabled,
    required this.performanceEnabled,
    required this.analyticsCollectionEnabled,
    required this.crashlyticsCollectionEnabled,
    required this.performanceCollectionEnabled,
    required this.flutterErrorsCaptured,
    this.initializationErrors = const <String>[],
  });

  final bool firebaseInitialized;
  final bool usedExistingFirebaseApp;
  final bool analyticsEnabled;
  final bool crashlyticsEnabled;
  final bool performanceEnabled;
  final bool analyticsCollectionEnabled;
  final bool crashlyticsCollectionEnabled;
  final bool performanceCollectionEnabled;
  final bool flutterErrorsCaptured;
  final List<String> initializationErrors;

  @override
  String toString() {
    return 'AppFactoryFirebaseInitializeResult('
        'firebaseInitialized: $firebaseInitialized, '
        'usedExistingFirebaseApp: $usedExistingFirebaseApp, '
        'analyticsEnabled: $analyticsEnabled, '
        'crashlyticsEnabled: $crashlyticsEnabled, '
        'performanceEnabled: $performanceEnabled, '
        'analyticsCollectionEnabled: $analyticsCollectionEnabled, '
        'crashlyticsCollectionEnabled: $crashlyticsCollectionEnabled, '
        'performanceCollectionEnabled: $performanceCollectionEnabled, '
        'flutterErrorsCaptured: $flutterErrorsCaptured, '
        'initializationErrors: $initializationErrors'
        ')';
  }
}
