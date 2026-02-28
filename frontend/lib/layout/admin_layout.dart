import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';
import '../providers/font_scale_provider.dart';
import 'admin_header.dart';
import 'admin_sidebar.dart';

/// 룰: AdminShell. 상단 헤더 + 좌측 사이드바가 페이지 이동 시에도 유지.
/// Desktop: 사이드바 250px 고정 + 우측 콘텐츠. Mobile: Drawer + 콘텐츠.
class AdminLayout extends ConsumerStatefulWidget {
  const AdminLayout({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends ConsumerState<AdminLayout> {
  static const double _breakpoint = 600;

  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(fontScaleProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= _breakpoint;
    final goRouter = GoRouter.of(context);
    final currentPath = GoRouterState.of(context).uri.path;
    final sidebar = AdminSidebar(
      currentPath: currentPath,
      fontScale: fontScale,
      goRouter: goRouter,
    );

    if (isWide) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AdminHeader(onMenuTap: null),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sidebar,
              Expanded(child: widget.child),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AdminHeader(
        onMenuTap: () => Scaffold.of(context).openDrawer(),
      ),
      drawer: Drawer(child: sidebar),
      body: SafeArea(child: widget.child),
    );
  }
}
