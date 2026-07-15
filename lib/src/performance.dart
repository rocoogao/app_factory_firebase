import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

abstract class AppTraceHandle {
  void setMetric(String name, int value);

  void incrementMetric(String name, int incrementBy);

  void putAttribute(String name, String value);

  Future<void> stop();
}

abstract class AppPerformanceTracer {
  Future<void> setCollectionEnabled(bool enabled);

  Future<AppTraceHandle> startTrace(String name);

  Future<T> traceAsync<T>(
    String name,
    Future<T> Function(AppTraceHandle trace) action,
  ) async {
    AppTraceHandle handle;
    try {
      handle = await startTrace(name);
    } catch (error, stackTrace) {
      _debugTraceFailure('start', name, error, stackTrace);
      handle = const _NoopAppTraceHandle();
    }

    try {
      return await action(handle);
    } catch (error) {
      try {
        handle.putAttribute('error', 'true');
        handle.putAttribute('error_message', error.toString());
      } catch (traceError, stackTrace) {
        _debugTraceFailure('annotate', name, traceError, stackTrace);
      }
      rethrow;
    } finally {
      try {
        await handle.stop();
      } catch (error, stackTrace) {
        _debugTraceFailure('stop', name, error, stackTrace);
      }
    }
  }
}

class _NoopAppTraceHandle implements AppTraceHandle {
  const _NoopAppTraceHandle();

  @override
  void incrementMetric(String name, int incrementBy) {}

  @override
  void putAttribute(String name, String value) {}

  @override
  void setMetric(String name, int value) {}

  @override
  Future<void> stop() async {}
}

void _debugTraceFailure(
  String operation,
  String traceName,
  Object error,
  StackTrace stackTrace,
) {
  assert(() {
    debugPrint(
      'Firebase trace "$traceName" failed to $operation: '
      '$error\n$stackTrace',
    );
    return true;
  }());
}

class FirebaseAppTraceHandle implements AppTraceHandle {
  FirebaseAppTraceHandle(this._trace);

  final Trace _trace;

  @override
  void setMetric(String name, int value) {
    _trace.setMetric(name, value);
  }

  @override
  void incrementMetric(String name, int incrementBy) {
    _trace.incrementMetric(name, incrementBy);
  }

  @override
  void putAttribute(String name, String value) {
    _trace.putAttribute(name, value);
  }

  @override
  Future<void> stop() {
    return _trace.stop();
  }
}

class FirebaseAppPerformanceTracer extends AppPerformanceTracer {
  FirebaseAppPerformanceTracer({FirebasePerformance? performance})
    : _performance = performance ?? FirebasePerformance.instance;

  final FirebasePerformance _performance;

  @override
  Future<void> setCollectionEnabled(bool enabled) {
    return _performance.setPerformanceCollectionEnabled(enabled);
  }

  @override
  Future<AppTraceHandle> startTrace(String name) async {
    final Trace trace = _performance.newTrace(name);
    await trace.start();
    return FirebaseAppTraceHandle(trace);
  }
}
