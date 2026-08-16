import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/features/auth/sign_in_resolver.dart';
import 'package:kashakeibo/features/monthly/monthly_page.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/style/tokens.dart';
import 'package:kashakeibo/utils/config/environment.dart';
import 'package:kashakeibo/utils/firebase_app_check/firebase_app_check.dart';
import 'package:kashakeibo/utils/firebase_emulator/firebase_emulator.dart';

void main() async {
  // debug ビルド = kashakeibo-dev、release / profile ビルド = kashakeibo-prod。
  // 接続先の実体は iOS の Copy GoogleService-Info.plist ビルドフェーズと
  // Android の google-services.json (src/debug = dev, app 直下 = prod) が切り替える。
  if (kDebugMode) {
    Environment.flavor = useFirebaseEmulator ? Flavor.LOCAL : Flavor.DEVELOP;
  } else {
    Environment.flavor = Flavor.PRODUCTION;
  }

  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  await activateAppCheck();

  runApp(const ProviderScope(child: App()));
}

/// アプリのルート Widget。
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // design_handoff_kashakeibo/README.md の Material 3 mapping。
      // ダークモードはデザイン未設計のためライトのみ定義する。
      theme: ThemeData(
        fontFamily: 'Figtree',
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          secondary: AppColors.secondary,
          onSecondary: AppColors.onPrimary,
          surface: AppColors.neutral100,
          onSurface: AppColors.onSurface,
          outline: AppColors.divider,
        ),
      ),
      home: const SignInResolver(child: MonthlyPage()),
    );
  }
}
