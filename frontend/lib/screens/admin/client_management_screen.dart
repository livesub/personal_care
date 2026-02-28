import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../models/admin_client_list_item.dart';
import '../../providers/admin_members_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/font_scale_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/i18n_helper.dart';
import '../../widgets/logout_button.dart';
import '../admin_member_register_dialogs.dart';

/// 장애인(이용자) 관리 전용 화면. 등록·목록·검색·페이징·삭제. 센터 격리.
class ClientManagementScreen extends ConsumerWidget {
  const ClientManagementScreen({super.key});

  static const double _breakpoint = 600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontScale = ref.watch(fontScaleProvider);
    final locale = ref.watch(localeProvider);
    final i18n = I18nHelper.of(context);

    return Container(
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _breakpoint;
          final contentPadding = isWide ? 24.0 : 16.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(context, ref, fontScale, locale, i18n, contentPadding),
              Expanded(
                child: _buildBody(context, ref, fontScale, i18n, isWide, contentPadding),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    WidgetRef ref,
    double fontScale,
    Locale locale,
    I18nHelper i18n,
    double contentPadding,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(contentPadding * fontScale, 12 * fontScale, contentPadding * fontScale, 8 * fontScale),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 8,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.accessible, color: AppColors.primary, size: 22 * fontScale),
              SizedBox(width: 8 * fontScale),
              Text(
                i18n.t('admin_nav_clients'),
                style: TextStyle(
                  fontSize: 18 * fontScale,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: i18n.t('font_size'),
                child: IconButton(
                  icon: Icon(Icons.text_fields, color: AppColors.textSecondary, size: 22 * fontScale),
                  onPressed: () => ref.read(fontScaleProvider.notifier).toggleScale(),
                ),
              ),
              SizedBox(
                width: 100,
                child: DropdownButton<String>(
                  value: locale.languageCode,
                  underline: const SizedBox(),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(value: 'ko', child: Text(i18n.t('language_ko'))),
                    DropdownMenuItem(value: 'en', child: Text(i18n.t('language_en'))),
                    DropdownMenuItem(value: 'vi', child: Text(i18n.t('language_vi'))),
                  ],
                  onChanged: (v) {
                    if (v != null) ref.read(localeProvider.notifier).changeLocale(v);
                  },
                ),
              ),
              const LogoutButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _clientSearchFieldDropdown(BuildContext context, WidgetRef ref, double fontScale, I18nHelper i18n) {
    final locale = ref.watch(localeProvider);
    final searchField = ref.watch(clientSearchFieldProvider);
    String label(String value) {
      switch (value) {
        case 'name': return locale.languageCode == 'ko' ? '이름' : (locale.languageCode == 'vi' ? 'Tên' : 'Name');
        case 'phone': return locale.languageCode == 'ko' ? '전화번호' : (locale.languageCode == 'vi' ? 'SĐT' : 'Phone');
        case 'resident_no': return _residentNoLabel(locale);
        default: return '이름';
      }
    }
    return SizedBox(
      width: 120 * fontScale,
      child: DropdownButtonFormField<String>(
        value: searchField,
        decoration: InputDecoration(border: OutlineInputBorder(), isDense: true),
        isExpanded: true,
        items: ['name', 'phone', 'resident_no'].map((v) => DropdownMenuItem(value: v, child: Text(label(v), style: TextStyle(fontSize: 14 * fontScale)))).toList(),
        onChanged: (v) {
          if (v != null) {
            ref.read(clientSearchFieldProvider.notifier).state = v;
            ref.read(clientPageProvider.notifier).state = 1;
            ref.invalidate(adminClientsListProvider);
          }
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    double fontScale,
    I18nHelper i18n,
    bool isWide,
    double contentPadding,
  ) {
    final searchQuery = ref.watch(clientSearchQueryProvider);
    final async = ref.watch(adminClientsListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: contentPadding * fontScale),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _clientSearchFieldDropdown(context, ref, fontScale, i18n),
                    SizedBox(width: 8 * fontScale),
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('client_search'),
                        initialValue: searchQuery,
                        onChanged: (v) {
                          ref.read(clientSearchQueryProvider.notifier).state = v;
                          ref.read(clientPageProvider.notifier).state = 1;
                        },
                        decoration: InputDecoration(
                          hintText: i18n.t('admin_header_search'),
                          prefixIcon: Icon(Icons.search, size: 20 * fontScale),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        style: TextStyle(fontSize: 14 * fontScale),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12 * fontScale),
              FilledButton.icon(
                icon: Icon(Icons.person_add, size: 20 * fontScale),
                label: Text(i18n.t('admin_register_new_client'), style: TextStyle(fontSize: 14 * fontScale)),
                onPressed: () => AdminMemberRegisterDialogs.showClientRegisterDialog(context, ref, fontScale, i18n)
                    .then((_) {
                  ref.invalidate(adminClientsListProvider);
                  ref.invalidate(adminClientsForMatchingProvider);
                }),
              ),
            ],
          ),
        ),
        SizedBox(height: 12 * fontScale),
        Expanded(
          child: async.when(
            data: (data) {
              final locale = ref.watch(localeProvider);
              final clients = data['clients'] as List<AdminClientListItem>;
              final total = data['total'] as int;
              final currentPage = data['current_page'] as int;
              final lastPage = data['last_page'] as int;

              Future<void> onDelete(int id) async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => AlertDialog(
                    title: Text(i18n.t('admin_delete_btn')),
                    content: Text(i18n.t('admin_delete_confirm_message')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(i18n.t('cancel')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                        child: Text(i18n.t('admin_delete_confirm_btn')),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                try {
                  await ref.read(apiServiceProvider).deleteAdminClient(id);
                  ref.invalidate(adminClientsListProvider);
                  ref.invalidate(adminClientsForMatchingProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(i18n.t('admin_client_delete_success'))),
                    );
                  }
                } on DioException catch (e) {
                  if (context.mounted) {
                    final Object? raw = e.response?.data is Map ? (e.response!.data as Map)['message'] : null;
                    final String msg = raw?.toString() ?? i18n.t('admin_delete_failed');
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  }
                }
              }

              if (clients.isEmpty) {
                return Center(
                  child: Text(
                    i18n.t('admin_clients_empty'),
                    style: TextStyle(fontSize: 16 * fontScale, color: AppColors.textSecondary),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: isWide
                        ? _buildTable(context, clients, fontScale, i18n, locale, contentPadding, onDelete)
                        : _buildListView(context, clients, fontScale, i18n, locale, contentPadding, onDelete),
                  ),
                  _buildPaging(context, ref, fontScale, i18n, total, currentPage, lastPage),
                ],
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: AppColors.adminActive)),
            error: (err, _) => Center(
              child: Padding(
                padding: EdgeInsets.all(contentPadding * fontScale),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    SizedBox(height: 16),
                    Text(
                      i18n.t('admin_members_load_error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14 * fontScale),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 통화 단위: 언어별 고정 문구만 사용 (변수명 노출 방지).
  static String _currencyUnit(Locale locale) {
    switch (locale.languageCode) {
      case 'ko': return '원';
      case 'vi': return 'VND';
      default: return 'USD';
    }
  }

  /// 주민번호 라벨: 언어별 고정 문구만 사용 (변수명 노출 방지).
  static String _residentNoLabel(Locale locale) {
    switch (locale.languageCode) {
      case 'ko': return '주민번호';
      case 'vi': return 'Số CCCD';
      default: return 'Resident No.';
    }
  }

  static String _formatVoucher(int value, Locale locale) {
    final s = value.toString();
    final sb = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) sb.write(',');
      sb.write(s[i]);
    }
    return '${sb.toString()} ${_currencyUnit(locale)}';
  }

  Widget _buildTable(
    BuildContext context,
    List<AdminClientListItem> clients,
    double fontScale,
    I18nHelper i18n,
    Locale locale,
    double contentPadding,
    Future<void> Function(int) onDelete,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: contentPadding * fontScale),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 820),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.adminSidebar),
            columns: [
              DataColumn(label: Text(i18n.t('admin_members_col_name'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontScale))),
              DataColumn(label: Text(_residentNoLabel(locale), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontScale))),
              DataColumn(label: Text(i18n.t('admin_register_phone'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontScale))),
              DataColumn(label: Text(i18n.t('admin_register_voucher_balance'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontScale))),
              DataColumn(label: Text(i18n.t('admin_register_emergency_contacts'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontScale))),
              DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontScale))),
            ],
            rows: clients.map((c) => _clientDataRow(context, c, fontScale, i18n, locale, onDelete)).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _clientDataRow(
    BuildContext context,
    AdminClientListItem c,
    double fontScale,
    I18nHelper i18n,
    Locale locale,
    Future<void> Function(int) onDelete,
  ) {
    return DataRow(
      cells: [
        DataCell(Text(c.name, style: TextStyle(fontSize: 14 * fontScale))),
        DataCell(Text(c.residentNoDisplayMasked, style: TextStyle(fontSize: 14 * fontScale))),
        DataCell(Text(c.phone ?? '-', style: TextStyle(fontSize: 14 * fontScale))),
        DataCell(Text(_formatVoucher(c.voucherBalance, locale), style: TextStyle(fontSize: 14 * fontScale))),
        DataCell(
          c.emergencyContacts.isNotEmpty
              ? TextButton(
                  onPressed: () => _showEmergencyContactsDialog(context, c.name, c.emergencyContacts, fontScale, i18n),
                  child: Text(i18n.t('admin_emergency_contacts_show'), style: TextStyle(fontSize: 13 * fontScale)),
                )
              : Text('-', style: TextStyle(fontSize: 14 * fontScale)),
        ),
        DataCell(
          TextButton(
            onPressed: () => onDelete(c.id),
            child: Text(i18n.t('admin_delete_btn'), style: TextStyle(fontSize: 13 * fontScale, color: AppColors.error)),
          ),
        ),
      ],
    );
  }

