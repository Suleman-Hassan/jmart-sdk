class ContactInfo {
  final int? id;
  final String? email;
  final String? phone;
  final String? whatsapp;

  ContactInfo({this.id, this.email, this.phone, this.whatsapp});

  factory ContactInfo.fromJson(Map<String, dynamic> json) {
    return ContactInfo(
      id: json['id'] as int?,
      email: (json['email'] as String?)?.trim(),
      phone: (json['phone'] as String?)?.trim(),
      whatsapp: (json['whatsapp'] as String?)?.trim(),
    );
  }
}