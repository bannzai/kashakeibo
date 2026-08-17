import 'package:flutter/material.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/style/tokens.dart';
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

/// 法務ドキュメントへの導線を表示する設定画面。
class SettingsPage extends StatelessWidget {
  /// 外部URLを開く処理。
  final OpenExternalUri openExternalUri;

  const SettingsPage({required this.openExternalUri, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final privacyPolicyPath =
        Localizations.localeOf(context).languageCode == 'en'
        ? 'PrivacyPolicy-en'
        : 'PrivacyPolicy';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text(
          l10n.settings,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            Material(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _LegalDocumentRow(
                    label: l10n.termsOfService,
                    uri: _legalDocumentUri(path: 'Terms'),
                    openExternalUri: openExternalUri,
                  ),
                  const Divider(height: 1),
                  _LegalDocumentRow(
                    label: l10n.privacyPolicy,
                    uri: _legalDocumentUri(path: privacyPolicyPath),
                    openExternalUri: openExternalUri,
                  ),
                  const Divider(height: 1),
                  _LegalDocumentRow(
                    label: l10n.specifiedCommercialTransactionAct,
                    uri: _legalDocumentUri(
                      path: 'SpecifiedCommercialTransactionAct-ja',
                    ),
                    openExternalUri: openExternalUri,
                  ),
                ],
              ),
            ),
          ],
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

  /// 開く法務ドキュメントのURL。
  final Uri uri;

  /// 外部URLを開く処理。
  final OpenExternalUri openExternalUri;

  const _LegalDocumentRow({
    required this.label,
    required this.uri,
    required this.openExternalUri,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 50,
      title: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.neutral500),
      onTap: () async {
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
