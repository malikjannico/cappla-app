class OrgUnitModel {
  final String id;
  final String name;
  final String abbreviation;
  final String headOfEmail;
  final String
  type; // "md division", "svp division", "vp division", "department", "group", "team"
  final String? parentId;
  final List<String> childIds;
  final String status; // "Active" | "Inactive"
  final String createdBy;
  final DateTime createdAt;
  final String lastModifiedBy;
  final DateTime lastModifiedAt;

  OrgUnitModel({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.headOfEmail,
    required this.type,
    this.parentId,
    required this.childIds,
    required this.status,
    String? createdBy,
    DateTime? createdAt,
    String? lastModifiedBy,
    DateTime? lastModifiedAt,
  }) : createdBy = createdBy ?? 'system',
       createdAt = createdAt ?? DateTime.now(),
       lastModifiedBy = lastModifiedBy ?? 'system',
       lastModifiedAt = lastModifiedAt ?? DateTime.now();

  OrgUnitModel copyWith({
    String? id,
    String? name,
    String? abbreviation,
    String? headOfEmail,
    String? type,
    String? Function()? parentId,
    List<String>? childIds,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    String? lastModifiedBy,
    DateTime? lastModifiedAt,
  }) => OrgUnitModel(
    id: id ?? this.id,
    name: name ?? this.name,
    abbreviation: abbreviation ?? this.abbreviation,
    headOfEmail: headOfEmail ?? this.headOfEmail,
    type: type ?? this.type,
    parentId: parentId != null ? parentId() : this.parentId,
    childIds: childIds ?? this.childIds,
    status: status ?? this.status,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'abbreviation': abbreviation,
    'headOfEmail': headOfEmail,
    'type': type,
    'parentId': parentId,
    'childIds': childIds,
    'status': status,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'lastModifiedBy': lastModifiedBy,
    'lastModifiedAt': lastModifiedAt.toIso8601String(),
  };

  factory OrgUnitModel.fromMap(Map<String, dynamic> map) {
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

    return OrgUnitModel(
      id: map['id'],
      name: map['name'],
      abbreviation: map['abbreviation'],
      headOfEmail: map['headOfEmail'],
      type: map['type'],
      parentId: map['parentId'],
      childIds: List<String>.from(map['childIds'] ?? []),
      status: map['status'],
      createdBy: map['createdBy'],
      createdAt: parseDate(map['createdAt']),
      lastModifiedBy: map['lastModifiedBy'],
      lastModifiedAt: parseDate(map['lastModifiedAt']),
    );
  }
}
