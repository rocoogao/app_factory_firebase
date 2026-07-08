import 'package:dio/dio.dart';
import 'package:firebase_performance_dio/firebase_performance_dio.dart';

Interceptor createFirebasePerformanceDioInterceptor() {
  return DioFirebasePerformanceInterceptor();
}
