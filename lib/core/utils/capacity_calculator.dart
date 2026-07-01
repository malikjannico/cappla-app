import '../../models/user_capacity_model.dart';
import '../../models/enums.dart';

class CapacityCalculator {
  /// Calculates the total available capacity in hours for a given month and year
  /// based on standard and specific period capacity overrides.
  static double calculateMonthlyCapacity(
    List<UserCapacityModel> capacities,
    int year,
    int month,
  ) {
    if (capacities.isEmpty) return 0.0;

    // Sort specific capacities by last modified timestamp descending,
    // so that the most recently updated override takes precedence.
    final specificCaps = capacities.where((c) => c.type == CapacityType.specific).toList()
      ..sort((a, b) => b.lastModifiedAt.compareTo(a.lastModifiedAt));

    final standardCap = capacities.firstWhere(
      (c) => c.type == CapacityType.standard,
      orElse: () => UserCapacityModel(
        id: '',
        userEmail: '',
        type: CapacityType.standard,
        monday: 0.0,
        tuesday: 0.0,
        wednesday: 0.0,
        thursday: 0.0,
        friday: 0.0,
        saturday: 0.0,
        sunday: 0.0,
      ),
    );

    final normalizedSpecificCaps = specificCaps
        .where((c) => c.startDate != null && c.endDate != null)
        .map((cap) => (
              cap: cap,
              start: DateTime(
                cap.startDate!.year,
                cap.startDate!.month,
                cap.startDate!.day,
              ),
              end: DateTime(
                cap.endDate!.year,
                cap.endDate!.month,
                cap.endDate!.day,
              ),
            ))
        .toList();

    final numDays = DateTime(year, month + 1, 0).day;
    double totalHours = 0.0;

    for (int day = 1; day <= numDays; day++) {
      final date = DateTime(year, month, day);
      UserCapacityModel? activeCap;

      // Find if any specific capacity covers this date
      for (final item in normalizedSpecificCaps) {
        if ((date.isAfter(item.start) || date.isAtSameMomentAs(item.start)) &&
            (date.isBefore(item.end) || date.isAtSameMomentAs(item.end))) {
          activeCap = item.cap;
          break;
        }
      }

      // Fallback to standard capacity
      activeCap ??= standardCap;

      // Add weekday capacity hours
      switch (date.weekday) {
        case DateTime.monday:
          totalHours += activeCap.monday;
          break;
        case DateTime.tuesday:
          totalHours += activeCap.tuesday;
          break;
        case DateTime.wednesday:
          totalHours += activeCap.wednesday;
          break;
        case DateTime.thursday:
          totalHours += activeCap.thursday;
          break;
        case DateTime.friday:
          totalHours += activeCap.friday;
          break;
        case DateTime.saturday:
          totalHours += activeCap.saturday;
          break;
        case DateTime.sunday:
          totalHours += activeCap.sunday;
          break;
      }
    }

    return totalHours;
  }
}
