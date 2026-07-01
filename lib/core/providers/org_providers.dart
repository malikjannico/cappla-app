// File: lib/core/providers/org_providers.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/org_unit_model.dart';
import 'auth_providers.dart';
import '../../services/database/database_service.dart';

part 'org_providers.g.dart';

@riverpod
Stream<List<OrgUnitModel>> orgUnitsStream(OrgUnitsStreamRef ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.status == 'Inactive') {
    return Stream.value(<OrgUnitModel>[]);
  }
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchOrgUnits();
}

@riverpod
Stream<OrgUnitModel?> orgUnitStream(OrgUnitStreamRef ref, String id) {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchOrgUnit(id);
}

@riverpod
OrgUnitModel? userOwnedOrgUnit(UserOwnedOrgUnitRef ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final orgUnits = ref.watch(orgUnitsStreamProvider).value ?? [];
  try {
    return orgUnits.firstWhere(
      (org) =>
          org.headOfEmail.trim().toLowerCase() ==
          user.email.trim().toLowerCase(),
    );
  } catch (_) {
    return null;
  }
}

@riverpod
OrgUnitModel? userOrgUnit(UserOrgUnitRef ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.orgUnitId == null) return null;
  return ref.watch(orgUnitStreamProvider(user.orgUnitId!)).value;
}
