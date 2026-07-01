import 'package:flutter_test/flutter_test.dart';
import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/services/database/database_service.dart';
import 'package:cappla/core/utils/org_unit_validator.dart';

void main() {
  group('OrgUnitValidator Unit Tests', () {
    late Map<String, OrgUnitModel> mockDatabase;

    setUp(() {
      mockDatabase = {};
    });

    Future<OrgUnitModel?> mockGetOrgUnit(String id) async {
      return mockDatabase[id];
    }

    test('Throws DatabaseValidationException if MD Division has a parent', () async {
      final division = OrgUnitModel(
        id: 'DIV_1',
        name: 'MD Division 1',
        abbreviation: 'MD1',
        headOfEmail: 'head@vetter.com',
        type: 'md division',
        parentId: 'PARENT_1',
        childIds: [],
        status: 'Active',
      );

      expect(
        () => OrgUnitValidator.validate(
          orgUnit: division,
          getOrgUnit: mockGetOrgUnit,
        ),
        throwsA(
          isA<DatabaseValidationException>().having(
            (e) => e.toString(),
            'message',
            contains('MD Division cannot have a parent assigned.'),
          ),
        ),
      );
    });

    test('Throws DatabaseValidationException if Team has child units assigned', () async {
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
        () => OrgUnitValidator.validate(
          orgUnit: team,
          getOrgUnit: mockGetOrgUnit,
        ),
        throwsA(
          isA<DatabaseValidationException>().having(
            (e) => e.toString(),
            'message',
            contains('Team cannot have children.'),
          ),
        ),
      );
    });

    test('Throws DatabaseValidationException if parent unit does not exist', () async {
      final unit = OrgUnitModel(
        id: 'UNIT_1',
        name: 'Department 1',
        abbreviation: 'D1',
        headOfEmail: 'head@vetter.com',
        type: 'department',
        parentId: 'NON_EXISTENT_PARENT',
        childIds: [],
        status: 'Active',
      );

      expect(
        () => OrgUnitValidator.validate(
          orgUnit: unit,
          getOrgUnit: mockGetOrgUnit,
        ),
        throwsA(
          isA<DatabaseValidationException>().having(
            (e) => e.toString(),
            'message',
            contains('Parent unit does not exist.'),
          ),
        ),
      );
    });

    test('Throws DatabaseValidationException if child unit does not exist', () async {
      final unit = OrgUnitModel(
        id: 'UNIT_1',
        name: 'Department 1',
        abbreviation: 'D1',
        headOfEmail: 'head@vetter.com',
        type: 'department',
        parentId: null,
        childIds: ['NON_EXISTENT_CHILD'],
        status: 'Active',
      );

      expect(
        () => OrgUnitValidator.validate(
          orgUnit: unit,
          getOrgUnit: mockGetOrgUnit,
        ),
        throwsA(
          isA<DatabaseValidationException>().having(
            (e) => e.toString(),
            'message',
            contains('Child unit does not exist.'),
          ),
        ),
      );
    });

    test('Throws OrgUnitCycleException if unit is its own parent', () async {
      final unit = OrgUnitModel(
        id: 'UNIT_1',
        name: 'Department 1',
        abbreviation: 'D1',
        headOfEmail: 'head@vetter.com',
        type: 'department',
        parentId: 'UNIT_1',
        childIds: [],
        status: 'Active',
      );
      // Seed self in DB so existence check passes
      mockDatabase['UNIT_1'] = unit;

      expect(
        () => OrgUnitValidator.validate(
          orgUnit: unit,
          getOrgUnit: mockGetOrgUnit,
        ),
        throwsA(
          isA<OrgUnitCycleException>().having(
            (e) => e.toString(),
            'message',
            contains('Cycle detected: Circular hierarchy not allowed.'),
          ),
        ),
      );
    });

    test('Throws OrgUnitCycleException for loop A -> B -> A', () async {
      final unitB = OrgUnitModel(
        id: 'UNIT_B',
        name: 'Department B',
        abbreviation: 'DB',
        headOfEmail: 'head@vetter.com',
        type: 'department',
        parentId: 'UNIT_A',
        childIds: [],
        status: 'Active',
      );
      final unitA = OrgUnitModel(
        id: 'UNIT_A',
        name: 'Department A',
        abbreviation: 'DA',
        headOfEmail: 'head@vetter.com',
        type: 'department',
        parentId: 'UNIT_B',
        childIds: [],
        status: 'Active',
      );
      mockDatabase['UNIT_B'] = unitB;
      mockDatabase['UNIT_A'] = unitA;

      expect(
        () => OrgUnitValidator.validate(
          orgUnit: unitA,
          getOrgUnit: mockGetOrgUnit,
        ),
        throwsA(
          isA<OrgUnitCycleException>().having(
            (e) => e.toString(),
            'message',
            contains('Cycle detected: Circular hierarchy not allowed.'),
          ),
        ),
      );
    });

    test('Throws OrgUnitCycleException for loop A -> B -> C -> A', () async {
      final unitC = OrgUnitModel(
        id: 'UNIT_C',
        name: 'Department C',
        abbreviation: 'DC',
        headOfEmail: 'head@vetter.com',
        type: 'department',
        parentId: 'UNIT_B',
        childIds: [],
        status: 'Active',
      );
      final unitB = OrgUnitModel(
        id: 'UNIT_B',
        name: 'Department B',
        abbreviation: 'DB',
        headOfEmail: 'head@vetter.com',
        type: 'department',
        parentId: 'UNIT_A',
        childIds: [],
        status: 'Active',
      );
      final unitA = OrgUnitModel(
        id: 'UNIT_A',
        name: 'Department A',
        abbreviation: 'DA',
        headOfEmail: 'head@vetter.com',
        type: 'department',
        parentId: 'UNIT_C',
        childIds: [],
        status: 'Active',
      );
      mockDatabase['UNIT_C'] = unitC;
      mockDatabase['UNIT_B'] = unitB;
      mockDatabase['UNIT_A'] = unitA;

      expect(
        () => OrgUnitValidator.validate(
          orgUnit: unitA,
          getOrgUnit: mockGetOrgUnit,
        ),
        throwsA(
          isA<OrgUnitCycleException>().having(
            (e) => e.toString(),
            'message',
            contains('Cycle detected: Circular hierarchy not allowed.'),
          ),
        ),
      );
    });

    test('Succeeds on valid hierarchy', () async {
      final root = OrgUnitModel(
        id: 'ROOT',
        name: 'MD Div',
        abbreviation: 'MDD',
        headOfEmail: 'head@vetter.com',
        type: 'md division',
        parentId: null,
        childIds: ['CHILD'],
        status: 'Active',
      );
      final child = OrgUnitModel(
        id: 'CHILD',
        name: 'Department Child',
        abbreviation: 'DC',
        headOfEmail: 'head@vetter.com',
        type: 'department',
        parentId: 'ROOT',
        childIds: [],
        status: 'Active',
      );
      mockDatabase['ROOT'] = root;
      mockDatabase['CHILD'] = child;

      await expectLater(
        OrgUnitValidator.validate(
          orgUnit: child,
          getOrgUnit: mockGetOrgUnit,
        ),
        completes,
      );
    });
  });
}
