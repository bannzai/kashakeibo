import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/provider/account.dart';
import 'package:kashakeibo/provider/firebase_user.dart';
import 'package:kashakeibo/style/app_theme.dart';
import 'package:kashakeibo/style/tokens.dart';
import 'package:kashakeibo/utils/analytics/analytics.dart';
import 'package:url_launcher/url_launcher.dart';

const _legalDocumentsHost = 'bannzai.github.io';
const _legalDocumentsBasePath = '/kashakeibo';

/// 外部URLを開く処理。テストでは呼び出し先を差し替える。
typedef OpenExternalUri = Future<void> Function({required Uri uri});

/// 端末の既定ブラウザでURLを開く。
///
/// ブラウザ起動はユーザーのタップごとに行う副作用のため冪等にはできない。
Future<void> openExternalUri({required Uri uri}) async {
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw Exception('Could not launch $uri');
  }
}

/// バックアップ用アカウントリンク、法務ドキュメントへの導線、アカウント削除を
/// 提供する設定画面。
class SettingsPage extends HookConsumerWidget {
  /// 外部URLを開く処理。
  final OpenExternalUri openExternalUri;

  /// Analyticsイベントを記録する処理。
  final LogAnalyticsEvent logAnalyticsEvent;

  const SettingsPage({
    required this.openExternalUri,
    required this.logAnalyticsEvent,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseUserAsync = ref.watch(firebaseUserChangesProvider);
    final linkOrSignInWithApple = ref.watch(linkOrSignInWithAppleProvider);
    final linkOrSignInWithGoogle = ref.watch(linkOrSignInWithGoogleProvider);
    final hasCurrentUserData = ref.watch(hasCurrentUserDataProvider);
    final deleteAccount = ref.watch(deleteAccountProvider);
    final operationInProgress = useState(false);
    // 戻る操作を経路 (AppBar の戻るボタン / スワイプ) によらず一度だけ記録する。
    final settingsCloseLogged = useRef(false);
    final l10n = AppLocalizations.of(context);
    final appColors = context.appColors;
    final privacyPolicyPath =
        Localizations.localeOf(context).languageCode == 'en'
        ? 'PrivacyPolicy-en'
        : 'PrivacyPolicy';

    void logSettingsClose() {
      if (settingsCloseLogged.value) {
        return;
      }
      settingsCloseLogged.value = true;
      unawaited(logAnalyticsEvent(name: 'settings_close'));
    }

    /// アカウントリンクを実行し、結果を画面へ表示する。
    Future<void> runLinkAction({
      required String analyticsEventName,
      required bool isAnonymous,
      required AccountAction accountAction,
    }) async {
      if (operationInProgress.value) {
        return;
      }
      operationInProgress.value = true;
      try {
        await logAnalyticsEvent(name: analyticsEventName);
        if (isAnonymous && await hasCurrentUserData()) {
          if (!context.mounted ||
              !await _confirmPossibleAccountSwitch(
                context: context,
                logAnalyticsEvent: logAnalyticsEvent,
              )) {
            return;
          }
        }
        final accountActionResult = await accountAction();
        if (!context.mounted) {
          return;
        }
        final successMessage = switch (accountActionResult) {
          AccountActionResult.linked => l10n.accountLinked,
          AccountActionResult.signedInExistingAccount =>
            l10n.existingAccountSignedIn,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
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

    return PopScope<void>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          logSettingsClose();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const BackButtonIcon(),
            onPressed: () {
              logSettingsClose();
              Navigator.of(context).pop();
            },
          ),
          title: Text(l10n.settings),
        ),
        body: SafeArea(
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  14,
                  AppSpacing.xl,
                  24,
                ),
                children: [
                  _BackupCard(
                    configured: !firebaseUser.isAnonymous,
                    appleLinked: appleLinked,
                    googleLinked: googleLinked,
                    operationInProgress: operationInProgress.value,
                    onApplePressed: () async {
                      await runLinkAction(
                        analyticsEventName: 'link_apple_account',
                        isAnonymous: firebaseUser.isAnonymous,
                        accountAction: linkOrSignInWithApple,
                      );
                    },
                    onGooglePressed: () async {
                      await runLinkAction(
                        analyticsEventName: 'link_google_account',
                        isAnonymous: firebaseUser.isAnonymous,
                        accountAction: linkOrSignInWithGoogle,
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: appColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _LegalDocumentRow(
                          label: l10n.termsOfService,
                          document: 'terms',
                          uri: _legalDocumentUri(path: 'Terms'),
                          openExternalUri: openExternalUri,
                          logAnalyticsEvent: logAnalyticsEvent,
                        ),
                        const Divider(height: 1),
                        _LegalDocumentRow(
                          label: l10n.privacyPolicy,
                          document: 'privacy_policy',
                          uri: _legalDocumentUri(path: privacyPolicyPath),
                          openExternalUri: openExternalUri,
                          logAnalyticsEvent: logAnalyticsEvent,
                        ),
                        const Divider(height: 1),
                        _LegalDocumentRow(
                          label: l10n.specifiedCommercialTransactionAct,
                          document: 'specified_commercial_transaction_act',
                          uri: _legalDocumentUri(
                            path: 'SpecifiedCommercialTransactionAct-ja',
                          ),
                          openExternalUri: openExternalUri,
                          logAnalyticsEvent: logAnalyticsEvent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton(
                      onPressed: operationInProgress.value
                          ? null
                          : () async {
                              if (operationInProgress.value) {
                                return;
                              }
                              operationInProgress.value = true;
                              try {
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
                        foregroundColor: appColors.destructive,
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
      ),
    );
  }
}

/// GitHub Pages上の法務ドキュメントURLを返す。
Uri _legalDocumentUri({required String path}) =>
    Uri.https(_legalDocumentsHost, '$_legalDocumentsBasePath/$path');

/// 設定画面の法務ドキュメント1行。
class _LegalDocumentRow extends StatelessWidget {
  /// 行に表示する文言。
  final String label;

  /// Analyticsで法務ドキュメントを識別する値。
  final String document;

  /// 開く法務ドキュメントのURL。
  final Uri uri;

  /// 外部URLを開く処理。
  final OpenExternalUri openExternalUri;

  /// Analyticsイベントを記録する処理。
  final LogAnalyticsEvent logAnalyticsEvent;

  const _LegalDocumentRow({
    required this.label,
    required this.document,
    required this.uri,
    required this.openExternalUri,
    required this.logAnalyticsEvent,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return ListTile(
      minTileHeight: 50,
      title: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      trailing: Icon(Icons.chevron_right, color: appColors.neutral500),
      onTap: () async {
        unawaited(
          logAnalyticsEvent(
            name: 'legal_document_open',
            parameters: {'document': document},
          ),
        );
        try {
          await openExternalUri(uri: uri);
        } catch (error) {
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      },
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
    final appColors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: appColors.sage100,
        border: Border.all(color: appColors.sage300),
        borderRadius: BorderRadius.circular(AppRadius.sheet),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.accountBackupTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: appColors.sage800,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: appColors.sage300,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  configured
                      ? l10n.accountBackupConfigured
                      : l10n.accountBackupNotSet,
                  style: AppTextStyles.label.copyWith(color: appColors.sage800),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            configured
                ? l10n.accountBackupConfiguredDescription
                : l10n.accountBackupDescription,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.6,
              color: appColors.sage800,
            ),
          ),
          if (!appleLinked || !googleLinked) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (!appleLinked)
                  FilledButton(
                    onPressed: operationInProgress ? null : onApplePressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: appColors.neutral900,
                      foregroundColor: appColors.background,
                    ),
                    child: Text(l10n.linkOrSignInWithApple),
                  ),
                if (!googleLinked)
                  OutlinedButton(
                    onPressed: operationInProgress ? null : onGooglePressed,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: appColors.surface,
                    ),
                    child: Text(l10n.linkOrSignInWithGoogle),
                  ),
              ],
            ),
          ],
          if (operationInProgress) ...[
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

/// 匿名データがある状態で既存アカウントへ切り替わる可能性を確認する。
Future<bool> _confirmPossibleAccountSwitch({
  required BuildContext context,
  required LogAnalyticsEvent logAnalyticsEvent,
}) async {
  final l10n = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.accountSwitchWarningTitle),
          content: Text(l10n.accountSwitchWarningMessage),
          actions: [
            TextButton(
              onPressed: () async {
                await logAnalyticsEvent(name: 'account_switch_cancel');
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(false);
                }
              },
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                await logAnalyticsEvent(name: 'account_switch_continue');
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: Text(l10n.continueAccountLink),
            ),
          ],
        ),
      ) ??
      false;
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
              style: TextButton.styleFrom(
                foregroundColor: dialogContext.appColors.destructive,
              ),
              child: Text(l10n.delete),
            ),
          ],
        ),
      ) ??
      false;
}
