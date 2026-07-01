import 'package:flutter_test/flutter_test.dart';
import 'package:cappla/models/user_model.dart';

void main() {
  group('UserModel Unit Tests', () {
    test('Successfully parses status and role from valid strings', () {
      final user = UserModel(
        id: 'USER_1',
        fullName: 'Test User',
        email: 'test@example.com',
        title: 'Tester',
        orgUnitId: 'ORG_1',
        status: 'Active',
        role: 'Administrator',
      );

      expect(user.status, equals('Active'));
      expect(user.role, equals('Administrator'));
    });

    test('Falls back to default values for invalid strings', () {
      final user = UserModel(
        id: 'USER_1',
        fullName: 'Test User',
        email: 'test@example.com',
        title: 'Tester',
        status: 'invalid_status_string',
        role: 'invalid_role_string',
      );

      expect(user.status, equals('Active')); // Defaults to active
      expect(user.role, equals('User')); // Defaults to user
    });

    test('Serializes toMap and deserializes fromMap correctly', () {
      final original = UserModel(
        id: 'USER_1',
        fullName: 'Test User',
        email: 'test@example.com',
        title: 'Tester',
        orgUnitId: 'ORG_1',
        status: 'Inactive',
        role: 'Administrator',
      );

      final map = original.toMap();
      expect(map['status'], equals('Inactive'));
      expect(map['role'], equals('Administrator'));

      final parsed = UserModel.fromMap(map);
      expect(parsed.id, equals(original.id));
      expect(parsed.fullName, equals(original.fullName));
      expect(parsed.email, equals(original.email));
      expect(parsed.title, equals(original.title));
      expect(parsed.orgUnitId, equals(original.orgUnitId));
      expect(parsed.status, equals(original.status));
      expect(parsed.role, equals(original.role));
    });

    test('copyWith behaves correctly, including clearing nullable orgUnitId', () {
      final original = UserModel(
        id: 'USER_1',
        fullName: 'Test User',
        email: 'test@example.com',
        title: 'Tester',
        orgUnitId: 'ORG_1',
        status: 'Active',
        role: 'User',
      );

      final updated = original.copyWith(
        fullName: 'Updated Name',
        orgUnitId: () => null,
      );

      expect(updated.fullName, equals('Updated Name'));
      expect(updated.orgUnitId, isNull);
    });
  });
}
