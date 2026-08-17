import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/provider/account.dart';
import 'package:kashakeibo/provider/firebase_analytics.dart';
import 'package:kashakeibo/provider/firebase_user.dart';
import 'package:kashakeibo/style/tokens.dart';

/// バックアップ用アカウントリンクとアカウント削除を提供する設定画面。
class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseUserAsync = ref.watch(firebaseUserChangesProvider);
    final linkOrSignInWithApple = ref.watch(linkOrSignInWithAppleProvider);
    final linkOrSignInWithGoogle = ref.watch(linkOrSignInWithGoogleProvider);
    final deleteAccount = ref.watch(deleteAccountProvider);
    final logAnalyticsEvent = ref.watch(logAnalyticsEventProvider);
    final operationInProgress = useState(false);
    final l10n = AppLocalizations.of(context);

    /// アカウントリンクを実行し、結果を画面へ表示する。
    Future<void> runLinkAction({required AccountAction accountAction}) async {
      operationInProgress.value = true;
      try {
        await accountAction();
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.accountLinked)));
      } catch (error) {
        if (!context.mounted) {
          return;
        }
        // エラーメッセージは加工せずそのまま表示する
        // (`.claude/rules/coding-conventions.md`)。
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      } finally {
        if (context.mounted) {
          operationInProgress.value = false;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          l10n.settingsTitle,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: firebaseUserAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // エラーメッセージは加工せずそのまま表示する
          // (`.claude/rules/coding-conventions.md`)。
          error: (error, _) => Center(child: Text(error.toString())),
          data: (firebaseUser) {
            if (firebaseUser == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final appleLinked = hasLinkedProvider(
              user: firebaseUser,
              providerID: 'apple.com',
            );
            final googleLinked = hasLinkedProvider(
              user: firebaseUser,
              providerID: 'google.com',
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              children: [
                _BackupCard(
                  configured: !firebaseUser.isAnonymous,
                  appleLinked: appleLinked,
                  googleLinked: googleLinked,
                  operationInProgress: operationInProgress.value,
                  onApplePressed: () async {
                    await logAnalyticsEvent(name: 'link_apple_account');
                    await runLinkAction(accountAction: linkOrSignInWithApple);
                  },
                  onGooglePressed: () async {
                    await logAnalyticsEvent(name: 'link_google_account');
                    await runLinkAction(accountAction: linkOrSignInWithGoogle);
                  },
                ),
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: operationInProgress.value
                        ? null
                        : () async {
                            await logAnalyticsEvent(
                              name: 'delete_account_start',
                            );
                            if (!context.mounted ||
                                !await _confirmAccountDeletion(
                                  context: context,
                                  logAnalyticsEvent: logAnalyticsEvent,
                                )) {
                              return;
                            }
                            operationInProgress.value = true;
                            try {
                              await deleteAccount.call();
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }
                              // エラーメッセージは加工せずそのまま表示する
                              // (`.claude/rules/coding-conventions.md`)。
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            } finally {
                              if (context.mounted) {
                                operationInProgress.value = false;
                              }
                            }
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent800,
                    ),
                    child: Text(
                      l10n.deleteAccount,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 未リンク時の注意と Apple / Google のリンク操作を表示するカード。
class _BackupCard extends StatelessWidget {
  /// 外部プロバイダが一つ以上リンク済みか。
  final bool configured;

  /// Apple がリンク済みか。
  final bool appleLinked;

  /// Google がリンク済みか。
  final bool googleLinked;

  /// 別のアカウント操作を実行中か。
  final bool operationInProgress;

  /// Apple リンクボタンの操作。
  final AsyncCallback onApplePressed;

  /// Google リンクボタンの操作。
  final AsyncCallback onGooglePressed;

  /// バックアップ状態とリンク操作を指定してカードを作る。
  const _BackupCard({
    required this.configured,
    required this.appleLinked,
    required this.googleLinked,
    required this.operationInProgress,
    required this.onApplePressed,
    required this.onGooglePressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.sage100,
        border: Border.all(color: AppColors.sage300),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.accountBackupTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.sage800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.sage300,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  configured
                      ? l10n.accountBackupConfigured
                      : l10n.accountBackupNotSet,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.sage800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            configured
                ? l10n.accountBackupConfiguredDescription
                : l10n.accountBackupDescription,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.6,
              color: AppColors.sage800,
            ),
          ),
          if (!appleLinked || !googleLinked) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!appleLinked)
                  FilledButton(
                    onPressed: operationInProgress ? null : onApplePressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.neutral900,
                      foregroundColor: AppColors.background,
                    ),
                    child: Text(l10n.linkOrSignInWithApple),
                  ),
                if (!googleLinked)
                  OutlinedButton(
                    onPressed: operationInProgress ? null : onGooglePressed,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurface,
                      side: const BorderSide(color: AppColors.divider),
                      backgroundColor: AppColors.neutral100,
                    ),
                    child: Text(l10n.linkOrSignInWithGoogle),
                  ),
              ],
            ),
          ],
          if (operationInProgress) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

/// アカウント削除の確認ダイアログを表示する。
Future<bool> _confirmAccountDeletion({
  required BuildContext context,
  required LogAnalyticsEvent logAnalyticsEvent,
}) async {
  final l10n = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.deleteAccountConfirmationTitle),
          content: Text(l10n.deleteAccountConfirmationMessage),
          actions: [
            TextButton(
              onPressed: () async {
                await logAnalyticsEvent(name: 'delete_account_cancel');
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(false);
                }
              },
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                await logAnalyticsEvent(name: 'delete_account_confirm');
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.accent800),
              child: Text(l10n.delete),
            ),
          ],
        ),
      ) ??
      false;
}
