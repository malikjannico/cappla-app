import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/models/enums.dart';
import 'package:cappla/services/database/database_service.dart';

/// Validator for organization unit business rules and hierarchy constraints.
class OrgUnitValidator {
  /// Validates hierarchy type constraints, references, and cycle prevention rules for [orgUnit].
  ///
  /// Throws [DatabaseValidationException] if constraints are violated.
  /// Throws [OrgUnitCycleException] if a cycle is detected.
  static Future<void> validate({
    required OrgUnitModel orgUnit,
    required Future<OrgUnitModel?> Function(String id) getOrgUnit,
  }) async {
    // 1. Service/Database-Level Type Constraints
    if (orgUnit.type == OrgUnitType.mdDivision && orgUnit.parentId != null) {
      throw DatabaseValidationException(
        'Hierarchy error: MD Division cannot have a parent assigned.',
      );
    }
    if (orgUnit.type == OrgUnitType.team && orgUnit.childIds.isNotEmpty) {
      throw DatabaseValidationException(
        'Hierarchy error: Team cannot have children.',
      );
    }

    // 2. Existence Checks
    if (orgUnit.parentId != null) {
      final parent = await getOrgUnit(orgUnit.parentId!);
      if (parent == null) {
        throw DatabaseValidationException('Parent unit does not exist.');
      }
    }

    for (final childId in orgUnit.childIds) {
      final child = await getOrgUnit(childId);
      if (child == null) {
        throw DatabaseValidationException('Child unit does not exist.');
      }
    }

    // 3. Cycle Prevention Check
    final Set<String> ancestors = {};
    String? currentParentId = orgUnit.parentId;
    while (currentParentId != null) {
      if (currentParentId == orgUnit.id) {
        throw OrgUnitCycleException(
          'Cycle detected: Circular hierarchy not allowed.',
        );
      }
      if (ancestors.contains(currentParentId)) {
        throw OrgUnitCycleException(
          'Cycle detected: Circular hierarchy not allowed.',
        );
      }
      final parent = await getOrgUnit(currentParentId);
      if (parent == null) break;
      ancestors.add(currentParentId);
      currentParentId = parent.parentId;
    }

    for (final childId in orgUnit.childIds) {
      if (ancestors.contains(childId) || childId == orgUnit.id) {
        throw OrgUnitCycleException(
          'Cycle detected: Circular hierarchy not allowed.',
        );
      }
    }
  }
}
