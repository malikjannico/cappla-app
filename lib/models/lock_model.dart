// File: lib/models/lock_model.dart

class LockModel {
  final String id; // Unique or deterministic document ID
  final String userId;
  final String userEmail;
  final String userFullName;
  final String lockType; // "activity" | "employee"
  final String? activityId; // For lockType == "activity"
  final List<String> activityIds; // For lockType == "employee"
  final List<String> employeeEmails; // For lockType == "employee"
  final int year;
  final String orgUnitId;
  final DateTime lockedAt;
  final DateTime expiresAt;

  LockModel({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userFullName,
    required this.lockType,
    this.activityId,
    required this.activityIds,
    required this.employeeEmails,
    required this.year,
    required this.orgUnitId,
    required this.lockedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  LockModel copyWith({
    String? id,
    String? userId,
    String? userEmail,
    String? userFullName,
    String? lockType,
    String? Function()? activityId,
    List<String>? activityIds,
    List<String>? employeeEmails,
    int? year,
    String? orgUnitId,
    DateTime? lockedAt,
    DateTime? expiresAt,
  }) => LockModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    userEmail: userEmail ?? this.userEmail,
    userFullName: userFullName ?? this.userFullName,
    lockType: lockType ?? this.lockType,
    activityId: activityId != null ? activityId() : this.activityId,
    activityIds: activityIds ?? this.activityIds,
    employeeEmails: employeeEmails ?? this.employeeEmails,
    year: year ?? this.year,
    orgUnitId: orgUnitId ?? this.orgUnitId,
    lockedAt: lockedAt ?? this.lockedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'userEmail': userEmail,
    'userFullName': userFullName,
    'lockType': lockType,
    'activityId': activityId,
    'activityIds': activityIds,
    'employeeEmails': employeeEmails,
    'year': year,
    'orgUnitId': orgUnitId,
    'lockedAt': lockedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory LockModel.fromMap(Map<String, dynamic> map) => LockModel(
    id: map['id'] ?? '',
    userId: map['userId'] ?? '',
    userEmail: map['userEmail'] ?? '',
    userFullName: map['userFullName'] ?? '',
    lockType: map['lockType'] ?? '',
    activityId: map['activityId'],
    activityIds: List<String>.from(map['activityIds'] ?? []),
    employeeEmails: List<String>.from(map['employeeEmails'] ?? []),
    year: map['year'] ?? 0,
    orgUnitId: map['orgUnitId'] ?? '',
    lockedAt: map['lockedAt'] != null
        ? DateTime.parse(map['lockedAt'])
        : DateTime.fromMillisecondsSinceEpoch(0),
    expiresAt: map['expiresAt'] != null
        ? DateTime.parse(map['expiresAt'])
        : DateTime.fromMillisecondsSinceEpoch(0),
  );
}
