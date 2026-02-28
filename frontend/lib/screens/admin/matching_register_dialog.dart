import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../models/admin_client_list_item.dart';
import '../../models/admin_member_user.dart';
import '../../providers/admin_members_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/i18n_helper.dart';

/// 매칭 등록 다이얼로그. 보호사/이용자 선택, 시급(보호사 선택 시 기본 시급 자동 로드·수정 가능), 시작/종료 일시.
class MatchingRegisterDialog {
  MatchingRegisterDialog._();

  static String _formatDateTime(DateTime date, TimeOfDay time) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(
      DateTime(date.year, date.month, date.day, time.hour, time.minute, 0),
    );
  }

  /// 서버 전송용: 기기 로컬 시간을 DateFormat으로만 전송. .toUtc()/Z 붙은 ISO 사용 금지.
  static String _toLocalTimeString(DateTime date, TimeOfDay time) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(
      DateTime(date.year, date.month, date.day, time.hour, time.minute, 0),
    );
  }

  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    double fontScale,
    I18nHelper i18n,
  ) async {
    final helpers = await ref.read(adminHelpersForMatchingProvider.future);
    final clients = await ref.read(adminClientsForMatchingProvider.future);

    AdminMemberUser? selectedHelper;
    AdminClientListItem? selectedClient;
    final wageC = TextEditingController(text: '16150');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime startDate = today;
    TimeOfDay startTime = TimeOfDay(hour: now.hour, minute: now.minute);
    DateTime endDate = today;
    TimeOfDay endTime = now.hour >= 18
        ? TimeOfDay(hour: now.hour, minute: now.minute)
        : const TimeOfDay(hour: 18, minute: 0);
    String dialogError = '';

    void updateWageFromHelper() {
      if (selectedHelper != null) {
        wageC.text = selectedHelper!.defaultHourlyWage.toString();
      }
    }

    String startDisplay() => _formatDateTime(startDate, startTime);
    String endDisplay() => _formatDateTime(endDate, endTime);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                Expanded(child: Text(i18n.t('admin_matching_dialog_title'))),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                  tooltip: i18n.t('cancel'),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<AdminMemberUser>(
                      value: selectedHelper,
                      decoration: InputDecoration(
                        labelText: i18n.t('admin_matching_helper_label'),
                        border: const OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<AdminMemberUser>(value: null, child: Text('—')),
                        ...helpers.map((u) => DropdownMenuItem<AdminMemberUser>(
                              value: u,
                              child: Text('${u.name} (${u.loginId.isNotEmpty ? u.loginId : u.loginIdMasked})'),
                            )),
                      ],
                      onChanged: (u) {
                        setState(() {
                          selectedHelper = u;
                          updateWageFromHelper();
                        });
                      },
                    ),
                    SizedBox(height: 12 * fontScale),
                    DropdownButtonFormField<AdminClientListItem>(
                      value: selectedClient,
                      decoration: InputDecoration(
                        labelText: i18n.t('admin_matching_client_label'),
                        border: const OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<AdminClientListItem>(value: null, child: Text('—')),
                        ...clients.map((c) => DropdownMenuItem<AdminClientListItem>(
                              value: c,
                              child: Text(c.name),
                            )),
                      ],
                      onChanged: (c) => setState(() => selectedClient = c),
                    ),
                    SizedBox(height: 12 * fontScale),
                    TextFormField(
                      controller: wageC,
                      decoration: InputDecoration(
                        labelText: i18n.t('admin_matching_wage_label'),
                        hintText: i18n.t('admin_matching_wage_hint'),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    SizedBox(height: 12 * fontScale),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final now = DateTime.now();
                              final today = DateTime(now.year, now.month, now.day);
                              final d = await showDatePicker(
                                context: context,
                                initialDate: startDate.isBefore(today) ? today : startDate,
                                firstDate: today,
                                lastDate: DateTime(2030),
                              );
                              if (d != null && context.mounted) {
                                final isStartToday = d.year == now.year && d.month == now.month && d.day == now.day;
                                final initialStart = isStartToday && (startTime.hour < now.hour || (startTime.hour == now.hour && startTime.minute < now.minute))
                                    ? TimeOfDay(hour: now.hour, minute: now.minute)
                                    : startTime;
                                final t = await showTimePicker(context: context, initialTime: initialStart);
                                if (t != null && context.mounted) {
                                  final chosen = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                                  if (chosen.isBefore(now)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(i18n.t('admin_matching_start_must_be_future'))),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    startDate = d;
                                    startTime = t;
                                  });
                                }
                              }
                            },
                            child: Text(i18n.t('admin_matching_start_label'), style: TextStyle(fontSize: 13 * fontScale)),
                          ),
                        ),
                        SizedBox(width: 8 * fontScale),
                        Text(startDisplay(), style: TextStyle(fontSize: 13 * fontScale)),
                      ],
                    ),
                    SizedBox(height: 8 * fontScale),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final startDay = DateTime(startDate.year, startDate.month, startDate.day);
                              final d = await showDatePicker(
                                context: context,
                                initialDate: endDate.isBefore(startDay) ? startDay : endDate,
                                firstDate: startDay,
                                lastDate: DateTime(2030),
                              );
                              if (d != null && context.mounted) {
                                final t = await showTimePicker(context: context, initialTime: endTime);
                                if (t != null) {
                                  setState(() {
                                    endDate = d;
                                    endTime = t;
                                  });
                                }
                              }
                            },
                            child: Text(i18n.t('admin_matching_end_label'), style: TextStyle(fontSize: 13 * fontScale)),
                          ),
                        ),
                        SizedBox(width: 8 * fontScale),
                        Text(endDisplay(), style: TextStyle(fontSize: 13 * fontScale)),
                      ],
                    ),
                    if (dialogError.isNotEmpty) ...[
                      SizedBox(height: 12 * fontScale),
                      Text(
                        dialogError,
                        style: TextStyle(color: AppColors.error, fontSize: 13 * fontScale),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(i18n.t('cancel')),
              ),
              FilledButton(
                onPressed: () async {
                  if (selectedHelper == null || selectedClient == null) {
                    setState(() => dialogError = i18n.t('admin_matching_required_helper_client'));
                    return;
                  }
                  final wage = int.tryParse(wageC.text.trim());
                  if (wage == null || wage < 0) {
                    setState(() => dialogError = i18n.t('admin_matching_required_wage'));
                    return;
                  }
                  final startLocal = DateTime(startDate.year, startDate.month, startDate.day, startTime.hour, startTime.minute);
                  final endLocal = DateTime(endDate.year, endDate.month, endDate.day, endTime.hour, endTime.minute);
                  if (startLocal.isBefore(DateTime.now())) {
                    setState(() => dialogError = i18n.t('admin_matching_start_must_be_future'));
                    return;
                  }
                  if (!endLocal.isAfter(startLocal)) {
                    setState(() => dialogError = i18n.t('admin_matching_end_after_start'));
                    return;
                  }
                  final startAt = _toLocalTimeString(startDate, startTime);
                  final endAt = _toLocalTimeString(endDate, endTime);
                  setState(() => dialogError = '');
                  try {
                    final res = await ref.read(apiServiceProvider).postAdminMatching({
                      'helper_id': selectedHelper!.userId,
                      'client_id': selectedClient!.id,
                      'start_at': startAt,
                      'end_at': endAt,
                      'hourly_wage': wage,
                    });
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(i18n.t('matching_created'))),
                    );
                    final body = res.data;
                    if (body is Map && body['warning_insufficient_balance'] == true && ctx.mounted) {
                      final msg = body['insufficient_message']?.toString() ?? i18n.t('voucher_insufficient_balance');
                      final estimated = body['estimated_amount'];
                      final balance = body['client_balance'];
                      final detail = (estimated != null && balance != null)
                          ? ' (예상: ${NumberFormat('#,###').format(estimated)}원, 잔액: ${NumberFormat('#,###').format(balance)}원)'
                          : '';
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text('$msg$detail'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  } on DioException catch (e) {
                    final data = e.response?.data;
                    String msg = i18n.t('admin_register_failed');
                    if (data is Map && data['message'] != null) {
                      msg = data['message'].toString();
                    }
                    if (data is Map && data['errors'] is Map) {
                      final errors = (data['errors'] as Map).values;
                      final first = errors.expand((x) => x is List ? x : [x]).firstOrNull?.toString();
                      if (first != null && first.isNotEmpty) msg = first;
                    }
                    setState(() => dialogError = msg);
                  }
                },
                child: Text(i18n.t('admin_matching_register_submit')),
              ),
            ],
          );
        },
      ),
    );
  }
}
