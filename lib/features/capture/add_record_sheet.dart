import 'package:flutter/material.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/style/tokens.dart';

/// 「記録する」シートで選ばれた入力経路。
enum AddRecordOption {
  /// カメラでレシートを撮影して AI 解析する。
  camera,

  /// フォトライブラリの写真・スクショを選んで AI 解析する。
  photoLibrary,

  /// 画像なしで手動入力する。
  manual,
}

/// 「記録する」シートを表示し、選ばれた入力経路を返す (閉じた場合は null)。
Future<AddRecordOption?> showAddRecordSheet({required BuildContext context}) =>
    showModalBottomSheet<AddRecordOption>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.neutral100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const AddRecordSheet(),
    );

/// 入力経路 (カメラで撮影 / 写真・スクショから選ぶ / 手動で入力) を選ぶボトムシート
/// (design_handoff_kashakeibo/README.md の取込フロー 1「記録する」)。
class AddRecordSheet extends StatelessWidget {
  const AddRecordSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.addRecordTitle,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _AddRecordOptionRow(
            icon: Icons.photo_camera_outlined,
            iconBackgroundColor: AppColors.accent100,
            iconColor: AppColors.primary,
            title: l10n.captureReceiptWithCamera,
            description: l10n.captureReceiptWithCameraDescription,
            onTap: () => Navigator.of(context).pop(AddRecordOption.camera),
          ),
          const SizedBox(height: 8),
          _AddRecordOptionRow(
            icon: Icons.photo_library_outlined,
            iconBackgroundColor: AppColors.sage100,
            iconColor: AppColors.sage700,
            title: l10n.capturePickFromPhotoLibrary,
            description: l10n.capturePickFromPhotoLibraryDescription,
            onTap: () =>
                Navigator.of(context).pop(AddRecordOption.photoLibrary),
          ),
          const SizedBox(height: 8),
          _AddRecordOptionRow(
            icon: Icons.currency_yen,
            iconBackgroundColor: AppColors.neutral200,
            iconColor: AppColors.neutral700,
            title: l10n.manualEntryOpen,
            description: l10n.manualEntryDescription,
            onTap: () => Navigator.of(context).pop(AddRecordOption.manual),
          ),
        ],
      ),
    );
  }
}

/// 「記録する」シートの選択肢 1 行 (42px の円形アイコン + タイトル + 説明)。
class _AddRecordOptionRow extends StatelessWidget {
  /// 左端に表示するアイコン。
  final IconData icon;

  /// アイコン円の背景色。
  final Color iconBackgroundColor;

  /// アイコンの色。
  final Color iconColor;

  /// 選択肢のタイトル。
  final String title;

  /// 選択肢の説明。
  final String description;

  /// タップ時の処理。
  final VoidCallback onTap;

  const _AddRecordOptionRow({
    required this.icon,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.neutral600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.neutral600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
