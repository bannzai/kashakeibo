import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/features/settings/settings_page.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/l10n/app_localizations_en.dart';
import 'package:kashakeibo/provider/account.dart';
import 'package:kashakeibo/provider/firebase_analytics.dart';
import 'package:kashakeibo/provider/firebase_user.dart';
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
}) => ProviderScope(
  overrides: [
    firebaseUserChangesProvider.overrideWith(
      (ref) => Stream.value(firebaseUser),
    ),
    linkOrSignInWithAppleProvider.overrideWithValue(linkOrSignInWithApple),
    linkOrSignInWithGoogleProvider.overrideWithValue(linkOrSignInWithGoogle),
    deleteAccountProvider.overrideWithValue(deleteAccount),
    logAnalyticsEventProvider.overrideWithValue(logAnalyticsEvent),
  ],
  child: MaterialApp(
    initialRoute: '/settings',
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routes: {
      '/': (context) => const Scaffold(),
      '/settings': (context) => const SettingsPage(),
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
        },
        linkOrSignInWithGoogle: () async {
          googleLinkCount++;
        },
        deleteAccount: FakeDeleteAccount(),
        logAnalyticsEvent: ({required name}) async {
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

  testWidgets('リンク済みユーザーは設定済みになり、リンク済みプロバイダのボタンを隠す', (tester) async {
    final firebaseUser = MockSettingsUser();
    final appleUserInfo = MockUserInfo();
    when(() => firebaseUser.isAnonymous).thenReturn(false);
    when(() => firebaseUser.providerData).thenReturn([appleUserInfo]);
    when(() => appleUserInfo.providerId).thenReturn('apple.com');

    await tester.pumpWidget(
      buildSettingsApp(
        firebaseUser: firebaseUser,
        linkOrSignInWithApple: () async {},
        linkOrSignInWithGoogle: () async {},
        deleteAccount: FakeDeleteAccount(),
        logAnalyticsEvent: ({required name}) async {},
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

  testWidgets('確認ダイアログで削除するとアカウント削除機能を実行する', (tester) async {
    final firebaseUser = MockSettingsUser();
    final deleteAccount = FakeDeleteAccount();
    final analyticsEvents = <String>[];
    when(() => firebaseUser.isAnonymous).thenReturn(true);
    when(() => firebaseUser.providerData).thenReturn(const []);

    await tester.pumpWidget(
      buildSettingsApp(
        firebaseUser: firebaseUser,
        linkOrSignInWithApple: () async {},
        linkOrSignInWithGoogle: () async {},
        deleteAccount: deleteAccount,
        logAnalyticsEvent: ({required name}) async {
          analyticsEvents.add(name);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppLocalizationsEn().deleteAccount));
    await tester.pumpAndSettle();
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
