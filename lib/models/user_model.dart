class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String title;
  final String? orgUnitId;
  final String status; // "Active" | "Inactive"
  final String role; // "User" | "Administrator"
  final String createdBy;
  final DateTime createdAt;
  final String lastModifiedBy;
  final DateTime lastModifiedAt;

  UserModel({
    required String id,
    required this.fullName,
    required String email,
    required this.title,
    this.orgUnitId,
    required this.status,
    required this.role,
    String? createdBy,
    DateTime? createdAt,
    String? lastModifiedBy,
    DateTime? lastModifiedAt,
  }) : id = id.trim().toLowerCase(),
       email = email.trim().toLowerCase(),
       createdBy = createdBy ?? 'system',
       createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
       lastModifiedBy = lastModifiedBy ?? 'system',
       lastModifiedAt =
           lastModifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? title,
    String? Function()? orgUnitId,
    String? status,
    String? role,
    String? createdBy,
    DateTime? createdAt,
    String? lastModifiedBy,
    DateTime? lastModifiedAt,
  }) => UserModel(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    title: title ?? this.title,
    orgUnitId: orgUnitId != null ? orgUnitId() : this.orgUnitId,
    status: status ?? this.status,
    role: role ?? this.role,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'title': title,
    'orgUnitId': orgUnitId,
    'status': status,
    'role': role,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'lastModifiedBy': lastModifiedBy,
    'lastModifiedAt': lastModifiedAt.toIso8601String(),
  };

  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.parse(val);
      try {
        return (val as dynamic).toDate();
      } catch (_) {
        try {
          return DateTime.parse(val.toString());
        } catch (_) {
          return null;
        }
      }
    }

    return UserModel(
      id: map['id'],
      fullName: map['fullName'],
      email: map['email'],
      title: map['title'],
      orgUnitId: map['orgUnitId'],
      status: map['status'],
      role: map['role'],
      createdBy: map['createdBy'],
      createdAt: parseDate(map['createdAt']),
      lastModifiedBy: map['lastModifiedBy'],
      lastModifiedAt: parseDate(map['lastModifiedAt']),
    );
  }
}
