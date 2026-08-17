import 'package:firebase_analytics/firebase_analytics.dart';

/// Analyticsイベントを記録する処理。テストでは呼び出し先を差し替える。
typedef LogAnalyticsEvent =
    Future<void> Function({
      required String name,
      Map<String, Object>? parameters,
    });

/// Firebase Analyticsへイベントを記録する。
///
/// ユーザー操作ごとの記録は副作用であり、同じ操作を区別するため冪等にはしない。
Future<void> recordAnalyticsEvent({
  required String name,
  Map<String, Object>? parameters,
}) => FirebaseAnalytics.instance.logEvent(name: name, parameters: parameters);
