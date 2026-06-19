// File: lib/models/planning_allocation_model.dart

class PlanningAllocationModel {
  final String id; // userEmail_activityId_year
  final String userEmail;
  final String activityId;
  final int year;
  final String orgUnitId;
  final double january;
  final double february;
  final double march;
  final double april;
  final double may;
  final double june;
  final double july;
  final double august;
  final double september;
  final double october;
  final double november;
  final double december;

  PlanningAllocationModel({
    required this.id,
    required String userEmail,
    required this.activityId,
    required this.year,
    required this.orgUnitId,
    this.january = 0.0,
    this.february = 0.0,
    this.march = 0.0,
    this.april = 0.0,
    this.may = 0.0,
    this.june = 0.0,
    this.july = 0.0,
    this.august = 0.0,
    this.september = 0.0,
    this.october = 0.0,
    this.november = 0.0,
    this.december = 0.0,
  }) : userEmail = userEmail.trim().toLowerCase();

  double get sum =>
      january +
      february +
      march +
      april +
      may +
      june +
      july +
      august +
      september +
      october +
      november +
      december;

  PlanningAllocationModel copyWith({
    String? id,
    String? userEmail,
    String? activityId,
    int? year,
    String? orgUnitId,
    double? january,
    double? february,
    double? march,
    double? april,
    double? may,
    double? june,
    double? july,
    double? august,
    double? september,
    double? october,
    double? november,
    double? december,
  }) => PlanningAllocationModel(
    id: id ?? this.id,
    userEmail: userEmail ?? this.userEmail,
    activityId: activityId ?? this.activityId,
    year: year ?? this.year,
    orgUnitId: orgUnitId ?? this.orgUnitId,
    january: january ?? this.january,
    february: february ?? this.february,
    march: march ?? this.march,
    april: april ?? this.april,
    may: may ?? this.may,
    june: june ?? this.june,
    july: july ?? this.july,
    august: august ?? this.august,
    september: september ?? this.september,
    october: october ?? this.october,
    november: november ?? this.november,
    december: december ?? this.december,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'userEmail': userEmail,
    'activityId': activityId,
    'year': year,
    'orgUnitId': orgUnitId,
    'january': january,
    'february': february,
    'march': march,
    'april': april,
    'may': may,
    'june': june,
    'july': july,
    'august': august,
    'september': september,
    'october': october,
    'november': november,
    'december': december,
  };

  factory PlanningAllocationModel.fromMap(Map<String, dynamic> map) =>
      PlanningAllocationModel(
        id: map['id'] ?? '',
        userEmail: map['userEmail'] ?? '',
        activityId: map['activityId'] ?? '',
        year: map['year'] ?? 0,
        orgUnitId: map['orgUnitId'] ?? '',
        january: (map['january'] as num?)?.toDouble() ?? 0.0,
        february: (map['february'] as num?)?.toDouble() ?? 0.0,
        march: (map['march'] as num?)?.toDouble() ?? 0.0,
        april: (map['april'] as num?)?.toDouble() ?? 0.0,
        may: (map['may'] as num?)?.toDouble() ?? 0.0,
        june: (map['june'] as num?)?.toDouble() ?? 0.0,
        july: (map['july'] as num?)?.toDouble() ?? 0.0,
        august: (map['august'] as num?)?.toDouble() ?? 0.0,
        september: (map['september'] as num?)?.toDouble() ?? 0.0,
        october: (map['october'] as num?)?.toDouble() ?? 0.0,
        november: (map['november'] as num?)?.toDouble() ?? 0.0,
        december: (map['december'] as num?)?.toDouble() ?? 0.0,
      );
}
