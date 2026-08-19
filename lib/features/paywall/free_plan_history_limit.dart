/// 無料プランで振り返れる履歴の範囲 (「全期間の履歴」をプレミアム特典として成立させるための上限)。
///
/// 表示できるのは表示時点の月を含む直近 [freePlanHistoryMonthCount] ヶ月。
/// それより古い月へ月送りしようとした無料プランのユーザーにはペイウォールを表示する (features/monthly)。
/// 履歴は LLM 原価が発生しない経路のためサーバー側では強制せず、UI ガードだけで守る
/// (`.claude/rules/firestore-rules-simplicity.md` のプレミアム機能制限の方針)。
library;

/// 無料プランで表示できる月数 (当月を含む)。
///
/// 先月との比較 (家計の振り返りの基本動作) までは無料で成立させ、
/// それより長期の記録価値をプレミアム特典「全期間の履歴」に置く値として、当月 + 過去 2 ヶ月にしている。
const freePlanHistoryMonthCount = 3;

/// [month] が無料プランで表示できる範囲 (今日 [now] の月を含む直近 [freePlanHistoryMonthCount] ヶ月) 内かどうか。
/// 未来の月は制限しない (先の月へ送ってもプレミアム特典を先取りしない)。
bool isMonthWithinFreePlanHistory({
  required DateTime month,
  required DateTime now,
}) {
  final oldestFreeMonth = DateTime(
    now.year,
    now.month - (freePlanHistoryMonthCount - 1),
  );
  return !DateTime(month.year, month.month).isBefore(oldestFreeMonth);
}
