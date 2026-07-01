import 'package:flutter_test/flutter_test.dart';
import 'package:cappla/models/user_capacity_model.dart';
import 'package:cappla/core/utils/capacity_calculator.dart';

void main() {
  group('CapacityCalculator Unit Tests', () {
    test('Returns 0.0 when capacities list is empty', () {
      final result = CapacityCalculator.calculateMonthlyCapacity([], 2026, 6);
      expect(result, equals(0.0));
    });

    test('Falls back to Standard capacity when no Specific overrides exist', () {
      final standard = UserCapacityModel(
        id: 'std',
        userEmail: 'user@vetter.com',
        type: 'Standard',
        monday: 8.0,
        tuesday: 8.0,
        wednesday: 8.0,
        thursday: 8.0,
        friday: 8.0,
        saturday: 0.0,
        sunday: 0.0,
      );

      // June 2026 has:
      // 4 Mondays, 5 Tuesdays, 5 Wednesdays, 4 Thursdays, 4 Fridays, 4 Saturdays, 4 Sundays.
      // Weekdays: 4+5+5+4+4 = 22 days.
      // Total hours: 22 * 8.0 = 176.0.
      final result = CapacityCalculator.calculateMonthlyCapacity([standard], 2026, 6);
      expect(result, equals(176.0));
    });

    test('Correctly calculates leap year capacity (February 2024 vs February 2023)', () {
      final standard = UserCapacityModel(
        id: 'std',
        userEmail: 'user@vetter.com',
        type: 'Standard',
        monday: 8.0,
        tuesday: 8.0,
        wednesday: 8.0,
        thursday: 8.0,
        friday: 8.0,
        saturday: 0.0,
        sunday: 0.0,
      );

      // February 2023: 28 days
      // Mon: 4, Tue: 4, Wed: 4, Thu: 4, Fri: 4. Total = 20 * 8 = 160.0
      final result2023 = CapacityCalculator.calculateMonthlyCapacity([standard], 2023, 2);
      expect(result2023, equals(160.0));

      // February 2024 (Leap year): 29 days.
      // 2024-02-29 is a Thursday.
      // Mon: 4, Tue: 4, Wed: 4, Thu: 5, Fri: 4. Total = 21 * 8 = 168.0
      final result2024 = CapacityCalculator.calculateMonthlyCapacity([standard], 2024, 2);
      expect(result2024, equals(168.0));
    });

    test('Applies Specific capacity override within the range and falls back outside of it', () {
      final standard = UserCapacityModel(
        id: 'std',
        userEmail: 'user@vetter.com',
        type: 'Standard',
        monday: 8.0,
        tuesday: 8.0,
        wednesday: 8.0,
        thursday: 8.0,
        friday: 8.0,
        saturday: 0.0,
        sunday: 0.0,
      );

      // Overrides capacity to 4.0 hours for all days from June 10, 2026 to June 15, 2026.
      // June 2026 calendar:
      // 10th (Wed), 11th (Thu), 12th (Fri), 13th (Sat), 14th (Sun), 15th (Mon).
      // Days overridden: 4 weekdays (Wed, Thu, Fri, Mon) -> capacity 4.0.
      // 2 weekend days (Sat, Sun) -> capacity 4.0.
      // Rest of month (22 - 4 = 18 weekdays) -> capacity 8.0.
      // 8 weekend days (6 weekend days outside range) -> capacity 0.0.
      // Expected total:
      // Overridden days: 6 days * 4.0 = 24.0 hours.
      // Outside range weekdays: 18 days * 8.0 = 144.0 hours.
      // Total: 168.0 hours.
      final specific = UserCapacityModel(
        id: 'spec',
        userEmail: 'user@vetter.com',
        type: 'Specific',
        startDate: DateTime(2026, 6, 10),
        endDate: DateTime(2026, 6, 15),
        monday: 4.0,
        tuesday: 4.0,
        wednesday: 4.0,
        thursday: 4.0,
        friday: 4.0,
        saturday: 4.0,
        sunday: 4.0,
      );

      final result = CapacityCalculator.calculateMonthlyCapacity([standard, specific], 2026, 6);
      expect(result, equals(168.0));
    });

    test('Filters out Specific capacities with missing start/end dates', () {
      final standard = UserCapacityModel(
        id: 'std',
        userEmail: 'user@vetter.com',
        type: 'Standard',
        monday: 8.0,
        tuesday: 8.0,
        wednesday: 8.0,
        thursday: 8.0,
        friday: 8.0,
        saturday: 0.0,
        sunday: 0.0,
      );

      final invalidSpecific = UserCapacityModel(
        id: 'spec_invalid',
        userEmail: 'user@vetter.com',
        type: 'Specific',
        startDate: null,
        endDate: null,
        monday: 4.0,
        tuesday: 4.0,
        wednesday: 4.0,
        thursday: 4.0,
        friday: 4.0,
        saturday: 4.0,
        sunday: 4.0,
      );

      final result = CapacityCalculator.calculateMonthlyCapacity([standard, invalidSpecific], 2026, 6);
      expect(result, equals(176.0));
    });

    test('If multiple Specific capacities overlap, the one with most recent lastModifiedAt wins', () {
      final standard = UserCapacityModel(
        id: 'std',
        userEmail: 'user@vetter.com',
        type: 'Standard',
        monday: 8.0,
        tuesday: 8.0,
        wednesday: 8.0,
        thursday: 8.0,
        friday: 8.0,
        saturday: 0.0,
        sunday: 0.0,
      );

      // Specific 1: earlier lastModifiedAt, sets capacity to 2.0 hours.
      final specific1 = UserCapacityModel(
        id: 'spec1',
        userEmail: 'user@vetter.com',
        type: 'Specific',
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 30),
        monday: 2.0,
        tuesday: 2.0,
        wednesday: 2.0,
        thursday: 2.0,
        friday: 2.0,
        saturday: 2.0,
        sunday: 2.0,
        lastModifiedAt: DateTime(2026, 6, 1),
      );

      // Specific 2: later lastModifiedAt, sets capacity to 6.0 hours.
      final specific2 = UserCapacityModel(
        id: 'spec2',
        userEmail: 'user@vetter.com',
        type: 'Specific',
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 30),
        monday: 6.0,
        tuesday: 6.0,
        wednesday: 6.0,
        thursday: 6.0,
        friday: 6.0,
        saturday: 6.0,
        sunday: 6.0,
        lastModifiedAt: DateTime(2026, 6, 10),
      );

      // 30 days in June. 30 * 6.0 = 180.0
      final result1 = CapacityCalculator.calculateMonthlyCapacity([standard, specific1, specific2], 2026, 6);
      expect(result1, equals(180.0));

      // If we swap the modified times, specific1 should win (30 * 2.0 = 60.0)
      final specific1Newer = specific1.copyWith(lastModifiedAt: DateTime(2026, 6, 20));
      final result2 = CapacityCalculator.calculateMonthlyCapacity([standard, specific1Newer, specific2], 2026, 6);
      expect(result2, equals(60.0));
    });
  });
}
