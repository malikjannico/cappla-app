import 'enums.dart';

class UserCapacityModel {
  final String id;
  final String userEmail;
  final CapacityType type;
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
    required dynamic type,
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
       type = type is CapacityType ? type : CapacityType.fromString(type.toString()),
       createdBy = createdBy ?? 'system',
       createdAt = createdAt ?? DateTime.now(),
       lastModifiedBy = lastModifiedBy ?? 'system',
       lastModifiedAt = lastModifiedAt ?? DateTime.now();

  double get sum =>
      monday + tuesday + wednesday + thursday + friday + saturday + sunday;

  UserCapacityModel copyWith({
    String? id,
    String? userEmail,
    dynamic type,
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
    'type': type.value,
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

  factory UserCapacityModel.fromMap(Map<String, dynamic> map) {
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

    return UserCapacityModel(
      id: map['id'] ?? '',
      userEmail: map['userEmail'] ?? '',
      type: CapacityType.fromString(map['type'] ?? 'Standard'),
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
      monday: (map['monday'] as num?)?.toDouble() ?? 0.0,
      tuesday: (map['tuesday'] as num?)?.toDouble() ?? 0.0,
      wednesday: (map['wednesday'] as num?)?.toDouble() ?? 0.0,
      thursday: (map['thursday'] as num?)?.toDouble() ?? 0.0,
      friday: (map['friday'] as num?)?.toDouble() ?? 0.0,
      saturday: (map['saturday'] as num?)?.toDouble() ?? 0.0,
      sunday: (map['sunday'] as num?)?.toDouble() ?? 0.0,
      createdBy: map['createdBy'] ?? 'system',
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      lastModifiedBy: map['lastModifiedBy'] ?? 'system',
      lastModifiedAt: parseDate(map['lastModifiedAt']) ?? DateTime.now(),
    );
  }
}
