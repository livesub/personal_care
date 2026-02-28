import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/font_scale_provider.dart';
import '../../utils/i18n_helper.dart';
import '../../utils/save_bytes_stub.dart' if (dart.library.html) '../../utils/save_bytes_web.dart' as save_bytes;
import '../../services/api_service.dart';

/// 정산 화면: 월 선택, [급여 산출] / [바우처 청구] 탭, 테이블, 총 청구 예상액, 행 클릭 시 상세 팝업.
class SettlementScreen extends ConsumerStatefulWidget {
  const SettlementScreen({super.key});

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _error;
  static const double _breakpoint = 600;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.getSettlement(year: _year, month: _month);
      if (mounted) {
        setState(() {
          _data = res;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _data = null;
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _prevMonth() {
    if (_month == 1) {
      setState(() {
        _year -= 1;
        _month = 12;
      });
    } else {
      setState(() => _month -= 1);
    }
    _load();
  }

  void _nextMonth() {
    if (_month == 12) {
      setState(() {
        _year += 1;
        _month = 1;
      });
    } else {
      setState(() => _month += 1);
    }
    _load();
  }

  Future<void> _downloadExcel() async {
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.getSettlementExport(year: _year, month: _month);
      try {
        save_bytes.saveBytes(result.bytes, result.filename);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(I18nHelper.of(context).t('settlement_excel_downloaded'))),
          );
        }
      } on UnsupportedError catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(I18nHelper.of(context).t('settlement_excel_only_web'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  static String _formatAmount(int value) {
    return NumberFormat('#,###').format(value);
  }

  static String _formatHours(num value) {
    return NumberFormat('0.0').format(value);
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(fontScaleProvider);
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
              _buildTopBar(context, fontScale, i18n, contentPadding),
              TabBar(
                controller: _tabController,
                labelStyle: TextStyle(fontSize: 14 * fontScale, fontWeight: FontWeight.w600),
                unselectedLabelStyle: TextStyle(fontSize: 14 * fontScale),
                tabs: [
                  Tab(text: i18n.t('settlement_tab_salary')),
                  Tab(text: i18n.t('settlement_tab_voucher')),
                ],
              ),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: AppColors.adminActive))
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.all(24 * fontScale),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    i18n.t('settlement_load_error'),
                                    style: TextStyle(fontSize: 14 * fontScale),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 12 * fontScale),
                                  TextButton(
                                    onPressed: _load,
                                    child: Text(i18n.t('confirm')),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _SalaryTab(
                                data: _data,
                                fontScale: fontScale,
                                i18n: i18n,
                                contentPadding: contentPadding,
                                formatAmount: _formatAmount,
                                formatHours: _formatHours,
                              ),
                              _VoucherTab(
                                data: _data,
                                fontScale: fontScale,
                                i18n: i18n,
                                contentPadding: contentPadding,
                                formatAmount: _formatAmount,
                                formatHours: _formatHours,
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

  Widget _buildTopBar(
    BuildContext context,
    double fontScale,
    I18nHelper i18n,
    double contentPadding,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        contentPadding * fontScale,
        12 * fontScale,
        contentPadding * fontScale,
        8 * fontScale,
      ),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, color: AppColors.adminActive, size: 22 * fontScale),
          SizedBox(width: 8 * fontScale),
          IconButton(
            icon: Icon(Icons.chevron_left, size: 28 * fontScale),
            onPressed: _prevMonth,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          Expanded(
            child: Text(
              '$_year년 ${_month.toString().padLeft(2, '0')}월',
              style: TextStyle(
                fontSize: 18 * fontScale,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, size: 28 * fontScale),
            onPressed: _nextMonth,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          SizedBox(width: 8 * fontScale),
          FilledButton.icon(
            onPressed: _downloadExcel,
            icon: Icon(Icons.download, size: 18 * fontScale),
            label: Text(i18n.t('settlement_excel_download')),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.adminActive,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalaryTab extends StatelessWidget {
  const _SalaryTab({
    required this.data,
    required this.fontScale,
    required this.i18n,
    required this.contentPadding,
    required this.formatAmount,
    required this.formatHours,
  });

  final Map<String, dynamic>? data;
  final double fontScale;
  final I18nHelper i18n;
  final double contentPadding;
  final String Function(int) formatAmount;
  final String Function(num) formatHours;

  @override
  Widget build(BuildContext context) {
    final list = (data?['salary'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    return SingleChildScrollView(
      padding: EdgeInsets.all(contentPadding * fontScale),
      child: list.isEmpty
          ? Padding(
              padding: EdgeInsets.only(top: 48 * fontScale),
              child: Center(child: Text(i18n.t('settlement_empty'))),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.adminSidebar),
                columns: [
                  DataColumn(label: Text(i18n.t('settlement_col_name'))),
                  DataColumn(label: Text(i18n.t('settlement_col_birth'))),
                  DataColumn(label: Text(i18n.t('settlement_col_total_hours')), numeric: true),
                  DataColumn(label: Text(i18n.t('settlement_col_hourly_wage')), numeric: true),
                  DataColumn(label: Text(i18n.t('settlement_col_total_amount')), numeric: true),
                ],
                rows: list
                    .map(
                      (row) => DataRow(
                        cells: [
                          DataCell(Text(row['name']?.toString() ?? '')),
                          DataCell(Text((row['birth_display'] ?? '').toString())),
                          DataCell(Text(formatHours((row['total_hours'] as num?) ?? 0))),
                          DataCell(Text(formatAmount((row['hourly_wage'] as int?) ?? 0))),
                          DataCell(Text(formatAmount((row['total_amount'] as int?) ?? 0))),
                        ],
                        onSelectChanged: (_) {
                          _showDetailDialog(
                            context,
                            title: row['name']?.toString() ?? '',
                            details: (row['details'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
                            fontScale: fontScale,
                            i18n: i18n,
                            formatAmount: formatAmount,
                            formatHours: formatHours,
                          );
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }
}

class _VoucherTab extends StatelessWidget {
  const _VoucherTab({
    required this.data,
    required this.fontScale,
    required this.i18n,
    required this.contentPadding,
    required this.formatAmount,
    required this.formatHours,
  });

  final Map<String, dynamic>? data;
  final double fontScale;
  final I18nHelper i18n;
  final double contentPadding;
  final String Function(int) formatAmount;
  final String Function(num) formatHours;

  @override
  Widget build(BuildContext context) {
    final list = (data?['voucher'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final voucherTotal = (data?['voucher_total'] as int?) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              contentPadding * fontScale,
              contentPadding * fontScale,
              contentPadding * fontScale,
              8,
            ),
            child: list.isEmpty
                ? Padding(
                    padding: EdgeInsets.only(top: 48 * fontScale),
                    child: Center(child: Text(i18n.t('settlement_empty'))),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppColors.adminSidebar),
                      columns: [
                        DataColumn(label: Text(i18n.t('settlement_col_name'))),
                        DataColumn(label: Text(i18n.t('settlement_col_birth'))),
                        DataColumn(label: Text(i18n.t('settlement_col_grade'))),
                        DataColumn(label: Text(i18n.t('settlement_col_total_hours')), numeric: true),
                        DataColumn(label: Text(i18n.t('settlement_col_unit_price')), numeric: true),
                        DataColumn(label: Text(i18n.t('settlement_col_claim_amount')), numeric: true),
                      ],
                      rows: list
                          .map(
                            (row) => DataRow(
                              cells: [
                                DataCell(Text(row['name']?.toString() ?? '')),
                                DataCell(Text((row['birth_display'] ?? '').toString())),
                                DataCell(Text((row['grade'] ?? '').toString())),
                                DataCell(Text(formatHours((row['total_hours'] as num?) ?? 0))),
                                DataCell(Text(formatAmount((row['unit_price'] as int?) ?? 0))),
                                DataCell(Text(formatAmount((row['claim_amount'] as int?) ?? 0))),
                              ],
                              onSelectChanged: (_) {
                                _showDetailDialog(
                                  context,
                                  title: row['name']?.toString() ?? '',
                                  details: (row['details'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
                                  fontScale: fontScale,
                                  i18n: i18n,
                                  formatAmount: formatAmount,
                                  formatHours: formatHours,
                                );
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: contentPadding * fontScale,
            vertical: 12 * fontScale,
          ),
          color: AppColors.adminSidebar,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                i18n.t('settlement_voucher_total_label'),
                style: TextStyle(
                  fontSize: 14 * fontScale,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(width: 12 * fontScale),
              Text(
                '${formatAmount(voucherTotal)} ${i18n.t('admin_currency_krw')}',
                style: TextStyle(
                  fontSize: 15 * fontScale,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void _showDetailDialog(
  BuildContext context, {
  required String title,
  required List<Map<String, dynamic>> details,
  required double fontScale,
  required I18nHelper i18n,
  required String Function(int) formatAmount,
  required String Function(num) formatHours,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${i18n.t('settlement_detail_title')} — $title'),
      content: SizedBox(
        width: double.maxFinite,
        child: details.isEmpty
            ? Text(i18n.t('settlement_empty'))
            : SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.adminSidebar),
                  columnSpacing: 16 * fontScale,
                  columns: [
                    DataColumn(label: Text(i18n.t('settlement_detail_date'))),
                    DataColumn(label: Text(i18n.t('settlement_detail_time')), numeric: true),
                    DataColumn(label: Text(i18n.t('settlement_detail_amount')), numeric: true),
                  ],
                  rows: details
                      .map(
                        (d) => DataRow(
                          cells: [
                            DataCell(Text((d['date'] ?? '').toString())),
                            DataCell(Text(
                                '${d['start_time'] ?? ''} ~ ${d['end_time'] ?? ''} (${formatHours((d['hours'] as num?) ?? 0)}h)')),
                            DataCell(Text(formatAmount((d['amount'] as int?) ?? 0))),
                          ],
                        ),
                      )
                      .toList(),
                ),
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
