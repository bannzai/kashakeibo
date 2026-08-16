// ignore_for_file: constant_identifier_names

/// アプリの接続先環境。
enum Flavor {
  /// kashakeibo-dev に接続する開発ビルド (debug ビルド)。
  DEVELOP,

  /// kashakeibo-prod に接続する本番ビルド (release / profile ビルド)。
  PRODUCTION,

  /// Firebase Emulator (demo-kashakeibo) に接続するローカル開発ビルド。
  LOCAL,
}

/// 実行中ビルドの環境情報。main() で flavor が設定される。
abstract class Environment {
  /// 本番 (kashakeibo-prod) に接続しているかどうか。
  static bool get isProduction => flavor == Flavor.PRODUCTION;

  /// 開発環境 (kashakeibo-dev または Emulator) に接続しているかどうか。
  static bool get isDevelopment =>
      flavor == Flavor.DEVELOP || flavor == Flavor.LOCAL;

  /// Firebase Emulator に接続しているかどうか。
  static bool get isLocal => flavor == Flavor.LOCAL;

  /// 現在の環境。main() の起動時に一度だけ設定される。
  static Flavor? flavor;
}
