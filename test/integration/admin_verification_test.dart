import 'package:flutter_test/flutter_test.dart';
import 'package:cappla/models/user_model.dart';
import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/services/database/database_service.dart';
import 'e2e_test_harness.dart';

void main() {
  group('Challenger M4 Verification: Active Propagation and Dissolving Relations', () {
    late E2ETestHarness harness;
    late DatabaseService db;

    setUp(() {
      harness = E2ETestHarness();
      db = harness.container.read(databaseServiceProvider);
    });

    test(
      '1. Removing a parent-child link successfully clears parentId on child',
      () async {
        // 1. Seed parent and child units
        final parent = OrgUnitModel(
          id: 'PARENT_1',
          name: 'Parent Unit',
          abbreviation: 'PRNT1',
          headOfEmail: 'head@vetter.com',
          type: 'md division',
          childIds: ['CHILD_1'],
          status: 'Active',
        );
        final child = OrgUnitModel(
          id: 'CHILD_1',
          name: 'Child Unit',
          abbreviation: 'CHLD1',
          headOfEmail: 'child@vetter.com',
          type: 'svp division',
          parentId: 'PARENT_1',
          childIds: [],
          status: 'Active',
        );

        harness.mockFirestore.setData('orgUnits', 'PARENT_1', parent.toMap());
        harness.mockFirestore.setData('orgUnits', 'CHILD_1', child.toMap());

        // Verify setup
        var dbParent = await db.getOrgUnit('PARENT_1');
        var dbChild = await db.getOrgUnit('CHILD_1');
        expect(dbParent!.childIds, contains('CHILD_1'));
        expect(dbChild!.parentId, equals('PARENT_1'));

        // 2. Remove parent-child link (update parent childIds to not include CHILD_1)
        final updatedParent = parent.copyWith(childIds: []);
        await db.saveOrgUnit(updatedParent);

        // Verify relation is dissolved
        dbParent = await db.getOrgUnit('PARENT_1');
        dbChild = await db.getOrgUnit('CHILD_1');

        expect(dbParent!.childIds, isNot(contains('CHILD_1')));
        expect(dbChild!.parentId, isNull);
      },
    );

    test(
      '2. Deactivating a parent recursively cascades Inactive status to all child units',
      () async {
        // 1. Seed parent, child, and grandchild units
        final parent = OrgUnitModel(
          id: 'PARENT_DIV',
          name: 'Parent Div',
          abbreviation: 'PDIV',
          headOfEmail: 'head@vetter.com',
          type: 'md division',
          childIds: ['CHILD_DIV'],
          status: 'Active',
        );
        final child = OrgUnitModel(
          id: 'CHILD_DIV',
          name: 'Child Div',
          abbreviation: 'CDIV',
          headOfEmail: 'child@vetter.com',
          type: 'svp division',
          parentId: 'PARENT_DIV',
          childIds: ['GRANDCHILD_DIV'],
          status: 'Active',
        );
        final grandchild = OrgUnitModel(
          id: 'GRANDCHILD_DIV',
          name: 'Grandchild Div',
          abbreviation: 'GCDIV',
          headOfEmail: 'grandchild@vetter.com',
          type: 'vp division',
          parentId: 'CHILD_DIV',
          childIds: [],
          status: 'Active',
        );

        harness.mockFirestore.setData('orgUnits', 'PARENT_DIV', parent.toMap());
        harness.mockFirestore.setData('orgUnits', 'CHILD_DIV', child.toMap());
        harness.mockFirestore.setData(
          'orgUnits',
          'GRANDCHILD_DIV',
          grandchild.toMap(),
        );

        // Verify all are Active initially
        expect((await db.getOrgUnit('PARENT_DIV'))!.status, equals('Active'));
        expect((await db.getOrgUnit('CHILD_DIV'))!.status, equals('Active'));
        expect(
          (await db.getOrgUnit('GRANDCHILD_DIV'))!.status,
          equals('Active'),
        );

        // 2. Deactivate parent
        final inactiveParent = parent.copyWith(status: 'Inactive');
        await db.saveOrgUnit(inactiveParent);

        // Verify recursive cascade propagation
        expect((await db.getOrgUnit('PARENT_DIV'))!.status, equals('Inactive'));
        expect((await db.getOrgUnit('CHILD_DIV'))!.status, equals('Inactive'));
        expect(
          (await db.getOrgUnit('GRANDCHILD_DIV'))!.status,
          equals('Inactive'),
        );
      },
    );

    test(
      '3. Deleting an org unit removes associations on parent, clears parentId on child units, and clears orgUnitId on all assigned users',
      () async {
        // 1. Seed parent, target (to delete), and child units, and users
        final parent = OrgUnitModel(
          id: 'PARENT_UNIT',
          name: 'Parent Unit',
          abbreviation: 'PARENT',
          headOfEmail: 'parent@vetter.com',
          type: 'md division',
          childIds: ['TARGET_UNIT'],
          status: 'Active',
        );
        final target = OrgUnitModel(
          id: 'TARGET_UNIT',
          name: 'Target Unit to Delete',
          abbreviation: 'TARGET',
          headOfEmail: 'target@vetter.com',
          type: 'svp division',
          parentId: 'PARENT_UNIT',
          childIds: ['CHILD_UNIT'],
          status: 'Active',
        );
        final child = OrgUnitModel(
          id: 'CHILD_UNIT',
          name: 'Child Unit',
          abbreviation: 'CHILD',
          headOfEmail: 'child@vetter.com',
          type: 'vp division',
          parentId: 'TARGET_UNIT',
          childIds: [],
          status: 'Active',
        );

        final user1 = UserModel(
          id: 'user1@vetter-pharma.com',
          fullName: 'User One',
          email: 'user1@vetter-pharma.com',
          title: 'Specialist',
          status: 'Active',
          role: 'User',
          orgUnitId: 'TARGET_UNIT',
        );
        final user2 = UserModel(
          id: 'user2@vetter-pharma.com',
          fullName: 'User Two',
          email: 'user2@vetter-pharma.com',
          title: 'Analyst',
          status: 'Active',
          role: 'User',
          orgUnitId: 'TARGET_UNIT',
        );
        final user3 = UserModel(
          id: 'user3@vetter-pharma.com',
          fullName: 'User Three',
          email: 'user3@vetter-pharma.com',
          title: 'Manager',
          status: 'Active',
          role: 'User',
          orgUnitId: 'PARENT_UNIT', // assigned to parent, shouldn't be affected
        );

        harness.mockFirestore.setData(
          'orgUnits',
          'PARENT_UNIT',
          parent.toMap(),
        );
        harness.mockFirestore.setData(
          'orgUnits',
          'TARGET_UNIT',
          target.toMap(),
        );
        harness.mockFirestore.setData('orgUnits', 'CHILD_UNIT', child.toMap());

        await db.saveUser(user1);
        await db.saveUser(user2);
        await db.saveUser(user3);

        // Verify setup
        expect(
          (await db.getOrgUnit('PARENT_UNIT'))!.childIds,
          contains('TARGET_UNIT'),
        );
        expect(
          (await db.getOrgUnit('CHILD_UNIT'))!.parentId,
          equals('TARGET_UNIT'),
        );
        expect(
          (await db.getUser('user1@vetter-pharma.com'))!.orgUnitId,
          equals('TARGET_UNIT'),
        );
        expect(
          (await db.getUser('user2@vetter-pharma.com'))!.orgUnitId,
          equals('TARGET_UNIT'),
        );
        expect(
          (await db.getUser('user3@vetter-pharma.com'))!.orgUnitId,
          equals('PARENT_UNIT'),
        );

        // 2. Delete the target org unit
        await db.deleteOrgUnit('TARGET_UNIT');

        // Verify deletion details
        // a. Target unit is deleted
        expect(await db.getOrgUnit('TARGET_UNIT'), isNull);

        // b. Associations on parent are removed
        final updatedParent = await db.getOrgUnit('PARENT_UNIT');
        expect(updatedParent!.childIds, isNot(contains('TARGET_UNIT')));

        // c. parentId is cleared on child units
        final updatedChild = await db.getOrgUnit('CHILD_UNIT');
        expect(updatedChild!.parentId, isNull);

        // d. orgUnitId is cleared on all assigned users
        final updatedUser1 = await db.getUser('user1@vetter-pharma.com');
        final updatedUser2 = await db.getUser('user2@vetter-pharma.com');
        final updatedUser3 = await db.getUser('user3@vetter-pharma.com');

        expect(updatedUser1!.orgUnitId, isNull);
        expect(updatedUser2!.orgUnitId, isNull);
        expect(updatedUser3!.orgUnitId, equals('PARENT_UNIT')); // Unaffected
      },
    );

    test('4. Hierarchy constraints: MD Division cannot have parent', () async {
      final mdDivision = OrgUnitModel(
        id: 'MD_DIV',
        name: 'MD Division',
        abbreviation: 'MDD',
        headOfEmail: 'head@vetter.com',
        type: 'md division',
        parentId: 'PARENT_1',
        childIds: [],
        status: 'Active',
      );
      expect(
        () => db.saveOrgUnit(mdDivision),
        throwsA(isA<DatabaseValidationException>()),
      );
    });

    test('5. Hierarchy constraints: Team cannot have children', () async {
      final team = OrgUnitModel(
        id: 'TEAM_1',
        name: 'Team 1',
        abbreviation: 'T1',
        headOfEmail: 'head@vetter.com',
        type: 'team',
        parentId: null,
        childIds: ['CHILD_1'],
        status: 'Active',
      );
      expect(
        () => db.saveOrgUnit(team),
        throwsA(isA<DatabaseValidationException>()),
      );
    });

    test(
      '6. Cycle prevention: Child in ancestors throws OrgUnitCycleException',
      () async {
        final parent = OrgUnitModel(
          id: 'PARENT_1',
          name: 'Parent Unit',
          abbreviation: 'PRNT1',
          headOfEmail: 'head@vetter.com',
          type: 'department',
          parentId: null,
          childIds: [],
          status: 'Active',
        );
        final child = OrgUnitModel(
          id: 'CHILD_1',
          name: 'Child Unit',
          abbreviation: 'CHLD1',
          headOfEmail: 'head@vetter.com',
          type: 'department',
          parentId: 'PARENT_1',
          childIds: [],
          status: 'Active',
        );
        await db.saveOrgUnit(parent);
        await db.saveOrgUnit(child);

        // Now set parent's parentId to child_1 (creates cycle)
        final parentCycle = parent.copyWith(parentId: () => 'CHILD_1');
        expect(
          () => db.saveOrgUnit(parentCycle),
          throwsA(isA<OrgUnitCycleException>()),
        );

        // Set parent's children to include itself
        final parentSelfChild = parent.copyWith(childIds: ['PARENT_1']);
        expect(
          () => db.saveOrgUnit(parentSelfChild),
          throwsA(isA<OrgUnitCycleException>()),
        );
      },
    );

    test('7. Old parent desynchronization on child reassignment', () async {
      final oldParent = OrgUnitModel(
        id: 'OLD_PARENT',
        name: 'Old Parent',
        abbreviation: 'OP',
        headOfEmail: 'head@vetter.com',
        type: 'department',
        parentId: null,
        childIds: ['CHILD_REASSIGN'],
        status: 'Active',
      );
      final child = OrgUnitModel(
        id: 'CHILD_REASSIGN',
        name: 'Child Reassign',
        abbreviation: 'CR',
        headOfEmail: 'head@vetter.com',
        type: 'department',
        parentId: 'OLD_PARENT',
        childIds: [],
        status: 'Active',
      );
      final newParent = OrgUnitModel(
        id: 'NEW_PARENT',
        name: 'New Parent',
        abbreviation: 'NP',
        headOfEmail: 'head@vetter.com',
        type: 'department',
        parentId: null,
        childIds: [],
        status: 'Active',
      );

      harness.mockFirestore.setData(
        'orgUnits',
        'OLD_PARENT',
        oldParent.toMap(),
      );
      harness.mockFirestore.setData(
        'orgUnits',
        'CHILD_REASSIGN',
        child.toMap(),
      );
      harness.mockFirestore.setData(
        'orgUnits',
        'NEW_PARENT',
        newParent.toMap(),
      );

      // Reassign child to newParent by saving newParent with child in childIds
      final updatedNewParent = newParent.copyWith(childIds: ['CHILD_REASSIGN']);
      await db.saveOrgUnit(updatedNewParent);

      // Verify that oldParent's child list no longer contains the child
      final dbOldParent = await db.getOrgUnit('OLD_PARENT');
      expect(dbOldParent!.childIds, isNot(contains('CHILD_REASSIGN')));

      // Verify that child's parent ID is set to newParent
      final dbChild = await db.getOrgUnit('CHILD_REASSIGN');
      expect(dbChild!.parentId, equals('NEW_PARENT'));

      // Verify that newParent's child list contains the child
      final dbNewParent = await db.getOrgUnit('NEW_PARENT');
      expect(dbNewParent!.childIds, contains('CHILD_REASSIGN'));
    });

    test(
      '7b. Old parent desynchronization on child reassignment by updating child parentId',
      () async {
        final oldParent = OrgUnitModel(
          id: 'OLD_PARENT_B',
          name: 'Old Parent B',
          abbreviation: 'OPB',
          headOfEmail: 'head@vetter.com',
          type: 'department',
          parentId: null,
          childIds: ['CHILD_REASSIGN_B'],
          status: 'Active',
        );
        final child = OrgUnitModel(
          id: 'CHILD_REASSIGN_B',
          name: 'Child Reassign B',
          abbreviation: 'CRB',
          headOfEmail: 'head@vetter.com',
          type: 'department',
          parentId: 'OLD_PARENT_B',
          childIds: [],
          status: 'Active',
        );
        final newParent = OrgUnitModel(
          id: 'NEW_PARENT_B',
          name: 'New Parent B',
          abbreviation: 'NPB',
          headOfEmail: 'head@vetter.com',
          type: 'department',
          parentId: null,
          childIds: [],
          status: 'Active',
        );

        harness.mockFirestore.setData(
          'orgUnits',
          'OLD_PARENT_B',
          oldParent.toMap(),
        );
        harness.mockFirestore.setData(
          'orgUnits',
          'CHILD_REASSIGN_B',
          child.toMap(),
        );
        harness.mockFirestore.setData(
          'orgUnits',
          'NEW_PARENT_B',
          newParent.toMap(),
        );

        // Reassign child to newParent by saving child directly with updated parentId
        final updatedChild = child.copyWith(parentId: () => 'NEW_PARENT_B');
        await db.saveOrgUnit(updatedChild);

        // Verify that oldParent's child list no longer contains the child
        final dbOldParent = await db.getOrgUnit('OLD_PARENT_B');
        expect(dbOldParent!.childIds, isNot(contains('CHILD_REASSIGN_B')));

        // Verify that child's parent ID is set to newParent
        final dbChild = await db.getOrgUnit('CHILD_REASSIGN_B');
        expect(dbChild!.parentId, equals('NEW_PARENT_B'));

        // Verify that newParent's child list contains the child
        final dbNewParent = await db.getOrgUnit('NEW_PARENT_B');
        expect(dbNewParent!.childIds, contains('CHILD_REASSIGN_B'));
      },
    );

    test(
      '8. Status propagation stack overflow protection with circular reference',
      () async {
        // Setup a cycle B -> A -> B using childIds but bypassing cycle checks on save
        // by setting parentId to null or different parents
        final unitA = OrgUnitModel(
          id: 'UNIT_A',
          name: 'Unit A',
          abbreviation: 'UA',
          headOfEmail: 'head@vetter.com',
          type: 'department',
          parentId: null,
          childIds: ['UNIT_B'],
          status: 'Active',
        );
        final unitB = OrgUnitModel(
          id: 'UNIT_B',
          name: 'Unit B',
          abbreviation: 'UB',
          headOfEmail: 'head@vetter.com',
          type: 'department',
          parentId: null,
          childIds: ['UNIT_A'],
          status: 'Active',
        );

        harness.mockFirestore.setData('orgUnits', 'UNIT_A', unitA.toMap());
        harness.mockFirestore.setData('orgUnits', 'UNIT_B', unitB.toMap());

        // Deactivate unitA. Since B has child A, status propagation would recurse infinitely without visited set.
        final inactiveA = unitA.copyWith(status: 'Inactive');
        await db.saveOrgUnit(inactiveA);

        // Verify both are now Inactive and no stack overflow occurred
        expect((await db.getOrgUnit('UNIT_A'))!.status, equals('Inactive'));
        expect((await db.getOrgUnit('UNIT_B'))!.status, equals('Inactive'));
      },
    );
  });
}
