import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../providers/font_scale_provider.dart';
import '../utils/project_guide_content.dart';

/// [프로젝트 가이드] 팝업: 카드/리스트/칩/경고 배너로 구역 구분, 글자 크기 연동.
void showProjectGuideDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => Consumer(
      builder: (ctx, ref, _) {
        final fontScale = ref.watch(fontScaleProvider);
        return AlertDialog(
          title: Text(
            '프로젝트 가이드',
            style: TextStyle(
              fontSize: 22 * fontScale,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(fontScale),
                  SizedBox(height: 20 * fontScale),
                  ...projectGuideSections.map(
                    (s) => Padding(
                      padding: EdgeInsets.only(bottom: 20 * fontScale),
                      child: _SectionCard(section: s, fontScale: fontScale),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                '닫기',
                style: TextStyle(
                  fontSize: 16 * fontScale,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Widget _buildHeader(double fontScale) {
  return Card(
    elevation: 0,
    color: AppColors.primary.withValues(alpha: 0.08),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: EdgeInsets.all(16 * fontScale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '장애인 활동 지원 플랫폼',
            style: TextStyle(
              fontSize: 18 * fontScale,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 4 * fontScale),
          Text(
            'PERSONAL CARE · Project Master Guide',
            style: TextStyle(
              fontSize: 13 * fontScale,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.fontScale});

  final GuideSection section;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16 * fontScale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Title
            Text(
              section.title,
              style: TextStyle(
                fontSize: 17 * fontScale,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (section.subtitle != null) ...[
              SizedBox(height: 8 * fontScale),
              Text(
                section.subtitle!,
                style: TextStyle(
                  fontSize: 14 * fontScale,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            // Tech Chips
            if (section.techChips.isNotEmpty) ...[
              SizedBox(height: 12 * fontScale),
              Wrap(
                spacing: 8 * fontScale,
                runSpacing: 8 * fontScale,
                children: section.techChips.map((c) {
                  return Chip(
                    avatar: Icon(
                      Icons.code,
                      size: 18 * fontScale,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      c.label,
                      style: TextStyle(fontSize: 13 * fontScale),
                    ),
                    labelStyle: TextStyle(fontSize: 13 * fontScale),
                    padding: EdgeInsets.symmetric(
                      horizontal: 8 * fontScale,
                      vertical: 4 * fontScale,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  );
                }).toList(),
              ),
            ],
            // Alert Banners (보안/주의사항)
            ...section.alertItems.map((text) => Padding(
                  padding: EdgeInsets.only(top: 12 * fontScale),
                  child: _AlertBanner(text: text, fontScale: fontScale),
                )),
            // List items (ListTile 스타일)
            ...section.items.map((text) => Padding(
                  padding: EdgeInsets.only(top: 8 * fontScale),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      Icons.check_circle_outline,
                      size: 20 * fontScale,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      text,
                      style: TextStyle(
                        fontSize: 14 * fontScale,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.text, required this.fontScale});

  final String text;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 14 * fontScale,
        vertical: 12 * fontScale,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.6),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 22 * fontScale,
            color: AppColors.warning,
          ),
          SizedBox(width: 10 * fontScale),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13 * fontScale,
                color: AppColors.textPrimary,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
