import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/features/capture/image_analysis_client.dart';
import 'package:kashakeibo/features/settings/settings_page.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/l10n/app_localizations_en.dart';
import 'package:kashakeibo/provider/account.dart';
import 'package:kashakeibo/provider/firebase_user.dart';
import 'package:kashakeibo/provider/image.dart';
import 'package:kashakeibo/provider/purchase.dart';
import 'package:kashakeibo/utils/analytics/analytics.dart';
import 'package:mocktail/mocktail.dart';

/// テスト用 Firebase ユーザーモック。
class MockSettingsUser extends Mock implements User {}

/// テスト用 Firebase プロバイダ情報モック。
class MockUserInfo extends Mock implements UserInfo {}

/// 呼び出し回数を記録するアカウント削除機能。
class FakeDeleteAccount implements DeleteAccount {
  /// 削除の呼び出し回数。
  int callCount = 0;

  /// 呼び出し回数を増やす。
  @override
  Future<void> call() async {
    callCount++;
  }
}

/// 設定画面をテスト用 Provider とルート構成で組み立てる。
Widget buildSettingsApp({
  required User firebaseUser,
  required AccountAction linkOrSignInWithApple,
  required AccountAction linkOrSignInWithGoogle,
  required DeleteAccount deleteAccount,
  required LogAnalyticsEvent logAnalyticsEvent,
  HasCurrentUserData? hasCurrentUserData,
  bool isPremium = false,
}) => ProviderScope(
  overrides: [
    firebaseUserChangesProvider.overrideWith(
      (ref) => Stream.value(firebaseUser),
    ),
    isPremiumProvider.overrideWithValue(isPremium),
    // プラン行から開くペイウォール用。Offering 無し (SDK 未設定相当) で表示だけ確認する
    fetchScanQuotaProvider.overrideWithValue(
      () async =>
          const ScanQuota(monthlyScanCount: 2, monthlyFreeScanLimit: 10),
    ),
    premiumOfferingProvider.overrideWith((ref) async => null),
    purchasePremiumPackageProvider.overrideWithValue(
      ({required package}) async => false,
    ),
    restorePurchasesProvider.overrideWithValue(() async => false),
    linkOrSignInWithAppleProvider.overrideWithValue(linkOrSignInWithApple),
    linkOrSignInWithGoogleProvider.overrideWithValue(linkOrSignInWithGoogle),
    hasCurrentUserDataProvider.overrideWithValue(
      hasCurrentUserData ?? () async => false,
    ),
    deleteAccountProvider.overrideWithValue(deleteAccount),
  ],
  child: MaterialApp(
    initialRoute: '/settings',
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routes: {
      '/': (context) => const Scaffold(),
      '/settings': (context) => SettingsPage(
        // 法務ドキュメントの外部起動は本テストの対象外のため何もしない。
        openExternalUri: ({required uri}) async {},
        logAnalyticsEvent: logAnalyticsEvent,
      ),
    },
  ),
);