  /// 비상연락처 확인 팝업. barrierDismissible: false, 세로 스크롤, 이름|연락처(특이사항)|관계 원본 그대로 표시.
  static void _showEmergencyContactsDialog(
    BuildContext context,
    String clientName,
    List<EmergencyContactItem> contacts,
    double fontScale,
    I18nHelper i18n,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text('$clientName · ${i18n.t('admin_register_emergency_contacts')}', style: TextStyle(fontSize: 16 * fontScale)),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(ctx).pop(),
              tooltip: i18n.t('close'),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 320,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final e = contacts[index];
              return Padding(
                padding: EdgeInsets.only(bottom: 12 * fontScale),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12 * fontScale),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(i18n.t('admin_members_col_name'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13 * fontScale)),
                            ),
                            Expanded(
                              child: Text(e.name, style: TextStyle(fontSize: 13 * fontScale), softWrap: true),
                            ),
                          ],
                        ),
                        SizedBox(height: 6 * fontScale),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(i18n.t('admin_register_phone'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13 * fontScale)),
                            ),
                            Expanded(
                              child: Text(e.phone, style: TextStyle(fontSize: 13 * fontScale), softWrap: true),
                            ),
                          ],
                        ),
                        if (e.relation.isNotEmpty) ...[
                          SizedBox(height: 6 * fontScale),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text(i18n.t('admin_contact_relation'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13 * fontScale)),
                              ),
                              Expanded(
                                child: Text(e.relation, style: TextStyle(fontSize: 13 * fontScale), softWrap: true),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(i18n.t('close')),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(
    BuildContext context,
    List<AdminClientListItem> clients,
    double fontScale,
    I18nHelper i18n,
    Locale locale,
    double contentPadding,
    Future<void> Function(int) onDelete,
  ) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: contentPadding * fontScale),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final c = clients[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12 * fontScale),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Icon(Icons.accessible, color: AppColors.primary),
            ),
            title: Text(c.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16 * fontScale)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_residentNoLabel(locale)}: ${c.residentNoDisplayMasked}', style: TextStyle(fontSize: 13 * fontScale)),
                Text('${i18n.t('admin_register_phone')}: ${c.phone ?? '-'}', style: TextStyle(fontSize: 13 * fontScale)),
                Text('${i18n.t('admin_register_voucher_balance')}: ${_formatVoucher(c.voucherBalance, locale)}', style: TextStyle(fontSize: 13 * fontScale)),
                if (c.emergencyContacts.isNotEmpty)
                  TextButton(
                    onPressed: () => _showEmergencyContactsDialog(context, c.name, c.emergencyContacts, fontScale, i18n),
                    child: Text(i18n.t('admin_emergency_contacts_show'), style: TextStyle(fontSize: 14 * fontScale)),
                  ),
                TextButton(
                  onPressed: () => onDelete(c.id),
                  child: Text(i18n.t('admin_delete_btn'), style: TextStyle(fontSize: 14 * fontScale, color: AppColors.error)),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildPaging(BuildContext context, WidgetRef ref, double fontScale, I18nHelper i18n, int total, int currentPage, int lastPage) {
    return Padding(
      padding: EdgeInsets.all(16 * fontScale),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text(
            '${i18n.t('admin_paging_total')} $total ${i18n.t('admin_paging_items')} · $currentPage / $lastPage',
            style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textSecondary),
          ),
          if (currentPage > 1)
            TextButton(
              onPressed: () => ref.read(clientPageProvider.notifier).state = currentPage - 1,
              child: Text(i18n.t('admin_paging_prev')),
            ),
          if (currentPage < lastPage)
            TextButton(
              onPressed: () => ref.read(clientPageProvider.notifier).state = currentPage + 1,
              child: Text(i18n.t('admin_paging_next')),
            ),
        ],
      ),
    );
  }
}
