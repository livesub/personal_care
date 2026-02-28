import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../utils/i18n_helper.dart';

/// 관리자 서브 메뉴용 placeholder. "준비 중" 문구 + 뒤로가기.
class AdminPlaceholderScreen extends StatelessWidget {
  final String title;

  const AdminPlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final i18n = I18nHelper.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final padding = width < 600 ? 16.0 : 24.0;
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.all(padding),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              i18n.t('admin_coming_soon'),
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
