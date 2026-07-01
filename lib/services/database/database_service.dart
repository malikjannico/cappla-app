import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/org_unit_model.dart';
import 'firestore_database_service.dart';
import '../../core/providers/providers.dart';

class DatabaseValidationException implements Exception {
  final String message;
  DatabaseValidationException(this.message);
  @override
  String toString() => message;
}

class OrgUnitCycleException extends DatabaseValidationException {
  OrgUnitCycleException(super.message);
}

abstract class DatabaseService {
  Future<UserModel?> getUser(String email);
  Future<UserModel?> getUserById(String id);
  Future<void> saveUser(UserModel user);
  Future<void> deleteUser(String id);
  Stream<UserModel?> watchUser(String id);
  Stream<UserModel?> watchUserByEmail(String email);
  Stream<List<UserModel>> watchUsers();
  Future<List<UserModel>> getAllUsers();
  Future<OrgUnitModel?> getOrgUnit(String id);
  Future<void> saveOrgUnit(OrgUnitModel orgUnit);
  Future<void> deleteOrgUnit(String id);
  Future<List<OrgUnitModel>> getAllOrgUnits();
  Stream<List<OrgUnitModel>> watchOrgUnits();
  Stream<OrgUnitModel?> watchOrgUnit(String id);
  Future<void> seedUsers();

  // Categories
  Future<CategoryModel?> getCategory(String id);
  Future<void> saveCategory(CategoryModel category);
  Future<void> deleteCategory(String id, String deletingOrgUnitId);
  Future<List<CategoryModel>> getAllCategories();
  Stream<List<CategoryModel>> watchCategories();
  Stream<CategoryModel?> watchCategory(String id);

  // Activity Groups
  Future<ActivityGroupModel?> getActivityGroup(String id);
  Future<void> saveActivityGroup(ActivityGroupModel activityGroup);
  Future<void> deleteActivityGroup(String id, String deletingOrgUnitId);
  Future<List<ActivityGroupModel>> getAllActivityGroups();
  Stream<List<ActivityGroupModel>> watchActivityGroups();
  Stream<ActivityGroupModel?> watchActivityGroup(String id);

  // Activities
  Future<ActivityModel?> getActivity(String id);
  Future<void> saveActivity(ActivityModel activity);
  Future<void> deleteActivity(String id, String deletingOrgUnitId);
  Future<List<ActivityModel>> getAllActivities();
  Stream<List<ActivityModel>> watchActivities();
  Stream<ActivityModel?> watchActivity(String id);

  // Capacities
  Future<List<UserCapacityModel>> getUserCapacities(String userEmail);
  Future<void> saveUserCapacity(UserCapacityModel capacity);
  Future<void> deleteUserCapacity(String id);
  Stream<List<UserCapacityModel>> watchUserCapacities(String userEmail);

  // Planning Demands
  Future<void> savePlanningDemand(PlanningDemandModel demand);
  Future<void> deletePlanningDemand(String id);
  Stream<List<PlanningDemandModel>> watchPlanningDemands(
    String orgUnitId,
    int year,
  );
  Stream<List<PlanningDemandModel>> watchAllPlanningDemands({List<int>? years});

  // Planning Allocations
  Future<void> savePlanningAllocation(PlanningAllocationModel allocation);
  Future<void> deletePlanningAllocation(String id);
  Stream<List<PlanningAllocationModel>> watchPlanningAllocations(
    String orgUnitId,
    int year,
  );
  Stream<List<PlanningAllocationModel>> watchAllPlanningAllocations({List<int>? years});

  // Locks
  Future<bool> acquireLock(LockModel lock);
  Future<void> releaseLock(String lockId);
  Stream<List<LockModel>> watchLocks(String orgUnitId, int year);
  Future<List<LockModel>> getLocks(String orgUnitId, int year);
}

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final db = ref.watch(firestoreProvider);
  return FirestoreDatabaseService(db);
});
