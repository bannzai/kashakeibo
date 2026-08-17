import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Firebase Analytics へイベントを送る関数。
typedef LogAnalyticsEvent = Future<void> Function({required String name});

/// Firebase Analytics のイベント送信機能。
final logAnalyticsEventProvider = Provider<LogAnalyticsEvent>(
  (ref) => logAnalyticsEvent,
);

/// 指定名のイベントを Firebase Analytics へ送信する。
Future<void> logAnalyticsEvent({required String name}) =>
    FirebaseAnalytics.instance.logEvent(name: name);
