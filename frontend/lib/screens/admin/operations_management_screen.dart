import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../providers/admin_members_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/font_scale_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/i18n_helper.dart';
import '../../utils/input_formatters.dart';

/// 운영 관리 화면. 탭: [설정] [계정] [공지].
class OperationsManagementScreen extends ConsumerStatefulWidget {
  const OperationsManagementScreen({super.key});

  @override
  ConsumerState<OperationsManagementScreen> createState() => _OperationsManagementScreenState();
}

class _OperationsManagementScreenState extends ConsumerState<OperationsManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const double _breakpoint = 600;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(fontScaleProvider);
    final i18n = I18nHelper.of(context);
    final isStaff = ref.watch(authProvider).user?.isStaff == true;

    return Container(
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _breakpoint;
          final contentPadding = isWide ? 24.0 : 16.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(context, fontScale, i18n, contentPadding),
              TabBar(
                controller: _tabController,
                labelStyle: TextStyle(fontSize: 14 * fontScale, fontWeight: FontWeight.w600),
                unselectedLabelStyle: TextStyle(fontSize: 14 * fontScale),
                tabs: [
                  Tab(text: i18n.t('ops_tab_settings')),
                  Tab(text: i18n.t('ops_tab_accounts')),
                  Tab(text: i18n.t('ops_tab_notices')),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _SettingsTab(
                      fontScale: fontScale,
                      contentPadding: contentPadding,
                      isStaff: isStaff,
                      onSaved: () => ref.invalidate(adminSettingsProvider),
                    ),
                    _AccountsTab(
                      fontScale: fontScale,
                      contentPadding: contentPadding,
                      isStaff: isStaff,
                      onAdded: () => ref.invalidate(adminAdminsListProvider),
                    ),
                    _NoticesTab(
                      fontScale: fontScale,
                      contentPadding: contentPadding,
                      onChanged: () => ref.invalidate(adminNoticesListProvider),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, double fontScale, I18nHelper i18n, double contentPadding) {
    return Padding(
      padding: EdgeInsets.fromLTRB(contentPadding * fontScale, 12 * fontScale, contentPadding * fontScale, 8 * fontScale),
      child: Row(
        children: [
          Icon(Icons.settings, color: AppColors.adminActive, size: 22 * fontScale),
          SizedBox(width: 8 * fontScale),
          Text(
            i18n.t('admin_nav_system'),
            style: TextStyle(
              fontSize: 18 * fontScale,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 설정 탭: 바우처 단가. Staff는 조회만.
class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab({
    required this.fontScale,
    required this.contentPadding,
    required this.isStaff,
    required this.onSaved,
  });

  final double fontScale;
  final double contentPadding;
  final bool isStaff;
  final VoidCallback onSaved;

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminSettingsProvider);
    final i18n = I18nHelper.of(context);

    return async.when(
      data: (data) {
        if (_controller.text.isEmpty && data['default_hourly_wage'] != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _controller.text = '${data['default_hourly_wage']}';
          });
        }
        return SingleChildScrollView(
          padding: EdgeInsets.all(widget.contentPadding * widget.fontScale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isStaff)
                Padding(
                  padding: EdgeInsets.only(bottom: 12 * widget.fontScale),
                  child: Text(
                    i18n.t('ops_staff_view_only'),
                    style: TextStyle(fontSize: 13 * widget.fontScale, color: AppColors.textSecondary),
                  ),
                ),
              TextField(
                controller: _controller,
                readOnly: widget.isStaff,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: i18n.t('ops_voucher_price_label'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                style: TextStyle(fontSize: 16 * widget.fontScale),
              ),
              SizedBox(height: 16 * widget.fontScale),
              if (!widget.isStaff)
                FilledButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          final v = int.tryParse(_controller.text.trim());
                          if (v == null || v < 0) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(i18n.t('ops_voucher_price_label') + ' 0 이상 숫자를 입력하세요.')),
                              );
                            }
                            return;
                          }
                          setState(() => _loading = true);
                          try {
                            await ref.read(apiServiceProvider).patchAdminSettings(defaultHourlyWage: v);
                            widget.onSaved();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.t('ops_saved'))));
                            }
                          } on DioException catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(i18n.t('admin_matchings_load_error'))),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                  child: _loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(i18n.t('ops_save'), style: TextStyle(fontSize: 14 * widget.fontScale)),
                ),
            ],
          ),
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: AppColors.adminActive)),
      error: (_, __) => Center(child: Text(i18n.t('admin_matchings_load_error'), style: TextStyle(color: AppColors.error))),
    );
  }
}