/// 設定画面の Widget テスト。
void main() {
  testWidgets('匿名ユーザーにバックアップ未設定とApple・Googleリンク導線を表示する', (tester) async {
    final firebaseUser = MockSettingsUser();
    var appleLinkCount = 0;
    var googleLinkCount = 0;
    final analyticsEvents = <String>[];
    when(() => firebaseUser.isAnonymous).thenReturn(true);
    when(() => firebaseUser.providerData).thenReturn(const []);

    await tester.pumpWidget(
      buildSettingsApp(
        firebaseUser: firebaseUser,
        linkOrSignInWithApple: () async {
          appleLinkCount++;
          return AccountActionResult.linked;
        },
        linkOrSignInWithGoogle: () async {
          googleLinkCount++;
          return AccountActionResult.linked;
        },
        deleteAccount: FakeDeleteAccount(),
        logAnalyticsEvent: ({required name, parameters}) async {
          analyticsEvents.add(name);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().accountBackupNotSet), findsOneWidget);
    expect(
      find.text(AppLocalizationsEn().linkOrSignInWithApple),
      findsOneWidget,
    );
    expect(
      find.text(AppLocalizationsEn().linkOrSignInWithGoogle),
      findsOneWidget,
    );

    await tester.tap(find.text(AppLocalizationsEn().linkOrSignInWithApple));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().linkOrSignInWithGoogle));
    await tester.pumpAndSettle();

    expect(appleLinkCount, 1);
    expect(googleLinkCount, 1);
    expect(
      analyticsEvents,
      containsAll(['link_apple_account', 'link_google_account']),
    );
  });

  testWidgets('プラン行に現在のプラン (無料 / プレミアム) を表示し、タップでペイウォールを開く', (tester) async {
    final firebaseUser = MockSettingsUser();
    final analyticsEvents = <String>[];
    when(() => firebaseUser.isAnonymous).thenReturn(true);
    when(() => firebaseUser.providerData).thenReturn(const []);

    await tester.pumpWidget(
      buildSettingsApp(
        firebaseUser: firebaseUser,
        linkOrSignInWithApple: () async => AccountActionResult.linked,
        linkOrSignInWithGoogle: () async => AccountActionResult.linked,
        deleteAccount: FakeDeleteAccount(),
        logAnalyticsEvent: ({required name, parameters}) async {
          analyticsEvents.add(name);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().settingsPlan), findsOneWidget);
    expect(find.text(AppLocalizationsEn().planFree), findsOneWidget);

    await tester.tap(find.text(AppLocalizationsEn().settingsPlan));
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizationsEn().paywallTitle), findsOneWidget);
    expect(
      analyticsEvents,
      containsAll(['settings_plan_open', 'paywall_open']),
    );
  });

  testWidgets('プレミアムのユーザーにはプラン行にプレミアムと表示する', (tester) async {
    final firebaseUser = MockSettingsUser();
    when(() => firebaseUser.isAnonymous).thenReturn(false);
    when(() => firebaseUser.providerData).thenReturn(const []);

    await tester.pumpWidget(
      buildSettingsApp(
        firebaseUser: firebaseUser,
        linkOrSignInWithApple: () async => AccountActionResult.linked,
        linkOrSignInWithGoogle: () async => AccountActionResult.linked,
        deleteAccount: FakeDeleteAccount(),
        logAnalyticsEvent: ({required name, parameters}) async {},
        isPremium: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().planPremium), findsOneWidget);
    expect(find.text(AppLocalizationsEn().planFree), findsNothing);
  });

  testWidgets('既存アカウントへサインインした場合はリンクではなく切替完了を表示する', (tester) async {
    final firebaseUser = MockSettingsUser();
    when(() => firebaseUser.isAnonymous).thenReturn(true);
    when(() => firebaseUser.providerData).thenReturn(const []);

    await tester.pumpWidget(
      buildSettingsApp(
        firebaseUser: firebaseUser,
        linkOrSignInWithApple: () async => AccountActionResult.linked,
        linkOrSignInWithGoogle: () async =>
            AccountActionResult.signedInExistingAccount,
        deleteAccount: FakeDeleteAccount(),
        logAnalyticsEvent: ({required name, parameters}) async {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppLocalizationsEn().linkOrSignInWithGoogle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text(AppLocalizationsEn().existingAccountSignedIn),
      findsOneWidget,
    );
  });

  testWidgets('リンク済みユーザーは設定済みになり、リンク済みプロバイダのボタンを隠す', (tester) async {
    final firebaseUser = MockSettingsUser();
    final appleUserInfo = MockUserInfo();
    when(() => firebaseUser.isAnonymous).thenReturn(false);
    when(() => firebaseUser.providerData).thenReturn([appleUserInfo]);
    when(() => appleUserInfo.providerId).thenReturn('apple.com');

    await tester.pumpWidget(
      buildSettingsApp(
        firebaseUser: firebaseUser,
        linkOrSignInWithApple: () async => AccountActionResult.linked,
        linkOrSignInWithGoogle: () async => AccountActionResult.linked,
        deleteAccount: FakeDeleteAccount(),
        logAnalyticsEvent: ({required name, parameters}) async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocalizationsEn().accountBackupConfigured),
      findsOneWidget,
    );
    expect(find.text(AppLocalizationsEn().linkOrSignInWithApple), findsNothing);
    expect(
      find.text(AppLocalizationsEn().linkOrSignInWithGoogle),
      findsOneWidget,
    );
  });

  testWidgets('匿名データがある場合は既存アカウント切替の警告を表示し、キャンセルするとリンクしない', (tester) async {
    final firebaseUser = MockSettingsUser();
    var appleLinkCount = 0;
    final analyticsEvents = <String>[];
    when(() => firebaseUser.isAnonymous).thenReturn(true);
    when(() => firebaseUser.providerData).thenReturn(const []);

    await tester.pumpWidget(
      buildSettingsApp(
        firebaseUser: firebaseUser,
        linkOrSignInWithApple: () async {
          appleLinkCount++;
          return AccountActionResult.linked;
        },
        linkOrSignInWithGoogle: () async => AccountActionResult.linked,
        deleteAccount: FakeDeleteAccount(),
        logAnalyticsEvent: ({required name, parameters}) async {
          analyticsEvents.add(name);
        },
        hasCurrentUserData: () async => true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppLocalizationsEn().linkOrSignInWithApple));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(AppLocalizationsEn().accountSwitchWarningTitle),
      findsOneWidget,
    );
    await tester.tap(find.text(AppLocalizationsEn().cancel));
    await tester.pumpAndSettle();

    expect(appleLinkCount, 0);
    expect(analyticsEvents, contains('account_switch_cancel'));
  });

  testWidgets('Analyticsの完了待ち中にリンクボタンを連打しても認証操作は一度だけ実行する', (tester) async {
    final firebaseUser = MockSettingsUser();
    final analyticsCompleter = Completer<void>();
    var analyticsCount = 0;
    var appleLinkCount = 0;
    when(() => firebaseUser.isAnonymous).thenReturn(true);
    when(() => firebaseUser.providerData).thenReturn(const []);

    await tester.pumpWidget(
      buildSettingsApp(
        firebaseUser: firebaseUser,
        linkOrSignInWithApple: () async {
          appleLinkCount++;
          return AccountActionResult.linked;
        },
        linkOrSignInWithGoogle: () async => AccountActionResult.linked,
        deleteAccount: FakeDeleteAccount(),
        logAnalyticsEvent: ({required name, parameters}) {
          analyticsCount++;
          return analyticsCompleter.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    final appleLinkButton = find.text(
      AppLocalizationsEn().linkOrSignInWithApple,
    );
    await tester.tap(appleLinkButton);
    await tester.tap(appleLinkButton);
    expect(analyticsCount, 1);
    expect(appleLinkCount, 0);

    analyticsCompleter.complete();
    await tester.pumpAndSettle();
    expect(appleLinkCount, 1);
  });

  testWidgets('Analyticsの完了待ち中に削除ボタンを連打しても確認ダイアログは一つだけ表示する', (tester) async {
    final firebaseUser = MockSettingsUser();
    final analyticsCompleter = Completer<void>();
    var deleteStartAnalyticsCount = 0;
    when(() => firebaseUser.isAnonymous).thenReturn(true);
    when(() => firebaseUser.providerData).thenReturn(const []);

    await tester.pumpWidget(
      buildSettingsApp(
        firebaseUser: firebaseUser,
        linkOrSignInWithApple: () async => AccountActionResult.linked,
        linkOrSignInWithGoogle: () async => AccountActionResult.linked,
        deleteAccount: FakeDeleteAccount(),
        logAnalyticsEvent: ({required name, parameters}) {
          if (name == 'delete_account_start') {
            deleteStartAnalyticsCount++;
            return analyticsCompleter.future;
          }
          return Future.value();
        },
      ),
    );
    await tester.pumpAndSettle();

    final deleteAccountButton = find.text(AppLocalizationsEn().deleteAccount);
    await tester.tap(deleteAccountButton);
    await tester.tap(deleteAccountButton);
    expect(deleteStartAnalyticsCount, 1);

    analyticsCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(AppLocalizationsEn().deleteAccountConfirmationTitle),
      findsOneWidget,
    );
    await tester.tap(find.text(AppLocalizationsEn().cancel));
    await tester.pumpAndSettle();
  });

  testWidgets('確認ダイアログで削除するとアカウント削除機能を実行する', (tester) async {
    final firebaseUser = MockSettingsUser();
    final deleteAccount = FakeDeleteAccount();
    final analyticsEvents = <String>[];
    when(() => firebaseUser.isAnonymous).thenReturn(true);
    when(() => firebaseUser.providerData).thenReturn(const []);

    await tester.pumpWidget(
      buildSettingsApp(
        firebaseUser: firebaseUser,
        linkOrSignInWithApple: () async => AccountActionResult.linked,
        linkOrSignInWithGoogle: () async => AccountActionResult.linked,
        deleteAccount: deleteAccount,
        logAnalyticsEvent: ({required name, parameters}) async {
          analyticsEvents.add(name);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppLocalizationsEn().deleteAccount));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(AppLocalizationsEn().deleteAccountConfirmationTitle),
      findsOneWidget,
    );
    await tester.tap(find.text(AppLocalizationsEn().delete));
    await tester.pumpAndSettle();

    expect(deleteAccount.callCount, 1);
    expect(
      analyticsEvents,
      containsAll(['delete_account_start', 'delete_account_confirm']),
    );
  });
}
