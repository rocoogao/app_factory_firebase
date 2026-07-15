import 'dart:async';

import 'package:flutter/foundation.dart';

enum AppScreenTrackingIssueType {
  unmappedRoute,
  resolverFailure,
  invalidScreenName,
  missingScreenContext,
  screenViewFailure,
  interactionEventFailure,
}

class AppScreenTrackingIssue {
  const AppScreenTrackingIssue({
    required this.type,
    required this.message,
    this.routeName,
    this.screenName,
    this.error,
    this.stackTrace,
  });

  final AppScreenTrackingIssueType type;
  final String message;
  final String? routeName;
  final String? screenName;
  final Object? error;
  final StackTrace? stackTrace;

  String get dedupeKey =>
      <String>[type.name, routeName ?? '', screenName ?? '', message].join('|');

  @override
  String toString() {
    return '[AppFactoryFirebase] ${type.name}: $message'
        '${routeName == null ? '' : ' route=$routeName'}'
        '${screenName == null ? '' : ' screen=$screenName'}'
        '${error == null ? '' : ' error=$error'}';
  }
}

typedef AppScreenTrackingIssueSink =
    FutureOr<void> Function(AppScreenTrackingIssue issue);

class AppScreenTrackingIssueReporter {
  AppScreenTrackingIssueReporter({required AppScreenTrackingIssueSink sink})
    : _sink = sink;

  factory AppScreenTrackingIssueReporter.debug() {
    return AppScreenTrackingIssueReporter(
      sink: (AppScreenTrackingIssue issue) {
        debugPrint(issue.toString());
        if (issue.stackTrace case final StackTrace stackTrace) {
          debugPrint(stackTrace.toString());
        }
      },
    );
  }

  final AppScreenTrackingIssueSink _sink;
  final Set<String> _reportedIssueKeys = <String>{};

  void report(AppScreenTrackingIssue issue) {
    if (!_reportedIssueKeys.add(issue.dedupeKey)) {
      return;
    }

    try {
      final FutureOr<void> result = _sink(issue);
      if (result is Future<void>) {
        unawaited(
          result.catchError((Object error, StackTrace stackTrace) {
            _debugSinkFailure(error, stackTrace);
          }),
        );
      }
    } catch (error, stackTrace) {
      _debugSinkFailure(error, stackTrace);
    }
  }

  void _debugSinkFailure(Object error, StackTrace stackTrace) {
    debugPrint(
      '[AppFactoryFirebase] Screen tracking issue sink failed: '
      '$error\n$stackTrace',
    );
  }
}
