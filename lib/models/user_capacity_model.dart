class UserCapacityModel {
  final String id;
  final String userEmail;
  final String type; // "Standard" | "Specific"
  final DateTime? startDate;
  final DateTime? endDate;
  final double monday;
  final double tuesday;
  final double wednesday;
  final double thursday;
  final double friday;
  final double saturday;
  final double sunday;
  final String createdBy;
  final DateTime createdAt;
  final String lastModifiedBy;
  final DateTime lastModifiedAt;

  UserCapacityModel({
    required this.id,
    required String userEmail,
    required this.type,
    this.startDate,
    this.endDate,
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
    String? createdBy,
    DateTime? createdAt,
    String? lastModifiedBy,
    DateTime? lastModifiedAt,
  }) : userEmail = userEmail.trim().toLowerCase(),
       createdBy = createdBy ?? 'system',
       createdAt = createdAt ?? DateTime.now(),
       lastModifiedBy = lastModifiedBy ?? 'system',
       lastModifiedAt = lastModifiedAt ?? DateTime.now();

  double get sum =>
      monday + tuesday + wednesday + thursday + friday + saturday + sunday;

  UserCapacityModel copyWith({
    String? id,
    String? userEmail,
    String? type,
    DateTime? Function()? startDate,
    DateTime? Function()? endDate,
    double? monday,
    double? tuesday,
    double? wednesday,
    double? thursday,
    double? friday,
    double? saturday,
    double? sunday,
    String? createdBy,
    DateTime? createdAt,
    String? lastModifiedBy,
    DateTime? lastModifiedAt,
  }) => UserCapacityModel(
    id: id ?? this.id,
    userEmail: userEmail ?? this.userEmail,
    type: type ?? this.type,
    startDate: startDate != null ? startDate() : this.startDate,
    endDate: endDate != null ? endDate() : this.endDate,
    monday: monday ?? this.monday,
    tuesday: tuesday ?? this.tuesday,
    wednesday: wednesday ?? this.wednesday,
    thursday: thursday ?? this.thursday,
    friday: friday ?? this.friday,
    saturday: saturday ?? this.saturday,
    sunday: sunday ?? this.sunday,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'userEmail': userEmail,
    'type': type,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'monday': monday,
    'tuesday': tuesday,
    'wednesday': wednesday,
    'thursday': thursday,
    'friday': friday,
    'saturday': saturday,
    'sunday': sunday,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'lastModifiedBy': lastModifiedBy,
    'lastModifiedAt': lastModifiedAt.toIso8601String(),
  };

  factory UserCapacityModel.fromMap(Map<String, dynamic> map) =>
      UserCapacityModel(
        id: map['id'],
        userEmail: map['userEmail'],
        type: map['type'],
        startDate: map['startDate'] != null
            ? DateTime.parse(map['startDate'])
            : null,
        endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
        monday: (map['monday'] as num).toDouble(),
        tuesday: (map['tuesday'] as num).toDouble(),
        wednesday: (map['wednesday'] as num).toDouble(),
        thursday: (map['thursday'] as num).toDouble(),
        friday: (map['friday'] as num).toDouble(),
        saturday: (map['saturday'] as num).toDouble(),
        sunday: (map['sunday'] as num).toDouble(),
        createdBy: map['createdBy'] ?? 'system',
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'])
            : DateTime.now(),
        lastModifiedBy: map['lastModifiedBy'] ?? 'system',
        lastModifiedAt: map['lastModifiedAt'] != null
            ? DateTime.parse(map['lastModifiedAt'])
            : DateTime.now(),
      );
}
