import 'analytics.dart';
import 'screen_tracking_issues.dart';

abstract final class AppAnalyticsScreenNames {
  static const String unknown = 'unknown';
}

String normalizeAppAnalyticsScreenName(String screenName) {
  final String normalized = screenName.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(
      screenName,
      'screenName',
      'Screen name must not be empty.',
    );
  }
  return normalized;
}

class AppAnalyticsScreenContext {
  String? _screenName;

  String? get screenName => _screenName;

  void update(String screenName) {
    _screenName = normalizeAppAnalyticsScreenName(screenName);
  }
}

class AppScreenTracker {
  AppScreenTracker({
    required AppAnalytics analytics,
    required AppAnalyticsScreenContext screenContext,
    AppScreenTrackingIssueReporter? issueReporter,
  }) : _analytics = analytics,
       _screenContext = screenContext,
       _issueReporter = issueReporter ?? AppScreenTrackingIssueReporter.debug();

  final AppAnalytics _analytics;
  final AppAnalyticsScreenContext _screenContext;
  final AppScreenTrackingIssueReporter _issueReporter;

  Future<void> trackScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object?> parameters = const <String, Object?>{},
  }) async {
    final String normalizedScreenName;
    try {
      normalizedScreenName = normalizeAppAnalyticsScreenName(screenName);
    } catch (error, stackTrace) {
      _issueReporter.report(
        AppScreenTrackingIssue(
          type: AppScreenTrackingIssueType.invalidScreenName,
          message: 'Screen view was ignored because its name is invalid.',
          screenName: screenName,
          error: error,
          stackTrace: stackTrace,
        ),
      );
      return;
    }

    _screenContext.update(normalizedScreenName);
    try {
      await _analytics.logScreenView(
        screenName: normalizedScreenName,
        screenClass: screenClass,
        parameters: parameters,
      );
    } catch (error, stackTrace) {
      _issueReporter.report(
        AppScreenTrackingIssue(
          type: AppScreenTrackingIssueType.screenViewFailure,
          message: 'Screen view upload failed.',
          screenName: normalizedScreenName,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
