/// 無料プランで振り返れる履歴の範囲 (「全期間の履歴」をプレミアム特典として成立させるための上限)。
///
/// 表示できるのは表示時点の月を含む直近 [freePlanHistoryMonthCount] ヶ月。
/// それより古い月へ月送りしようとした無料プランのユーザーにはペイウォールを表示する (features/monthly)。
/// 月送り以外に過去へ届く経路 (features/transaction_search の検索・features/audit_log の操作履歴) にも
/// [oldestFreePlanHistoryDateTime] で同じ下限を適用し、制限の迂回経路を作らない。
/// 履歴は LLM 原価が発生しない経路のためサーバー側では強制せず、UI ガードだけで守る
/// (`.claude/rules/firestore-rules-simplicity.md` のプレミアム機能制限の方針)。
library;

/// 無料プランで表示できる月数 (当月を含む)。
///
/// 先月との比較 (家計の振り返りの基本動作) までは無料で成立させ、
/// それより長期の記録価値をプレミアム特典「全期間の履歴」に置く値として、当月 + 過去 2 ヶ月にしている。
const freePlanHistoryMonthCount = 3;

/// 無料プランで振り返れる最古の日時 (今日 [now] の月を含む直近 [freePlanHistoryMonthCount] ヶ月の先頭)。
///
/// 月単位で判定する月次画面 ([isMonthWithinFreePlanHistory]) と同じ境界を、日時で絞り込む画面
/// (検索・操作履歴) が使えるように日時で表したもの。
DateTime oldestFreePlanHistoryDateTime({required DateTime now}) =>
    DateTime(now.year, now.month - (freePlanHistoryMonthCount - 1));

/// [now] から次の月初 (端末ローカル) までの残り時間。
///
/// [oldestFreePlanHistoryDateTime] の下限が変わるのは月初のため、画面を開いたまま月をまたぐと
/// build 時に計算した下限が前月のまま残る。画面はこの時間で Timer を張り、
/// 発火時に下限を計算し直す (features/transaction_search)。
Duration durationUntilNextMonthStart({required DateTime now}) =>
    DateTime(now.year, now.month + 1).difference(now);

/// [month] が無料プランで表示できる範囲 (今日 [now] の月を含む直近 [freePlanHistoryMonthCount] ヶ月) 内かどうか。
/// 未来の月は制限しない (先の月へ送ってもプレミアム特典を先取りしない)。
bool isMonthWithinFreePlanHistory({
  required DateTime month,
  required DateTime now,
}) => !DateTime(
  month.year,
  month.month,
).isBefore(oldestFreePlanHistoryDateTime(now: now));
