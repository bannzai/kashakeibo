import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/provider/firebase_user.dart';
import 'package:kashakeibo/provider/purchase.dart';

/// サインイン済みであることを保証する resolver。
///
/// 未サインイン (初回起動) の場合は匿名サインインを実行し、完了するまで
/// ローディングを表示する。登録なしで使い始められるようにするための
/// 匿名認証スタート (documents/adr/0001-tech-stack.md)。
/// サインイン済みの uid が決まる (変わる) たびに RevenueCat の app user ID を同じ uid に揃え、
/// Worker が uid で entitlement を検証できるようにする (workers/image/src/entitlement.ts)。
class SignInResolver extends HookConsumerWidget {
  /// サインイン完了後に表示する画面。
  final Widget child;

  const SignInResolver({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseUserAsync = ref.watch(firebaseUserChangesProvider);
    final ensureAnonymousSignIn = ref.watch(ensureAnonymousSignInProvider);
    final logInPurchases = ref.watch(logInPurchasesProvider);
    final signInError = useState<Object?>(null);

    // Widget 内部で完結するローカル関数。サインイン失敗時のエラーを保持して
    // リトライボタンからも再実行できるようにする。
    Future<void> signInAnonymouslyIfNeeded() async {
      try {
        await ensureAnonymousSignIn();
        signInError.value = null;
      } catch (error) {
        signInError.value = error;
      }
    }

    // 初回起動に加え、アカウント削除で UID が null へ戻った時にも匿名認証する。
    // uid が決まったら RevenueCat の app user ID を揃える (同じ uid での再実行は SDK 側で no-op)。
    // 失敗しても課金以外の機能は使えるため、サインインのエラー表示には含めずログに残す。
    final firebaseUserID = firebaseUserAsync.valueOrNull?.uid;
    useEffect(() {
      if (firebaseUserID == null) {
        signInAnonymouslyIfNeeded();
      } else {
        logInPurchases(appUserID: firebaseUserID).catchError((Object error) {
          debugPrint('RevenueCat の app user ID を揃えられませんでした: $error');
        });
      }
      return null;
    }, [firebaseUserID]);

    final firebaseUserChangesError = firebaseUserAsync.whenOrNull(
      error: (error, _) => error,
    );
    final error = signInError.value ?? firebaseUserChangesError;
    if (error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // エラーメッセージは加工せずそのまま表示する (.claude/rules/coding-conventions.md)。
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(error.toString()),
              ),
              FilledButton(
                onPressed: signInAnonymouslyIfNeeded,
                child: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      );
    }

    if (firebaseUserAsync.valueOrNull == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return child;
  }
}
