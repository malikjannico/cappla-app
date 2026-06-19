import 'package:flutter_test/flutter_test.dart';
import 'package:cappla/models/user_model.dart';
import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/services/database/database_service.dart';
import 'e2e_test_harness.dart';

void main() {
  group('Empirical Challenger M4 Stress Tests', () {
    late E2ETestHarness harness;
    late DatabaseService db;

    setUp(() {
      harness = E2ETestHarness();
      db = harness.container.read(databaseServiceProvider);
    });

    group('Deactivation Cascade Verification', () {
      test('Deep tree cascade propagation works correctly', () async {
        final level1 = OrgUnitModel(
          id: 'L1',
          name: 'Level 1',
          abbreviation: 'L1',
          headOfEmail: 'l1@vetter.com',
          type: 'md division',
          childIds: ['L2'],
          status: 'Active',
        );
        final level2 = OrgUnitModel(
          id: 'L2',
          name: 'Level 2',
          abbreviation: 'L2',
          headOfEmail: 'l2@vetter.com',
          type: 'svp division',
          parentId: 'L1',
          childIds: ['L3'],
          status: 'Active',
        );
        final level3 = OrgUnitModel(
          id: 'L3',
          name: 'Level 3',
          abbreviation: 'L3',
          headOfEmail: 'l3@vetter.com',
          type: 'vp division',
          parentId: 'L2',
          childIds: ['L4'],
          status: 'Active',
        );
        final level4 = OrgUnitModel(
          id: 'L4',
          name: 'Level 4',
          abbreviation: 'L4',
          headOfEmail: 'l4@vetter.com',
          type: 'department',
          parentId: 'L3',
          childIds: [],
          status: 'Active',
        );

        harness.mockFirestore.setData('orgUnits', 'L1', level1.toMap());
        harness.mockFirestore.setData('orgUnits', 'L2', level2.toMap());
        harness.mockFirestore.setData('orgUnits', 'L3', level3.toMap());
        harness.mockFirestore.setData('orgUnits', 'L4', level4.toMap());

        // Verify initial active status
        expect((await db.getOrgUnit('L1'))!.status, equals('Active'));
        expect((await db.getOrgUnit('L2'))!.status, equals('Active'));
        expect((await db.getOrgUnit('L3'))!.status, equals('Active'));
        expect((await db.getOrgUnit('L4'))!.status, equals('Active'));

        // Deactivate the root level
        final inactiveLevel1 = level1.copyWith(status: 'Inactive');
        await db.saveOrgUnit(inactiveLevel1);

        // Verify all cascaded to Inactive
        expect((await db.getOrgUnit('L1'))!.status, equals('Inactive'));
        expect((await db.getOrgUnit('L2'))!.status, equals('Inactive'));
        expect((await db.getOrgUnit('L3'))!.status, equals('Inactive'));
        expect((await db.getOrgUnit('L4'))!.status, equals('Inactive'));
      });

      test(
        'Stack overflow protection on circular reference deactivation cascade',
        () async {
          // Setup B -> C -> B circular structure by using childIds (bypassing parentId check)
          final unitB = OrgUnitModel(
            id: 'UNIT_B_CIRC',
            name: 'Unit B Circular',
            abbreviation: 'UBC',
            headOfEmail: 'b@vetter.com',
            type: 'department',
            parentId: null,
            childIds: ['UNIT_C_CIRC'],
            status: 'Active',
          );
          final unitC = OrgUnitModel(
            id: 'UNIT_C_CIRC',
            name: 'Unit C Circular',
            abbreviation: 'UCC',
            headOfEmail: 'c@vetter.com',
            type: 'department',
            parentId: null,
            childIds: ['UNIT_B_CIRC'],
            status: 'Active',
          );

          harness.mockFirestore.setData(
            'orgUnits',
            'UNIT_B_CIRC',
            unitB.toMap(),
          );
          harness.mockFirestore.setData(
            'orgUnits',
            'UNIT_C_CIRC',
            unitC.toMap(),
          );

          // Deactivate unitB
          final inactiveB = unitB.copyWith(status: 'Inactive');

          // This must complete and not result in StackOverflowError
          await db.saveOrgUnit(inactiveB);

          // Verify both units are inactive
          expect(
            (await db.getOrgUnit('UNIT_B_CIRC'))!.status,
            equals('Inactive'),
          );
          expect(
            (await db.getOrgUnit('UNIT_C_CIRC'))!.status,
            equals('Inactive'),
          );
        },
      );
    });

    group('Relation Syncing Verification', () {
      test(
        'Breaking link from parent side (clearing childIds) clears parentId on child',
        () async {
          final parent = OrgUnitModel(
            id: 'P_SYNC_1',
            name: 'Parent Unit',
            abbreviation: 'PS1',
            headOfEmail: 'head@vetter.com',
            type: 'md division',
            childIds: ['C_SYNC_1'],
            status: 'Active',
          );
          final child = OrgUnitModel(
            id: 'C_SYNC_1',
            name: 'Child Unit',
            abbreviation: 'CS1',
            headOfEmail: 'child@vetter.com',
            type: 'svp division',
            parentId: 'P_SYNC_1',
            childIds: [],
            status: 'Active',
          );

          harness.mockFirestore.setData('orgUnits', 'P_SYNC_1', parent.toMap());
          harness.mockFirestore.setData('orgUnits', 'C_SYNC_1', child.toMap());

          // Verify initial state
          expect(
            (await db.getOrgUnit('P_SYNC_1'))!.childIds,
            contains('C_SYNC_1'),
          );
          expect(
            (await db.getOrgUnit('C_SYNC_1'))!.parentId,
            equals('P_SYNC_1'),
          );

          // Clear childIds on parent
          final updatedParent = parent.copyWith(childIds: []);
          await db.saveOrgUnit(updatedParent);

          // Verify parent childIds is empty, child parentId is cleared (null)
          expect((await db.getOrgUnit('P_SYNC_1'))!.childIds, isEmpty);
          expect((await db.getOrgUnit('C_SYNC_1'))!.parentId, isNull);
        },
      );

      test(
        'Breaking link from child side (clearing parentId) clears childId on parent',
        () async {
          final parent = OrgUnitModel(
            id: 'P_SYNC_2',
            name: 'Parent Unit',
            abbreviation: 'PS2',
            headOfEmail: 'head@vetter.com',
            type: 'md division',
            childIds: ['C_SYNC_2'],
            status: 'Active',
          );
          final child = OrgUnitModel(
            id: 'C_SYNC_2',
            name: 'Child Unit',
            abbreviation: 'CS2',
            headOfEmail: 'child@vetter.com',
            type: 'svp division',
            parentId: 'P_SYNC_2',
            childIds: [],
            status: 'Active',
          );

          harness.mockFirestore.setData('orgUnits', 'P_SYNC_2', parent.toMap());
          harness.mockFirestore.setData('orgUnits', 'C_SYNC_2', child.toMap());

          // Verify initial state
          expect(
            (await db.getOrgUnit('P_SYNC_2'))!.childIds,
            contains('C_SYNC_2'),
          );
          expect(
            (await db.getOrgUnit('C_SYNC_2'))!.parentId,
            equals('P_SYNC_2'),
          );

          // Clear parentId on child
          final updatedChild = child.copyWith(parentId: () => null);
          await db.saveOrgUnit(updatedChild);

          // Verify parent childIds is empty, child parentId is cleared (null)
          expect((await db.getOrgUnit('P_SYNC_2'))!.childIds, isEmpty);
          expect((await db.getOrgUnit('C_SYNC_2'))!.parentId, isNull);
        },
      );

      test(
        'Reassigning child to new parent automatically updates old parent and new parent',
        () async {
          final parentOld = OrgUnitModel(
            id: 'P_OLD',
            name: 'Parent Old',
            abbreviation: 'POLD',
            headOfEmail: 'head@vetter.com',
            type: 'department',
            parentId: null,
            childIds: ['C_REASSIGN'],
            status: 'Active',
          );
          final parentNew = OrgUnitModel(
            id: 'P_NEW',
            name: 'Parent New',
            abbreviation: 'PNEW',
            headOfEmail: 'head@vetter.com',
            type: 'department',
            parentId: null,
            childIds: [],
            status: 'Active',
          );
          final child = OrgUnitModel(
            id: 'C_REASSIGN',
            name: 'Child Reassign',
            abbreviation: 'CRE',
            headOfEmail: 'child@vetter.com',
            type: 'department',
            parentId: 'P_OLD',
            childIds: [],
            status: 'Active',
          );

          harness.mockFirestore.setData('orgUnits', 'P_OLD', parentOld.toMap());
          harness.mockFirestore.setData('orgUnits', 'P_NEW', parentNew.toMap());
          harness.mockFirestore.setData(
            'orgUnits',
            'C_REASSIGN',
            child.toMap(),
          );

          // Verify initial state
          expect(
            (await db.getOrgUnit('P_OLD'))!.childIds,
            contains('C_REASSIGN'),
          );
          expect((await db.getOrgUnit('P_NEW'))!.childIds, isEmpty);
          expect(
            (await db.getOrgUnit('C_REASSIGN'))!.parentId,
            equals('P_OLD'),
          );

          // Reassign child by saving child with new parent ID
          final updatedChild = child.copyWith(parentId: () => 'P_NEW');
          await db.saveOrgUnit(updatedChild);

          // Verify old parent loses child, new parent gains child, child has new parent
          expect((await db.getOrgUnit('P_OLD'))!.childIds, isEmpty);
          expect(
            (await db.getOrgUnit('P_NEW'))!.childIds,
            contains('C_REASSIGN'),
          );
          expect(
            (await db.getOrgUnit('C_REASSIGN'))!.parentId,
            equals('P_NEW'),
          );
        },
      );
    });

    group('User Disassociation Verification', () {
      test('Deleting an org unit disassociates all assigned users', () async {
        final orgUnit = OrgUnitModel(
          id: 'DEL_UNIT',
          name: 'Delete Unit',
          abbreviation: 'DEL',
          headOfEmail: 'head@vetter.com',
          type: 'department',
          parentId: null,
          childIds: [],
          status: 'Active',
        );

        final user1 = UserModel(
          id: 'user1@vetter.com',
          fullName: 'User One',
          email: 'user1@vetter.com',
          title: 'Specialist',
          status: 'Active',
          role: 'User',
          orgUnitId: 'DEL_UNIT',
        );
        final user2 = UserModel(
          id: 'user2@vetter.com',
          fullName: 'User Two',
          email: 'user2@vetter.com',
          title: 'Specialist',
          status: 'Active',
          role: 'User',
          orgUnitId: 'DEL_UNIT',
        );
        final userUnaffected = UserModel(
          id: 'user3@vetter.com',
          fullName: 'User Unaffected',
          email: 'user3@vetter.com',
          title: 'Specialist',
          status: 'Active',
          role: 'User',
          orgUnitId: 'OTHER_UNIT',
        );

        await db.saveOrgUnit(orgUnit);
        await db.saveUser(user1);
        await db.saveUser(user2);
        await db.saveUser(userUnaffected);

        // Verify initial state
        expect(
          (await db.getUser('user1@vetter.com'))!.orgUnitId,
          equals('DEL_UNIT'),
        );
        expect(
          (await db.getUser('user2@vetter.com'))!.orgUnitId,
          equals('DEL_UNIT'),
        );
        expect(
          (await db.getUser('user3@vetter.com'))!.orgUnitId,
          equals('OTHER_UNIT'),
        );

        // Delete the unit
        await db.deleteOrgUnit('DEL_UNIT');

        // Verify that deleted unit is gone
        expect(await db.getOrgUnit('DEL_UNIT'), isNull);

        // Verify user1 and user2 are disassociated, but user3 is unaffected
        expect((await db.getUser('user1@vetter.com'))!.orgUnitId, isNull);
        expect((await db.getUser('user2@vetter.com'))!.orgUnitId, isNull);
        expect(
          (await db.getUser('user3@vetter.com'))!.orgUnitId,
          equals('OTHER_UNIT'),
        );
      });
    });
  });
}
