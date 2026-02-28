/// 비상연락처 한 건 (DB name, phone, relation 그대로 사용).
class EmergencyContactItem {
  final String name;
  final String phone;
  final String relation;

  EmergencyContactItem({
    required this.name,
    required this.phone,
    required this.relation,
  });

  factory EmergencyContactItem.fromJson(Map<String, dynamic> json) {
    return EmergencyContactItem(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      relation: json['relation'] as String? ?? '',
    );
  }
}

/// GET /api/admin/clients 목록 응답 항목.
class AdminClientListItem {
  final int id;
  final String name;
  final String? phone;
  final String residentNoDisplayMasked;
  final String? gender;
  final int voucherBalance;
  final String status;
  final List<EmergencyContactItem> emergencyContacts;

  AdminClientListItem({
    required this.id,
    required this.name,
    this.phone,
    required this.residentNoDisplayMasked,
    this.gender,
    required this.voucherBalance,
    required this.status,
    required this.emergencyContacts,
  });

  factory AdminClientListItem.fromJson(Map<String, dynamic> json) {
    final contactsRaw = json['emergency_contacts'] as List?;
    final contacts = contactsRaw != null
        ? contactsRaw
            .whereType<Map<String, dynamic>>()
            .map((e) => EmergencyContactItem.fromJson(e))
            .toList()
        : <EmergencyContactItem>[];
    return AdminClientListItem(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      residentNoDisplayMasked: json['resident_no_display_masked'] as String? ?? '******-*******',
      gender: json['gender'] as String?,
      voucherBalance: (json['voucher_balance'] is int)
          ? json['voucher_balance'] as int
          : int.tryParse(json['voucher_balance']?.toString() ?? '0') ?? 0,
      status: json['status'] as String? ?? 'active',
      emergencyContacts: contacts,
    );
  }
}
