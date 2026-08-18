import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
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

/// 法務ドキュメントへの導線を表示する設定画面。
class SettingsPage extends StatefulWidget {
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
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _settingsCloseLogged = false;

  /// 戻る操作を経路によらず一度だけ記録する。
  void _logSettingsClose() {
    if (_settingsCloseLogged) {
      return;
    }
    _settingsCloseLogged = true;
    unawaited(widget.logAnalyticsEvent(name: 'settings_close'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final privacyPolicyPath =
        Localizations.localeOf(context).languageCode == 'en'
        ? 'PrivacyPolicy-en'
        : 'PrivacyPolicy';

    return PopScope<void>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _logSettingsClose();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const BackButtonIcon(),
            onPressed: () {
              _logSettingsClose();
              Navigator.of(context).pop();
            },
          ),
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
                      document: 'terms',
                      uri: _legalDocumentUri(path: 'Terms'),
                      openExternalUri: widget.openExternalUri,
                      logAnalyticsEvent: widget.logAnalyticsEvent,
                    ),
                    const Divider(height: 1),
                    _LegalDocumentRow(
                      label: l10n.privacyPolicy,
                      document: 'privacy_policy',
                      uri: _legalDocumentUri(path: privacyPolicyPath),
                      openExternalUri: widget.openExternalUri,
                      logAnalyticsEvent: widget.logAnalyticsEvent,
                    ),
                    const Divider(height: 1),
                    _LegalDocumentRow(
                      label: l10n.specifiedCommercialTransactionAct,
                      document: 'specified_commercial_transaction_act',
                      uri: _legalDocumentUri(
                        path: 'SpecifiedCommercialTransactionAct-ja',
                      ),
                      openExternalUri: widget.openExternalUri,
                      logAnalyticsEvent: widget.logAnalyticsEvent,
                    ),
                  ],
                ),
              ),
            ],
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
    return ListTile(
      minTileHeight: 50,
      title: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.neutral500),
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