/// 계정 탭: 관리자 목록 + 추가 버튼(Super만).
class _AccountsTab extends ConsumerWidget {
  const _AccountsTab({
    required this.fontScale,
    required this.contentPadding,
    required this.isStaff,
    required this.onAdded,
  });

  final double fontScale;
  final double contentPadding;
  final bool isStaff;
  final VoidCallback onAdded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminAdminsListProvider);
    final i18n = I18nHelper.of(context);
    final locale = ref.watch(localeProvider);

    return async.when(
      data: (admins) {
        String formatDate(String? iso) {
          if (iso == null || iso.isEmpty) return '—';
          final d = DateTime.tryParse(iso);
          if (d == null) return iso;
          final local = d.toLocal();
          return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
              '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: contentPadding * fontScale, vertical: 8 * fontScale),
              child: Row(
                children: [
                  const Spacer(),
                  FilledButton.icon(
                    icon: Icon(Icons.add, size: 20 * fontScale),
                    label: Text(i18n.t('ops_add_admin'), style: TextStyle(fontSize: 14 * fontScale)),
                    onPressed: isStaff ? null : () => _showAddAdminDialog(context, ref, fontScale, i18n, locale, onAdded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: admins.isEmpty
                  ? Center(
                      child: Text(
                        i18n.t('admin_matching_empty'),
                        style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textSecondary),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: contentPadding * fontScale),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppColors.adminSidebar),
                        columns: [
                          DataColumn(label: Text(i18n.t('ops_admin_name'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 * fontScale))),
                          DataColumn(label: Text(i18n.t('ops_admin_id'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 * fontScale))),
                          DataColumn(label: Text(i18n.t('ops_admin_role'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 * fontScale))),
                          DataColumn(label: Text(i18n.t('ops_admin_created_at'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 * fontScale))),
                        ],
                        rows: admins.map((a) {
                          final role = a['role'] as String? ?? 'staff';
                          return DataRow(
                            cells: [
                              DataCell(Text('${a['name']}', style: TextStyle(fontSize: 13 * fontScale))),
                              DataCell(Text('${a['login_id']}', style: TextStyle(fontSize: 13 * fontScale))),
                              DataCell(
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8 * fontScale, vertical: 4 * fontScale),
                                  decoration: BoxDecoration(
                                    color: role == 'super' ? AppColors.adminActive.withValues(alpha: 0.2) : AppColors.textSecondary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    role == 'super' ? i18n.t('admin_role_admin') : i18n.t('admin_role_staff'),
                                    style: TextStyle(fontSize: 12 * fontScale, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              DataCell(Text(formatDate(a['created_at'] as String?), style: TextStyle(fontSize: 13 * fontScale))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: AppColors.adminActive)),
      error: (_, __) => Center(child: Text(i18n.t('admin_matchings_load_error'), style: TextStyle(color: AppColors.error))),
    );
  }
}

void _showAddAdminDialog(
  BuildContext context,
  WidgetRef ref,
  double fontScale,
  I18nHelper i18n,
  Locale locale,
  VoidCallback onAdded,
) {
  final loginId = TextEditingController();
  final password = TextEditingController();
  final passwordConfirm = TextEditingController();
  final name = TextEditingController();
  final email = TextEditingController();
  String role = 'staff';
  String? dialogPasswordError;
  const String _passwordGuide = '최소 10자 이상, 영문+숫자+특수문자 포함';

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Row(
            children: [
              Expanded(child: Text(i18n.t('ops_add_admin'))),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(),
                tooltip: i18n.t('cancel'),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: loginId,
                    decoration: InputDecoration(
                      labelText: i18n.t('ops_admin_id'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.next,
                    style: TextStyle(fontSize: 14 * fontScale),
                  ),
                  SizedBox(height: 12 * fontScale),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: i18n.t('new_password'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: 14 * fontScale),
                    onChanged: (_) => setState(() => dialogPasswordError = null),
                  ),
                  SizedBox(height: 12 * fontScale),
                  TextField(
                    controller: passwordConfirm,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: i18n.t('confirm_password'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: 14 * fontScale),
                    onChanged: (_) => setState(() => dialogPasswordError = null),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 6 * fontScale),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _passwordGuide,
                          style: TextStyle(
                            fontSize: 12 * fontScale,
                            color: dialogPasswordError != null ? AppColors.error : AppColors.textSecondary,
                          ),
                        ),
                        if (dialogPasswordError != null) ...[
                          SizedBox(height: 4 * fontScale),
                          Text(
                            dialogPasswordError!,
                            style: TextStyle(fontSize: 13 * fontScale, color: AppColors.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 12 * fontScale),
                  TextField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: i18n.t('ops_admin_name'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: 14 * fontScale),
                  ),
                  SizedBox(height: 12 * fontScale),
                  TextField(
                    controller: email,
                    decoration: InputDecoration(
                      labelText: 'Email (선택)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontSize: 14 * fontScale),
                  ),
                  SizedBox(height: 12 * fontScale),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: InputDecoration(
                      labelText: i18n.t('ops_admin_role'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'staff',
                        child: Text(i18n.t('admin_role_staff'), style: TextStyle(fontSize: 14 * fontScale)),
                      ),
                      DropdownMenuItem<String>(
                        value: 'super',
                        enabled: false,
                        child: Text(
                          i18n.t('admin_role_admin'),
                          style: TextStyle(fontSize: 14 * fontScale, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => role = v ?? 'staff'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(i18n.t('cancel'))),
            FilledButton(
              onPressed: () async {
                setState(() => dialogPasswordError = null);
                final lid = loginId.text.trim();
                final pwd = password.text.trim();
                final confirm = passwordConfirm.text.trim();
                final n = name.text.trim();
                if (lid.isEmpty) {
                  setState(() => dialogPasswordError = i18n.t('validation_admin_id_required'));
                  return;
                }
                if (n.isEmpty) {
                  setState(() => dialogPasswordError = '이름을 입력해주세요.');
                  return;
                }
                if (pwd.isEmpty) {
                  setState(() => dialogPasswordError = i18n.t('validation_admin_password_required'));
                  return;
                }
                if (pwd != confirm) {
                  setState(() => dialogPasswordError = i18n.t('admin_setup_password_mismatch'));
                  return;
                }
                if (pwd.length < 10) {
                  setState(() => dialogPasswordError = i18n.t('admin_setup_password_min'));
                  return;
                }
                if (!passwordMeetsComplexity(pwd)) {
                  setState(() => dialogPasswordError = i18n.t('password_rule_full'));
                  return;
                }
                try {
                  await ref.read(apiServiceProvider).postAdminAdmin({
                    'login_id': lid,
                    'password': pwd,
                    'name': n,
                    'email': email.text.trim().isEmpty ? null : email.text.trim(),
                    'role': 'staff',
                  });
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  onAdded();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.t('admin_admin_created'))));
                  }
                } on DioException catch (e) {
                  String msg = i18n.t('admin_setup_failed');
                  if (e.response?.data is Map && (e.response!.data as Map).containsKey('message')) {
                    final m = (e.response!.data as Map)['message']?.toString();
                    if (m != null && m.isNotEmpty) msg = m;
                  }
                  if (ctx.mounted) setState(() => dialogPasswordError = msg);
                }
              },
              child: Text(i18n.t('ops_save')),
            ),
          ],
        );
      },
    ),
  );
}

/// 공지 탭: 목록 + 등록/수정/삭제.
class _NoticesTab extends ConsumerWidget {
  const _NoticesTab({
    required this.fontScale,
    required this.contentPadding,
    required this.onChanged,
  });

  final double fontScale;
  final double contentPadding;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminNoticesListProvider);
    final i18n = I18nHelper.of(context);

    return async.when(
      data: (notices) {
        String formatDate(String? iso) {
          if (iso == null || iso.isEmpty) return '—';
          final d = DateTime.tryParse(iso);
          if (d == null) return iso;
          final local = d.toLocal();
          return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
              '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: contentPadding * fontScale, vertical: 8 * fontScale),
              child: Row(
                children: [
                  const Spacer(),
                  FilledButton.icon(
                    icon: Icon(Icons.add, size: 20 * fontScale),
                    label: Text(i18n.t('ops_notice_add'), style: TextStyle(fontSize: 14 * fontScale)),
                    onPressed: () => _showNoticeEditDialog(context, ref, fontScale, i18n, null, onChanged),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notices.isEmpty
                  ? Center(
                      child: Text(
                        i18n.t('admin_matching_empty'),
                        style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: contentPadding * fontScale, vertical: 8 * fontScale),
                      itemCount: notices.length,
                      itemBuilder: (context, index) {
                        final n = notices[index];
                        final id = n['id'] as int?;
                        final title = n['title'] as String? ?? '';
                        final content = n['content'] as String? ?? '';
                        final createdAt = n['created_at'] as String?;
                        return Card(
                          margin: EdgeInsets.only(bottom: 12 * fontScale),
                          child: ListTile(
                            title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15 * fontScale)),
                            subtitle: Text(
                              (content.length > 80 ? content.substring(0, 80) + '…' : content) + ' · ${formatDate(createdAt)}',
                              style: TextStyle(fontSize: 13 * fontScale, color: AppColors.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, size: 20 * fontScale),
                                  onPressed: () => _showNoticeEditDialog(context, ref, fontScale, i18n, n, onChanged),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, size: 20 * fontScale, color: AppColors.error),
                                  onPressed: id == null
                                      ? null
                                      : () => _confirmDeleteNotice(context, ref, fontScale, i18n, id, onChanged),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: AppColors.adminActive)),
      error: (_, __) => Center(child: Text(i18n.t('admin_matchings_load_error'), style: TextStyle(color: AppColors.error))),
    );
  }
}

void _showNoticeEditDialog(
  BuildContext context,
  WidgetRef ref,
  double fontScale,
  I18nHelper i18n,
  Map<String, dynamic>? existing,
  VoidCallback onChanged,
) {
  final titleController = TextEditingController(text: existing?['title'] as String? ?? '');
  final contentController = TextEditingController(text: existing?['content'] as String? ?? '');
  final id = existing?['id'] as int?;

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(id == null ? i18n.t('ops_notice_add') : i18n.t('ops_notice_edit')),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: i18n.t('ops_notice_title'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                style: TextStyle(fontSize: 14 * fontScale),
              ),
              SizedBox(height: 12 * fontScale),
              TextField(
                controller: contentController,
                decoration: InputDecoration(
                  labelText: i18n.t('ops_notice_content'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                style: TextStyle(fontSize: 14 * fontScale),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(i18n.t('cancel'))),
        FilledButton(
          onPressed: () async {
            final title = titleController.text.trim();
            final content = contentController.text.trim();
            if (title.isEmpty || content.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.t('ops_notice_title'))));
              return;
            }
            try {
              if (id == null) {
                await ref.read(apiServiceProvider).postAdminNotice({'title': title, 'content': content});
              } else {
                await ref.read(apiServiceProvider).patchAdminNotice(id, {'title': title, 'content': content});
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
              onChanged();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(id == null ? i18n.t('notice_created') : i18n.t('notice_updated'))),
                );
              }
            } on DioException catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.t('admin_matchings_load_error'))));
              }
            }
          },
          child: Text(i18n.t('ops_save')),
        ),
      ],
    ),
  );
}

Future<void> _confirmDeleteNotice(
  BuildContext context,
  WidgetRef ref,
  double fontScale,
  I18nHelper i18n,
  int id,
  VoidCallback onChanged,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(i18n.t('ops_notice_delete')),
      content: Text(i18n.t('admin_delete_confirm_message')),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(i18n.t('cancel'))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(i18n.t('admin_delete_confirm_btn')),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await ref.read(apiServiceProvider).deleteAdminNotice(id);
    onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.t('notice_deleted'))));
    }
  } on DioException catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.t('admin_matchings_load_error'))));
    }
  }
}
