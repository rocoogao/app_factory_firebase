import 'analytics.dart';
import 'screen_context.dart';
import 'screen_tracking_issues.dart';

abstract final class AppInteractionEventNames {
  static const String clickElement = 'click_element';
  static const String viewPop = 'view_pop';
}

class AppInteractionEvents {
  AppInteractionEvents({
    required AppAnalytics analytics,
    required AppAnalyticsScreenContext screenContext,
    AppScreenTrackingIssueReporter? issueReporter,
  }) : _analytics = analytics,
       _screenContext = screenContext,
       _issueReporter = issueReporter ?? AppScreenTrackingIssueReporter.debug();

  final AppAnalytics _analytics;
  final AppAnalyticsScreenContext _screenContext;
  final AppScreenTrackingIssueReporter _issueReporter;

  Future<void> clickElement({
    required String elementId,
    required String elementName,
    String? screenName,
  }) async {
    await _logInteractionEvent(
      AppInteractionEventNames.clickElement,
      parameters: _withScreenName(<String, Object?>{
        'element_id': elementId,
        'element_name': elementName,
      }, screenName),
    );
  }

  Future<void> viewPop({
    required String popId,
    required String popName,
    String? screenName,
  }) async {
    await _logInteractionEvent(
      AppInteractionEventNames.viewPop,
      parameters: _withScreenName(<String, Object?>{
        'pop_id': popId,
        'pop_name': popName,
      }, screenName),
    );
  }

  Future<void> _logInteractionEvent(
    String eventName, {
    required Map<String, Object?> parameters,
  }) async {
    try {
      await _analytics.logEvent(eventName, parameters: parameters);
    } catch (error, stackTrace) {
      _issueReporter.report(
        AppScreenTrackingIssue(
          type: AppScreenTrackingIssueType.interactionEventFailure,
          message: 'Interaction event "$eventName" upload failed.',
          screenName: parameters['screen_name'] as String?,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Map<String, Object?> _withScreenName(
    Map<String, Object?> parameters,
    String? screenName,
  ) {
    final String? candidate = screenName ?? _screenContext.screenName;
    final String resolvedScreenName;
    if (candidate == null) {
      _issueReporter.report(
        const AppScreenTrackingIssue(
          type: AppScreenTrackingIssueType.missingScreenContext,
          message: 'Interaction used the unknown screen fallback.',
          screenName: AppAnalyticsScreenNames.unknown,
        ),
      );
      resolvedScreenName = AppAnalyticsScreenNames.unknown;
    } else {
      try {
        resolvedScreenName = normalizeAppAnalyticsScreenName(candidate);
      } catch (error, stackTrace) {
        _issueReporter.report(
          AppScreenTrackingIssue(
            type: AppScreenTrackingIssueType.invalidScreenName,
            message:
                'Interaction used the unknown screen fallback because '
                'its screen name is invalid.',
            screenName: candidate,
            error: error,
            stackTrace: stackTrace,
          ),
        );
        return <String, Object?>{
          'screen_name': AppAnalyticsScreenNames.unknown,
          ...parameters,
        };
      }
    }
    return <String, Object?>{'screen_name': resolvedScreenName, ...parameters};
  }
}
