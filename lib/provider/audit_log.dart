import 'package:kashakeibo/features/audit_log/audit_log_client.dart'
    as audit_log_client;
import 'package:kashakeibo/provider/firebase_user.dart';
import 'package:kashakeibo/provider/image.dart';
import 'package:kashakeibo/provider/purchase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'audit_log.g.dart';

/// 本人の操作履歴を Worker から新しい順に取得する操作。
typedef FetchAuditLogs = Future<List<audit_log_client.AuditLog>> Function();

/// 操作履歴の取得操作。テストでは差し替える。
final fetchAuditLogsProvider = Provider<FetchAuditLogs>(
  (ref) => fetchAuditLogs,
);

/// 操作履歴を Worker から取得する。冪等 (読み取りのみ)。
Future<List<audit_log_client.AuditLog>> fetchAuditLogs() => callWorkerApi(
  workerApiCall:
      ({
        required firebaseIdToken,
        required firebaseAppCheckToken,
        required httpClient,
      }) => audit_log_client.fetchAuditLogs(
        firebaseIdToken: firebaseIdToken,
        firebaseAppCheckToken: firebaseAppCheckToken,
        httpClient: httpClient,
      ),
);

/// 履歴画面に表示する操作履歴 (新しい順)。
///
/// 履歴の正は明細の変更を写した BigQuery の changelog で、件数の上限と無料プランの
/// 期間制限は Worker が適用済みの結果を返す (lib/features/audit_log/audit_log_client.dart)。
/// Firestore の snapshot listener で購読していた頃のリアルタイム反映は API 化で失われるため、
/// 画面を開いたまま行った操作は [refresh] (履歴画面の pull-to-refresh) で取り直す。
@riverpod
class AuditLogs extends _$AuditLogs {
  @override
  Future<List<audit_log_client.AuditLog>> build() {
    // 課金状態が変わったら取り直す。期間制限を適用するのは Worker のため値自体は使わないが、
    // 依存に加えることで購入・失効のたびに Future が作り直され、画面を開いたままでも
    // 制限後 / 制限なしの一覧に切り替わる。
    ref.watch(isPremiumProvider);
    // サインイン中の uid が変わったら取り直す。
    if (ref.watch(currentUserIDProvider) == null) {
      return Future.value(const []);
    }
    return ref.watch(fetchAuditLogsProvider)();
  }

  /// Worker から取り直す。取得が終わるまで完了しない Future を返し、
  /// pull-to-refresh のインジケータを取得中だけ表示できるようにする。
  ///
  /// 取得中も直前の一覧を保持する (取り直しのたびに一覧が消えないようにするため、
  /// loading へは遷移させない)。冪等 (読み取りのみ)。
  Future<void> refresh() async {
    if (ref.read(currentUserIDProvider) == null) {
      return;
    }
    state = await AsyncValue.guard(() => ref.read(fetchAuditLogsProvider)());
  }
}
