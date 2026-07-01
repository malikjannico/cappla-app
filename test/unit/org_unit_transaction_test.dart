import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cappla/services/database/firestore_database_service.dart';
import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/models/user_model.dart';
import 'package:cappla/models/enums.dart';

void main() {
  group('FirestoreDatabaseService Transaction Tests', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreDatabaseService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = FirestoreDatabaseService(firestore);
    });

    test('saveOrgUnit updates child parentId references and parent childIds', () async {
      // 1. Create a parent and child
      final parent = OrgUnitModel(
        id: 'PARENT_1',
        name: 'Parent Unit',
        abbreviation: 'P1',
        headOfEmail: 'head@example.com',
        type: OrgUnitType.mdDivision,
        childIds: [],
        status: 'Active',
      );

      final child = OrgUnitModel(
        id: 'CHILD_1',
        name: 'Child Unit',
        abbreviation: 'C1',
        headOfEmail: 'child@example.com',
        type: OrgUnitType.team,
        childIds: [],
        status: 'Active',
      );

      // Save parent first
      await service.saveOrgUnit(parent);
      // Save child first
      await service.saveOrgUnit(child);

      // Update child to reference parent
      final updatedChild = child.copyWith(parentId: () => 'PARENT_1');
      await service.saveOrgUnit(updatedChild);

      // Verify that parent childIds was updated to include CHILD_1
      final parentFromDb = await service.getOrgUnit('PARENT_1');
      expect(parentFromDb?.childIds, contains('CHILD_1'));

      // Verify child parentId is correct
      final childFromDb = await service.getOrgUnit('CHILD_1');
      expect(childFromDb?.parentId, equals('PARENT_1'));
    });

    test('saveOrgUnit propagates Inactive status to children recursively', () async {
      // Seed a three-level hierarchy
      final parent = OrgUnitModel(
        id: 'PARENT_1',
        name: 'Parent',
        abbreviation: 'P',
        headOfEmail: 'h@ex.com',
        type: OrgUnitType.mdDivision,
        childIds: ['CHILD_1'],
        status: 'Active',
      );
      final child = OrgUnitModel(
        id: 'CHILD_1',
        name: 'Child',
        abbreviation: 'C',
        headOfEmail: 'c@ex.com',
        type: OrgUnitType.department,
        parentId: 'PARENT_1',
        childIds: ['SUBCHILD_1'],
        status: 'Active',
      );
      final subChild = OrgUnitModel(
        id: 'SUBCHILD_1',
        name: 'Sub Child',
        abbreviation: 'SC',
        headOfEmail: 'sc@ex.com',
        type: OrgUnitType.team,
        parentId: 'CHILD_1',
        childIds: [],
        status: 'Active',
      );

      await firestore.collection('orgUnits').doc('PARENT_1').set(parent.toMap());
      await firestore.collection('orgUnits').doc('CHILD_1').set(child.toMap());
      await firestore.collection('orgUnits').doc('SUBCHILD_1').set(subChild.toMap());

      // Save parent as Inactive
      final inactiveParent = parent.copyWith(status: 'Inactive');
      await service.saveOrgUnit(inactiveParent);

      // Verify cascading Inactive status
      final childFromDb = await service.getOrgUnit('CHILD_1');
      final subChildFromDb = await service.getOrgUnit('SUBCHILD_1');

      expect(childFromDb?.status, equals('Inactive'));
      expect(subChildFromDb?.status, equals('Inactive'));
    });

    test('deleteOrgUnit clears parentId on children and orgUnitId on users', () async {
      // Seed parent, child, and user
      final parent = OrgUnitModel(
        id: 'PARENT_1',
        name: 'Parent',
        abbreviation: 'P',
        headOfEmail: 'h@ex.com',
        type: OrgUnitType.mdDivision,
        childIds: ['CHILD_1'],
        status: 'Active',
      );
      final child = OrgUnitModel(
        id: 'CHILD_1',
        name: 'Child',
        abbreviation: 'C',
        headOfEmail: 'c@ex.com',
        type: OrgUnitType.team,
        parentId: 'PARENT_1',
        childIds: [],
        status: 'Active',
      );
      final user = UserModel(
        id: 'USER_1',
        fullName: 'User One',
        email: 'user1@example.com',
        title: 'Developer',
        orgUnitId: 'CHILD_1',
        status: 'Active',
        role: 'User',
      );

      await firestore.collection('orgUnits').doc('PARENT_1').set(parent.toMap());
      await firestore.collection('orgUnits').doc('CHILD_1').set(child.toMap());
      await firestore.collection('users').doc(user.id).set(user.toMap());

      // Delete CHILD_1
      await service.deleteOrgUnit('CHILD_1');

      // Verify CHILD_1 deleted
      final childFromDb = await service.getOrgUnit('CHILD_1');
      expect(childFromDb, isNull);

      // Verify parent CHILD_1 reference removed
      final parentFromDb = await service.getOrgUnit('PARENT_1');
      expect(parentFromDb?.childIds, isEmpty);

      // Verify user orgUnitId cleared
      final userDoc = await firestore.collection('users').doc(user.id).get();
      final userFromDb = UserModel.fromMap(userDoc.data()!);
      expect(userFromDb.orgUnitId, isNull);
    });
  });
}
