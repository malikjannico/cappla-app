import 'enums.dart';

class ActivityModel {
  final String id;
  final String name;
  final String activityGroupId;
  final String? categoryId;
  final ActivityType type;
  final DateTime? validityStart;
  final DateTime? validityEnd;
  final String ownerOrgUnitId;
  final List<String> sharedOrgUnitIds;
  final List<String> appliedOrgUnitIds;
  final Map<String, String> statusMap; // orgUnitId -> "Active" | "Inactive"
  final String createdBy;
  final DateTime createdAt;
  final String lastModifiedBy;
  final DateTime lastModifiedAt;
  final int order;
  final List<String> assignedUserEmails;

  ActivityModel({
    required this.id,
    required this.name,
    required this.activityGroupId,
    this.categoryId,
    required dynamic type,
    this.validityStart,
    this.validityEnd,
    required this.ownerOrgUnitId,
    required this.sharedOrgUnitIds,
    required this.appliedOrgUnitIds,
    required this.statusMap,
    required this.createdBy,
    required this.createdAt,
    required this.lastModifiedBy,
    required this.lastModifiedAt,
    required this.order,
    this.assignedUserEmails = const [],
  }) : type = type is ActivityType ? type : ActivityType.fromString(type.toString());

  ActivityModel copyWith({
    String? id,
    String? name,
    String? activityGroupId,
    String? Function()? categoryId,
    dynamic type,
    DateTime? Function()? validityStart,
    DateTime? Function()? validityEnd,
    String? ownerOrgUnitId,
    List<String>? sharedOrgUnitIds,
    List<String>? appliedOrgUnitIds,
    Map<String, String>? statusMap,
    String? createdBy,
    DateTime? createdAt,
    String? lastModifiedBy,
    DateTime? lastModifiedAt,
    int? order,
    List<String>? assignedUserEmails,
  }) => ActivityModel(
    id: id ?? this.id,
    name: name ?? this.name,
    activityGroupId: activityGroupId ?? this.activityGroupId,
    categoryId: categoryId != null ? categoryId() : this.categoryId,
    type: type != null ? (type is ActivityType ? type : ActivityType.fromString(type.toString())) : this.type,
    validityStart: validityStart != null ? validityStart() : this.validityStart,
    validityEnd: validityEnd != null ? validityEnd() : this.validityEnd,
    ownerOrgUnitId: ownerOrgUnitId ?? this.ownerOrgUnitId,
    sharedOrgUnitIds: sharedOrgUnitIds ?? this.sharedOrgUnitIds,
    appliedOrgUnitIds: appliedOrgUnitIds ?? this.appliedOrgUnitIds,
    statusMap: statusMap ?? this.statusMap,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
    order: order ?? this.order,
    assignedUserEmails: assignedUserEmails ?? this.assignedUserEmails,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'activityGroupId': activityGroupId,
    'categoryId': categoryId,
    'type': type.value,
    'validityStart': validityStart?.toIso8601String(),
    'validityEnd': validityEnd?.toIso8601String(),
    'ownerOrgUnitId': ownerOrgUnitId,
    'sharedOrgUnitIds': sharedOrgUnitIds,
    'appliedOrgUnitIds': appliedOrgUnitIds,
    'statusMap': statusMap,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'lastModifiedBy': lastModifiedBy,
    'lastModifiedAt': lastModifiedAt.toIso8601String(),
    'order': order,
    'assignedUserEmails': assignedUserEmails,
  };

  factory ActivityModel.fromMap(Map<String, dynamic> map) {
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

    return ActivityModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      activityGroupId: map['activityGroupId'] ?? '',
      categoryId: map['categoryId'],
      type: ActivityType.fromString(map['type'] ?? 'Unlimited'),
      validityStart: parseDate(map['validityStart']),
      validityEnd: parseDate(map['validityEnd']),
      ownerOrgUnitId: map['ownerOrgUnitId'] ?? '',
      sharedOrgUnitIds: List<String>.from(map['sharedOrgUnitIds'] ?? []),
      appliedOrgUnitIds: List<String>.from(map['appliedOrgUnitIds'] ?? []),
      statusMap: Map<String, String>.from(map['statusMap'] ?? {}),
      createdBy: map['createdBy'] ?? '',
      createdAt: parseDate(map['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      lastModifiedBy: map['lastModifiedBy'] ?? '',
      lastModifiedAt: parseDate(map['lastModifiedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      order: map['order'] ?? 0,
      assignedUserEmails: List<String>.from(map['assignedUserEmails'] ?? []),
    );
  }
}
