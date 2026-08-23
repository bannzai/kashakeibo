// 無料プランの履歴制限の下限日時のテスト。
// 検索・操作履歴の下限は画面側が現在時刻から計算して provider に渡すため、
// 月をまたいだ時に下限が追随することを固定の日時で検証する。
import 'package:flutter_test/flutter_test.dart';
import 'package:kashakeibo/features/paywall/free_plan_history_limit.dart';

void main() {
  group('oldestFreePlanHistoryDateTime', () {
    test('当月を含む直近 freePlanHistoryMonthCount ヶ月の先頭を返す', () {
      expect(
        oldestFreePlanHistoryDateTime(now: DateTime(2026, 8, 31, 23, 59, 59)),
        DateTime(2026, 6),
      );
      expect(
        oldestFreePlanHistoryDateTime(now: DateTime(2026, 9, 1)),
        DateTime(2026, 7),
      );
    });

    test('月をまたぐと下限も1ヶ月ぶん新しくなる', () {
      expect(
        oldestFreePlanHistoryDateTime(now: DateTime(2026, 8, 31, 23, 59, 59)),
        isNot(oldestFreePlanHistoryDateTime(now: DateTime(2026, 9, 1))),
      );
      // 同じ月の中では、日・時刻が変わっても同じ下限を返す (検索の family キャッシュが効く条件)。
      expect(
        oldestFreePlanHistoryDateTime(now: DateTime(2026, 8, 1)),
        oldestFreePlanHistoryDateTime(now: DateTime(2026, 8, 31, 23, 59, 59)),
      );
    });

    test('年をまたぐ場合も前年の月になる', () {
      expect(
        oldestFreePlanHistoryDateTime(now: DateTime(2026, 1, 15)),
        DateTime(2025, 11),
      );
    });
  });

  group('isMonthWithinFreePlanHistory', () {
    test('下限の月は含み、その1ヶ月前は含まない', () {
      expect(
        isMonthWithinFreePlanHistory(
          month: DateTime(2026, 6),
          now: DateTime(2026, 8, 15),
        ),
        isTrue,
      );
      expect(
        isMonthWithinFreePlanHistory(
          month: DateTime(2026, 5),
          now: DateTime(2026, 8, 15),
        ),
        isFalse,
      );
    });

    test('未来の月は制限しない', () {
      expect(
        isMonthWithinFreePlanHistory(
          month: DateTime(2026, 12),
          now: DateTime(2026, 8, 15),
        ),
        isTrue,
      );
    });
  });
}
