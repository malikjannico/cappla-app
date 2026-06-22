class CategoryModel {
  final String id;
  final String name;
  final String ownerOrgUnitId;
  final List<String> sharedOrgUnitIds;
  final List<String> appliedOrgUnitIds;
  final Map<String, String> statusMap; // orgUnitId -> "Active" | "Inactive"
  final String createdBy;
  final DateTime createdAt;
  final String lastModifiedBy;
  final DateTime lastModifiedAt;
  final int order;

  CategoryModel({
    required this.id,
    required this.name,
    required this.ownerOrgUnitId,
    required this.sharedOrgUnitIds,
    required this.appliedOrgUnitIds,
    required this.statusMap,
    required this.createdBy,
    required this.createdAt,
    required this.lastModifiedBy,
    required this.lastModifiedAt,
    required this.order,
  });

  CategoryModel copyWith({
    String? id,
    String? name,
    String? ownerOrgUnitId,
    List<String>? sharedOrgUnitIds,
    List<String>? appliedOrgUnitIds,
    Map<String, String>? statusMap,
    String? createdBy,
    DateTime? createdAt,
    String? lastModifiedBy,
    DateTime? lastModifiedAt,
    int? order,
  }) => CategoryModel(
    id: id ?? this.id,
    name: name ?? this.name,
    ownerOrgUnitId: ownerOrgUnitId ?? this.ownerOrgUnitId,
    sharedOrgUnitIds: sharedOrgUnitIds ?? this.sharedOrgUnitIds,
    appliedOrgUnitIds: appliedOrgUnitIds ?? this.appliedOrgUnitIds,
    statusMap: statusMap ?? this.statusMap,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
    order: order ?? this.order,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'ownerOrgUnitId': ownerOrgUnitId,
    'sharedOrgUnitIds': sharedOrgUnitIds,
    'appliedOrgUnitIds': appliedOrgUnitIds,
    'statusMap': statusMap,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'lastModifiedBy': lastModifiedBy,
    'lastModifiedAt': lastModifiedAt.toIso8601String(),
    'order': order,
  };

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
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

    return CategoryModel(
      id: map['id'],
      name: map['name'],
      ownerOrgUnitId: map['ownerOrgUnitId'],
      sharedOrgUnitIds: List<String>.from(map['sharedOrgUnitIds'] ?? []),
      appliedOrgUnitIds: List<String>.from(map['appliedOrgUnitIds'] ?? []),
      statusMap: Map<String, String>.from(map['statusMap'] ?? {}),
      createdBy: map['createdBy'] ?? '',
      createdAt: parseDate(map['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      lastModifiedBy: map['lastModifiedBy'] ?? '',
      lastModifiedAt: parseDate(map['lastModifiedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      order: map['order'] ?? 0,
    );
  }
}
