import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../providers/admin_members_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/i18n_helper.dart';

/// 신규 회원 등록 다이얼로그 (보호사/이용자 선택 및 각 폼).
class AdminMemberRegisterDialogs {
  AdminMemberRegisterDialogs._();

  /// 보호사 / 이용자 선택
  static Future<void> showRegisterTypeChoice(
    BuildContext context,
    WidgetRef ref,
    double fontScale,
    I18nHelper i18n,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(i18n.t('admin_register_choose_type'))),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(ctx).pop(),
              tooltip: i18n.t('cancel'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person_add, color: AppColors.adminActive),
              title: Text(i18n.t('admin_register_helper')),
              subtitle: Text(i18n.t('admin_register_helper_hint'), style: TextStyle(fontSize: 12 * fontScale)),
              onTap: () {
            Navigator.of(ctx).pop();
              AdminMemberRegisterDialogs.showHelperRegisterDialog(context, ref, fontScale, i18n);
              },
            ),
            ListTile(
              leading: Icon(Icons.accessible, color: AppColors.primary),
              title: Text(i18n.t('admin_register_client')),
              subtitle: Text(i18n.t('admin_register_client_hint'), style: TextStyle(fontSize: 12 * fontScale)),
              onTap: () {
            Navigator.of(ctx).pop();
              AdminMemberRegisterDialogs.showClientRegisterDialog(context, ref, fontScale, i18n);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(i18n.t('cancel')),
          ),
        ],
      ),
    );
  }

  /// 보호사 등록 다이얼로그. 스마트 등록: 휴대폰 조회 후 기존 회원이면 비밀번호 숨김, 신규만 비밀번호 입력.
  static Future<void> showHelperRegisterDialog(
    BuildContext context,
    WidgetRef ref,
    double fontScale,
    I18nHelper i18n,
  ) async {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final passwordC = TextEditingController();
    final emailC = TextEditingController();
    String dialogError = '';
    bool? userExists;
    String? existingName;
    bool loadingCheck = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final isExistingMember = userExists == true;

          return AlertDialog(
            title: Row(
              children: [
                Expanded(child: Text(i18n.t('admin_register_helper'))),
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
                    TextField(
                      controller: nameC,
                      decoration: InputDecoration(
                        labelText: i18n.t('name'),
                        hintText: i18n.t('name_hint'),
                      ),
                      textCapitalization: TextCapitalization.none,
                    ),
                    SizedBox(height: 12 * fontScale),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: phoneC,
                            onChanged: (_) => setState(() => userExists = null),
                            decoration: InputDecoration(
                              labelText: i18n.t('admin_members_col_login_id'),
                              hintText: i18n.t('id_hint'),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        SizedBox(width: 8 * fontScale),
                        FilledButton(
                          onPressed: loadingCheck
                              ? null
                              : () async {
                                  final phone = phoneC.text.replaceAll(RegExp(r'[^0-9]'), '');
                                  if (phone.length < 10) {
                                    setState(() => dialogError = '전화번호 10자 이상 입력 후 조회해 주세요.');
                                    return;
                                  }
                                  setState(() {
                                    dialogError = '';
                                    loadingCheck = true;
                                  });
                                  try {
                                    final data = await ref.read(apiServiceProvider).getAdminUserCheck(phoneC.text);
                                    if (!ctx.mounted) return;
                                    setState(() {
                                      userExists = data['exists'] as bool? ?? false;
                                      existingName = data['name'] as String?;
                                      final nameToSet = existingName?.trim() ?? '';
                                      if (userExists == true && nameToSet.isNotEmpty) {
                                        nameC.text = nameToSet;
                                      }
                                      loadingCheck = false;
                                    });
                                  } catch (_) {
                                    if (ctx.mounted) setState(() {
                                      loadingCheck = false;
                                      dialogError = i18n.t('admin_register_failed');
                                    });
                                  }
                                },
                          child: Text(loadingCheck ? '...' : i18n.t('helper_smart_check_btn')),
                        ),
                      ],
                    ),
                    if (!isExistingMember) ...[
                      SizedBox(height: 12 * fontScale),
                      TextField(
                        controller: passwordC,
                        decoration: InputDecoration(
                          labelText: i18n.t('password'),
                          hintText: i18n.t('admin_setup_password_hint'),
                        ),
                        obscureText: true,
                      ),
                      SizedBox(height: 8 * fontScale),
                      Text(
                        i18n.t('helper_smart_new_password_hint'),
                        style: TextStyle(fontSize: 12 * fontScale, color: AppColors.textSecondary),
                      ),
                      SizedBox(height: 12 * fontScale),
                    ],
                    if (isExistingMember) ...[
                      SizedBox(height: 12 * fontScale),
                      Text(
                        i18n.t('helper_smart_existing_member_hint'),
                        style: TextStyle(fontSize: 13 * fontScale, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 12 * fontScale),
                    ],
                    TextField(
                      controller: emailC,
                      decoration: InputDecoration(
                        labelText: i18n.t('admin_members_col_email'),
                        hintText: 'example@email.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textCapitalization: TextCapitalization.none,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9@._%\-]')),
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
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(i18n.t('cancel'))),
              FilledButton(
                onPressed: () async {
                  setState(() => dialogError = '');
                  final name = nameC.text.trim();
                  final phone = phoneC.text.replaceAll("'", "").replaceAll(RegExp(r'[^0-9\-]'), '');
                  final password = passwordC.text;
                  final email = emailC.text.trim();
                  if (name.isEmpty) {
                    setState(() => dialogError = '이름을 입력해 주세요.');
                    return;
                  }
                  if (phone.length < 10) {
                    setState(() => dialogError = '전화번호는 10자 이상 입력해 주세요.');
                    return;
                  }
                  if (!isExistingMember && password.length < 10) {
                    setState(() => dialogError = '비밀번호는 10자 이상 입력해 주세요.');
                    return;
                  }
                  if (email.isNotEmpty && !RegExp(r'^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
                    setState(() => dialogError = '이메일 형식이 올바르지 않습니다.');
                    return;
                  }
                  final emailToSend = email.isEmpty ? '$phone@temp.local' : email;
                  final payload = <String, dynamic>{
                    'name': name,
                    'login_id': phone,
                    'email': emailToSend,
                  };
                  if (!isExistingMember) payload['password'] = password;
                  try {
                    final res = await ref.read(apiServiceProvider).postAdminUserStore(payload);
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    ref.invalidate(adminMembersProvider);
                    ref.invalidate(adminHelpersListProvider);
                    if (context.mounted) {
                      final data = res.data;
                      final affiliationAdded = data is Map && (data['affiliation_added'] == true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            affiliationAdded ? i18n.t('admin_register_success_affiliation') : i18n.t('admin_register_success_helper'),
                          ),
                        ),
                      );
                    }
                  } on DioException catch (e) {
                    String msg = i18n.t('admin_register_failed');
                    if (e.response?.data is Map) {
                      final d = e.response!.data as Map<String, dynamic>;
                      msg = d['message'] as String? ?? msg;
                      if (d['errors'] is Map) {
                        final errs = d['errors'] as Map;
                        final first = errs.values.isNotEmpty ? errs.values.first : null;
                        if (first is List && first.isNotEmpty) msg = first.first.toString();
                      }
                    }
                    if (ctx.mounted) setState(() => dialogError = msg);
                  }
                },
                child: Text(i18n.t('submit')),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 연락처: 숫자와 하이픈만 남김 (찌꺼기 기호 제거).
  static String _sanitizePhone(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw.replaceAll("'", "").replaceAll(RegExp(r'[^0-9\-]'), '');
  }

  /// 이용자 등록 다이얼로그. 성명, 주민번호(앞6-뒷7), 연락처, 비상연락망. 성별 자동 판별, 뒷7자리 암호화 안내.
  static Future<void> showClientRegisterDialog(
    BuildContext context,
    WidgetRef ref,
    double fontScale,
    I18nHelper i18n,
  ) async {
    final nameC = TextEditingController();
    final residentPrefixC = TextEditingController();
    final residentSuffixC = TextEditingController();
    final phoneC = TextEditingController();
    final voucherBalanceC = TextEditingController(text: '0');
    final contacts = <Map<String, String>>[];
    String dialogError = '';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
        final suffixFirst = residentSuffixC.text.isNotEmpty ? residentSuffixC.text[0] : null;
        String? genderLabel;
        if (suffixFirst != null) {
          if (suffixFirst == '1' || suffixFirst == '3') genderLabel = i18n.t('admin_register_gender_male');
          if (suffixFirst == '2' || suffixFirst == '4') genderLabel = i18n.t('admin_register_gender_female');
        }
        return AlertDialog(
          title: Row(
            children: [
              Expanded(child: Text(i18n.t('admin_register_client'))),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameC,
                    decoration: InputDecoration(labelText: i18n.t('name'), hintText: i18n.t('name_hint')),
                  ),
                  SizedBox(height: 12 * fontScale),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: residentPrefixC,
                          decoration: InputDecoration(
                            labelText: i18n.t('admin_register_resident_prefix'),
                            hintText: '900101',
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: residentSuffixC,
                          decoration: InputDecoration(
                            labelText: i18n.t('admin_register_resident_suffix'),
                            hintText: '*******',
                          ),
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          maxLength: 7,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  if (genderLabel != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('${i18n.t('admin_register_gender_auto')}: $genderLabel', style: TextStyle(fontSize: 12 * fontScale, color: AppColors.textSecondary)),
                    ),
                  TextField(
                    controller: phoneC,
                    decoration: InputDecoration(labelText: i18n.t('admin_register_phone'), hintText: i18n.t('id_hint')),
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: 12 * fontScale),
                  TextField(
                    controller: voucherBalanceC,
                    decoration: InputDecoration(
                      labelText: i18n.t('admin_register_voucher_balance'),
                      hintText: i18n.t('admin_register_voucher_balance_hint'),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 16 * fontScale),
                  Text(i18n.t('admin_register_emergency_contacts'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * fontScale)),
                  ...List.generate(contacts.length, (i) {
                    final c = contacts[i];
                    return Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: ValueKey('name_$i'),
                              initialValue: c['name'],
                              decoration: InputDecoration(labelText: i18n.t('admin_register_contact_name')),
                              onChanged: (v) => c['name'] = v,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              key: ValueKey('phone_$i'),
                              initialValue: c['phone'],
                              decoration: InputDecoration(labelText: i18n.t('admin_register_contact_phone')),
                              onChanged: (v) => c['phone'] = v,
                              maxLength: 100,
                              minLines: 1,
                              maxLines: null,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline, color: AppColors.error),
                            onPressed: () => setState(() => contacts.removeAt(i)),
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () => setState(() => contacts.add({'name': '', 'phone': ''})),
                    icon: Icon(Icons.add, size: 20),
                    label: Text(i18n.t('admin_register_add_contact')),
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
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(i18n.t('cancel'))),
            FilledButton(
              onPressed: () async {
                setState(() => dialogError = '');
                // 등록 시 전송할 값: 컨트롤러에서만 읽음. 더미/고정값 사용 금지.
                final name = nameC.text.trim();
                final prefixRaw = residentPrefixC.text.replaceAll("'", "").replaceAll(RegExp(r'[^0-9\-]'), '');
                final prefix = prefixRaw.length == 6 ? prefixRaw : null;
                final suffix = residentSuffixC.text.replaceAll("'", "").replaceAll(RegExp(r'[^0-9\-]'), '');
                final phoneSanitized = _sanitizePhone(phoneC.text);
                final voucherBalance = int.tryParse(voucherBalanceC.text.trim()) ?? 0;
                if (name.isEmpty) {
                  setState(() => dialogError = '이름을 입력해 주세요.');
                  return;
                }
                if (suffix.length != 7) {
                  setState(() => dialogError = '주민번호 뒷자리 7자리를 정확히 입력해 주세요.');
                  return;
                }
                final list = contacts.where((c) => (c['name'] ?? '').trim().isNotEmpty && (c['phone'] ?? '').trim().isNotEmpty).toList();
                final contactMaps = list
                    .map((c) => {'name': c['name']!.trim(), 'phone': (c['phone'] ?? '').trim()})
                    .where((c) => c['name']!.isNotEmpty && c['phone']!.isNotEmpty)
                    .toList();
                final payload = <String, dynamic>{
                  'name': name,
                  'resident_no_suffix': suffix,
                  'phone': phoneSanitized.isEmpty ? null : phoneSanitized,
                  'voucher_balance': voucherBalance >= 0 ? voucherBalance : 0,
                };
                if (prefix != null) payload['resident_no_prefix'] = prefix;
                if (contactMaps.isNotEmpty) payload['contacts'] = contactMaps;
                try {
                  await ref.read(apiServiceProvider).postAdminClientStore(payload);
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  ref.invalidate(adminMembersProvider);
                  ref.invalidate(adminClientsListProvider);
                  ref.invalidate(adminClientsForMatchingProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(i18n.t('admin_register_success_client'))),
                    );
                  }
                } on DioException catch (e) {
                  String msg = i18n.t('admin_register_failed');
                  if (e.response?.data is Map) {
                    final d = e.response!.data as Map<String, dynamic>;
                    msg = d['message'] as String? ?? msg;
                    if (d['errors'] is Map) {
                      final errs = d['errors'] as Map;
                      final first = errs.values.isNotEmpty ? errs.values.first : null;
                      if (first is List && first.isNotEmpty) msg = first.first.toString();
                    }
                  }
                  if (ctx.mounted) setState(() => dialogError = msg);
                }
              },
              child: Text(i18n.t('submit')),
            ),
          ],
        );
        },
      ),
    );
  }
}
