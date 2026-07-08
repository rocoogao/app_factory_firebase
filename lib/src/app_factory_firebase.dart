import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'providers.dart';

class AppFactoryFirebase {
  const AppFactoryFirebase._();

  static Future<AppFactoryFirebaseInitializeResult> initialize(
    ProviderContainer container,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();

    final AppFactoryFirebaseConfig config = container.read(
      appFactoryFirebaseConfigProvider,
    );

    final List<String> initializationErrors = <String>[];
    final bool usedExistingFirebaseApp = Firebase.apps.isNotEmpty;
    bool firebaseInitialized = usedExistingFirebaseApp;
    if (!firebaseInitialized) {
      firebaseInitialized = await _runNonFatal(
        'Firebase.initializeApp',
        initializationErrors,
        () async {
          await Firebase.initializeApp(options: config.options);
          return true;
        },
        fallback: false,
      );
    }

    bool crashlyticsCollectionEnabled = false;
    bool flutterErrorsCaptured = false;
    if (firebaseInitialized && config.enableCrashlytics) {
      flutterErrorsCaptured = await _runNonFatal(
        'Crashlytics Flutter error capture',
        initializationErrors,
        () async {
          if (!config.captureFlutterErrors) {
            return false;
          }
          container.read(crashlyticsInitializerProvider);
          return true;
        },
        fallback: false,
      );

      crashlyticsCollectionEnabled = await _runNonFatal(
        'Crashlytics collection initializer',
        initializationErrors,
        () => container.read(crashlyticsCollectionInitializerProvider.future),
        fallback: false,
      );
    }

    bool performanceCollectionEnabled = false;
    if (firebaseInitialized && config.enablePerformance) {
      performanceCollectionEnabled = await _runNonFatal(
        'Performance initializer',
        initializationErrors,
        () => container.read(performanceInitializerProvider.future),
        fallback: false,
      );
    }

    bool analyticsCollectionEnabled = false;
    if (firebaseInitialized && config.enableAnalytics) {
      analyticsCollectionEnabled = await _runNonFatal(
        'Analytics initializer',
        initializationErrors,
        () => container.read(analyticsInitializerProvider.future),
        fallback: false,
      );
    }

    final AppFactoryFirebaseInitializeResult result =
        AppFactoryFirebaseInitializeResult(
          firebaseInitialized: firebaseInitialized,
          usedExistingFirebaseApp: usedExistingFirebaseApp,
          analyticsEnabled: config.enableAnalytics,
          crashlyticsEnabled: config.enableCrashlytics,
          performanceEnabled: config.enablePerformance,
          analyticsCollectionEnabled: analyticsCollectionEnabled,
          crashlyticsCollectionEnabled: crashlyticsCollectionEnabled,
          performanceCollectionEnabled: performanceCollectionEnabled,
          flutterErrorsCaptured: flutterErrorsCaptured,
          initializationErrors: initializationErrors,
        );

    if (config.debugLogInitializeResult) {
      debugPrint(result.toString());
    }

    return result;
  }

  static Future<T> _runNonFatal<T>(
    String label,
    List<String> initializationErrors,
    Future<T> Function() action, {
    required T fallback,
  }) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      final String message = '$label failed: $error';
      initializationErrors.add(message);
      debugPrint('[AppFactoryFirebase] $message\n$stackTrace');
      return fallback;
    }
  }
}

Future<AppFactoryFirebaseInitializeResult> runAppWithFirebase({
  required AppFactoryFirebaseConfig config,
  required Widget child,
  // Riverpod 3 accepts Override objects here, but the Override type is not
  // publicly exported by flutter_riverpod. Keep the public API usable while
  // letting ProviderContainer's contextual type validate the expanded items.
  List<dynamic> overrides = const <dynamic>[],
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  final ProviderContainer container = ProviderContainer(
    overrides: [
      appFactoryFirebaseConfigProvider.overrideWithValue(config),
      ...overrides,
    ],
  );

  final AppFactoryFirebaseInitializeResult result =
      await AppFactoryFirebase.initialize(container);

  runApp(UncontrolledProviderScope(container: container, child: child));

  return result;
}
