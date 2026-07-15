import 'analytics.dart';
import 'crashlytics.dart';
import 'performance.dart';

class FakeAnalyticsEvent {
  const FakeAnalyticsEvent({required this.name, required this.parameters});

  final String name;
  final Map<String, Object?> parameters;
}

class FakeScreenView {
  const FakeScreenView({
    required this.screenName,
    required this.parameters,
    this.screenClass,
  });

  final String screenName;
  final String? screenClass;
  final Map<String, Object?> parameters;
}

class FakeUserProperty {
  const FakeUserProperty({required this.name, required this.value});

  final String name;
  final String? value;
}

class FakeAppAnalytics implements AppAnalytics {
  final List<FakeAnalyticsEvent> events = <FakeAnalyticsEvent>[];
  final List<FakeScreenView> screenViews = <FakeScreenView>[];
  final List<FakeUserProperty> userProperties = <FakeUserProperty>[];
  final List<String?> userIds = <String?>[];
  final Map<String, String> contextProperties = <String, String>{};
  final Map<String, Object?> defaultEventParameters = <String, Object?>{};

  @override
  void setContextProperties(Map<String, String> properties) {
    contextProperties.addAll(properties);
  }

  @override
  void setContextProperty(String key, String value) {
    contextProperties[key] = value;
  }

  @override
  Future<void> setDefaultEventParameters(
    Map<String, Object?> parameters,
  ) async {
    for (final MapEntry<String, Object?> entry in parameters.entries) {
      if (entry.value == null) {
        defaultEventParameters.remove(entry.key);
      } else {
        defaultEventParameters[entry.key] = entry.value;
      }
    }
  }

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) async {
    events.add(
      FakeAnalyticsEvent(
        name: name,
        parameters: <String, Object?>{...contextProperties, ...parameters},
      ),
    );
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object?> parameters = const <String, Object?>{},
  }) async {
    screenViews.add(
      FakeScreenView(
        screenName: screenName,
        screenClass: screenClass,
        parameters: <String, Object?>{...contextProperties, ...parameters},
      ),
    );
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    userProperties.add(FakeUserProperty(name: name, value: value));
  }

  @override
  Future<void> setUserId(String? userId) async {
    userIds.add(userId);
  }
}

class FakeCrashError {
  const FakeCrashError({
    required this.error,
    required this.stackTrace,
    required this.fatal,
  });

  final Object error;
  final StackTrace stackTrace;
  final bool fatal;
}

class FakeAppCrashReporter implements AppCrashReporter {
  final List<String> logs = <String>[];
  final List<FakeCrashError> errors = <FakeCrashError>[];
  final List<String?> userIdentifiers = <String?>[];

  @override
  void log(String message) {
    logs.add(message);
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
  }) async {
    errors.add(
      FakeCrashError(error: error, stackTrace: stackTrace, fatal: fatal),
    );
  }

  @override
  Future<void> setUserIdentifier(String? userId) async {
    userIdentifiers.add(userId);
  }
}

class FakeTraceRecord {
  FakeTraceRecord({required this.name});

  final String name;
  final Map<String, int> metrics = <String, int>{};
  final Map<String, String> attributes = <String, String>{};
  bool stopped = false;
}

class FakeAppTraceHandle implements AppTraceHandle {
  FakeAppTraceHandle(this.record);

  final FakeTraceRecord record;

  @override
  void setMetric(String name, int value) {
    record.metrics[name] = value;
  }

  @override
  void incrementMetric(String name, int incrementBy) {
    record.metrics[name] = (record.metrics[name] ?? 0) + incrementBy;
  }

  @override
  void putAttribute(String name, String value) {
    record.attributes[name] = value;
  }

  @override
  Future<void> stop() async {
    record.stopped = true;
  }
}

class FakeAppPerformanceTracer extends AppPerformanceTracer {
  final List<bool> collectionEnabledValues = <bool>[];
  final List<FakeTraceRecord> traces = <FakeTraceRecord>[];

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    collectionEnabledValues.add(enabled);
  }

  @override
  Future<AppTraceHandle> startTrace(String name) async {
    final FakeTraceRecord record = FakeTraceRecord(name: name);
    traces.add(record);
    return FakeAppTraceHandle(record);
  }
}
