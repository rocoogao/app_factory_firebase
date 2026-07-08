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
  );
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

class FirebaseAppPerformanceTracer implements AppPerformanceTracer {
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

  @override
  Future<T> traceAsync<T>(
    String name,
    Future<T> Function(AppTraceHandle trace) action,
  ) async {
    final AppTraceHandle handle = await startTrace(name);
    try {
      return await action(handle);
    } catch (error) {
      handle.putAttribute('error', 'true');
      handle.putAttribute('error_message', error.toString());
      rethrow;
    } finally {
      try {
        await handle.stop();
      } catch (error, stackTrace) {
        assert(() {
          debugPrint(
            'Failed to stop Firebase trace "$name": '
            '$error\n$stackTrace',
          );
          return true;
        }());
      }
    }
  }
}
