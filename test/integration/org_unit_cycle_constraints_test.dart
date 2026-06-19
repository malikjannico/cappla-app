import 'package:flutter_test/flutter_test.dart';
import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/services/database/database_service.dart';
import 'e2e_test_harness.dart';

void main() {
  group('Empirical Challenger: Cycle Checks & Type Constraints', () {
    late E2ETestHarness harness;
    late DatabaseService db;

    setUp(() {
      harness = E2ETestHarness();
      db = harness.container.read(databaseServiceProvider);
    });

    group('Cycle Checks', () {
      test(
        'Updating a parent unit\'s children list to include its own ancestor throws OrgUnitCycleException',
        () async {
          // Scenario: A -> B -> C
          // A is the ancestor (grandparent) of C.
          // B is the parent of C.
          // If B's children list is updated to include A (B's own ancestor), it must throw OrgUnitCycleException.

          final ancestor = OrgUnitModel(
            id: 'ANCESTOR_A',
            name: 'Ancestor A',
            abbreviation: 'AA',
            headOfEmail: 'a@vetter.com',
            type: 'department',
            parentId: null,
            childIds: ['PARENT_B'],
            status: 'Active',
          );

          final parent = OrgUnitModel(
            id: 'PARENT_B',
            name: 'Parent B',
            abbreviation: 'PB',
            headOfEmail: 'b@vetter.com',
            type: 'department',
            parentId: 'ANCESTOR_A',
            childIds: ['CHILD_C'],
            status: 'Active',
          );

          final child = OrgUnitModel(
            id: 'CHILD_C',
            name: 'Child C',
            abbreviation: 'CC',
            headOfEmail: 'c@vetter.com',
            type: 'department',
            parentId: 'PARENT_B',
            childIds: [],
            status: 'Active',
          );

          harness.mockFirestore.setData(
            'orgUnits',
            'ANCESTOR_A',
            ancestor.toMap(),
          );
          harness.mockFirestore.setData('orgUnits', 'PARENT_B', parent.toMap());
          harness.mockFirestore.setData('orgUnits', 'CHILD_C', child.toMap());

          // Update Parent B's children list to include Ancestor A
          final updatedParent = parent.copyWith(
            childIds: ['CHILD_C', 'ANCESTOR_A'],
          );

          expect(
            () => db.saveOrgUnit(updatedParent),
            throwsA(isA<OrgUnitCycleException>()),
          );
        },
      );
    });

    group('Type Constraints', () {
      test(
        'Assigning md division to a parent throws DatabaseValidationException',
        () async {
          final parent = OrgUnitModel(
            id: 'PARENT_A',
            name: 'Parent A',
            abbreviation: 'PA',
            headOfEmail: 'a@vetter.com',
            type: 'department',
            parentId: null,
            childIds: [],
            status: 'Active',
          );
          await db.saveOrgUnit(parent);

          final mdDivision = OrgUnitModel(
            id: 'MD_DIV_B',
            name: 'MD Division B',
            abbreviation: 'MDDB',
            headOfEmail: 'b@vetter.com',
            type: 'md division',
            parentId: 'PARENT_A', // Violates: MD Division cannot have a parent
            childIds: [],
            status: 'Active',
          );

          expect(
            () => db.saveOrgUnit(mdDivision),
            throwsA(isA<DatabaseValidationException>()),
          );
        },
      );

      test(
        'Assigning children to a team throws DatabaseValidationException',
        () async {
          final team = OrgUnitModel(
            id: 'TEAM_A',
            name: 'Team A',
            abbreviation: 'TA',
            headOfEmail: 'a@vetter.com',
            type: 'team',
            parentId: null,
            childIds: ['CHILD_X'], // Violates: Team cannot have children
            status: 'Active',
          );

          expect(
            () => db.saveOrgUnit(team),
            throwsA(isA<DatabaseValidationException>()),
          );
        },
      );
    });
  });
}
