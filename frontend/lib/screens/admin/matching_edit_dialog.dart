import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../models/admin_client_list_item.dart';
import '../../models/admin_matching_list_item.dart';
import '../../models/admin_member_user.dart';
import '../../providers/admin_members_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/i18n_helper.dart';

/// 매칭 수정 다이얼로그. 이미 시작/종료된 매칭은 시작·종료 일시 필드 비활성화.
class MatchingEditDialog {
  MatchingEditDialog._();

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
    AdminMatchingListItem item,
  ) async {
    final helpers = await ref.read(adminHelpersForMatchingProvider.future);
    final clients = await ref.read(adminClientsForMatchingProvider.future);

    AdminMemberUser? selectedHelper;
    for (final u in helpers) {
      if (u.userId == item.userId) {
        selectedHelper = u;
        break;
      }
    }
    AdminClientListItem? selectedClient;
    if (item.clientId != null) {
      for (final c in clients) {
        if (c.id == item.clientId) {
          selectedClient = c;
          break;
        }
      }
    }

    final wageC = TextEditingController(text: item.hourlyWage.toString());

    DateTime startDate = DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    DateTime endDate = DateTime.now();
    TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 0);
    if (item.startAt != null) {
      final s = DateTime.tryParse(item.startAt!);
      if (s != null) {
        final local = s.toLocal();
        startDate = local;
        startTime = TimeOfDay(hour: local.hour, minute: local.minute);
      }
    }
    if (item.endAt != null) {
      final e = DateTime.tryParse(item.endAt!);
      if (e != null) {
        final local = e.toLocal();
        endDate = local;
        endTime = TimeOfDay(hour: local.hour, minute: local.minute);
      }
    }

    final canEditTime = item.canEditTime;
    String dialogError = '';

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
                Expanded(child: Text(i18n.t('admin_matching_edit_dialog_title'))),
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
                      onChanged: canEditTime ? (u) => setState(() => selectedHelper = u) : null,
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
                      onChanged: canEditTime ? (c) => setState(() => selectedClient = c) : null,
                    ),
                    SizedBox(height: 12 * fontScale),
                    TextFormField(
                      controller: wageC,
                      decoration: InputDecoration(
                        labelText: i18n.t('admin_matching_wage_label'),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    SizedBox(height: 12 * fontScale),
                    if (!canEditTime)
                      Padding(
                        padding: EdgeInsets.only(bottom: 8 * fontScale),
                        child: Text(
                          i18n.t('admin_matching_time_locked_hint'),
                          style: TextStyle(fontSize: 12 * fontScale, color: AppColors.textSecondary),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: canEditTime
                              ? OutlinedButton(
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
                                        setState(() { startDate = d; startTime = t; });
                                      }
                                    }
                                  },
                                  child: Text(i18n.t('admin_matching_start_label'), style: TextStyle(fontSize: 13 * fontScale)),
                                )
                              : InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: i18n.t('admin_matching_start_label'),
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                  ),
                                  child: Text(AdminMatchingListItem.formatDateTime(item.startAt), style: TextStyle(fontSize: 14 * fontScale)),
                                ),
                        ),
                        if (canEditTime) SizedBox(width: 8 * fontScale),
                        if (canEditTime) Text(startDisplay(), style: TextStyle(fontSize: 13 * fontScale)),
                      ],
                    ),
                    SizedBox(height: 8 * fontScale),
                    Row(
                      children: [
                        Expanded(
                          child: canEditTime
                              ? OutlinedButton(
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
                                      if (t != null) setState(() { endDate = d; endTime = t; });
                                    }
                                  },
                                  child: Text(i18n.t('admin_matching_end_label'), style: TextStyle(fontSize: 13 * fontScale)),
                                )
                              : InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: i18n.t('admin_matching_end_label'),
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                  ),
                                  child: Text(AdminMatchingListItem.formatDateTime(item.endAt), style: TextStyle(fontSize: 14 * fontScale)),
                                ),
                        ),
                        if (canEditTime) SizedBox(width: 8 * fontScale),
                        if (canEditTime) Text(endDisplay(), style: TextStyle(fontSize: 13 * fontScale)),
                      ],
                    ),
                    if (dialogError.isNotEmpty) ...[
                      SizedBox(height: 12 * fontScale),
                      Text(dialogError, style: TextStyle(color: AppColors.error, fontSize: 13 * fontScale)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(i18n.t('cancel'))),
              FilledButton(
                onPressed: () async {
                  final wage = int.tryParse(wageC.text.trim());
                  if (wage == null || wage < 0) {
                    setState(() => dialogError = i18n.t('admin_matching_required_wage'));
                    return;
                  }
                  if (canEditTime && selectedHelper != null && selectedClient != null) {
                    final startLocal = DateTime(startDate.year, startDate.month, startDate.day, startTime.hour, startTime.minute);
                    if (startLocal.isBefore(DateTime.now())) {
                      setState(() => dialogError = i18n.t('admin_matching_start_must_be_future'));
                      return;
                    }
                    final endLocal = DateTime(endDate.year, endDate.month, endDate.day, endTime.hour, endTime.minute);
                    if (!endLocal.isAfter(startLocal)) {
                      setState(() => dialogError = i18n.t('admin_matching_end_after_start'));
                      return;
                    }
                  }
                  setState(() => dialogError = '');
                  final payload = <String, dynamic>{'hourly_wage': wage};
                  if (canEditTime && selectedHelper != null && selectedClient != null) {
                    payload['helper_id'] = selectedHelper!.userId;
                    payload['client_id'] = selectedClient!.id;
                    payload['start_at'] = _toLocalTimeString(startDate, startTime);
                    payload['end_at'] = _toLocalTimeString(endDate, endTime);
                  }
                  try {
                    await ref.read(apiServiceProvider).patchAdminMatching(item.id, payload);
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(i18n.t('admin_matching_updated'))));
                  } on DioException catch (e) {
                    final data = e.response?.data;
                    String msg = (data is Map && data['message'] != null) ? data['message'].toString() : i18n.t('admin_register_failed');
                    setState(() => dialogError = msg);
                  }
                },
                child: Text(i18n.t('confirm')),
              ),
            ],
          );
        },
      ),
    );
  }
}
