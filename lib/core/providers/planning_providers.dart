// File: lib/core/providers/planning_providers.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/user_capacity_model.dart';
import '../../models/planning_demand_model.dart';
import '../../models/planning_allocation_model.dart';
import '../../models/lock_model.dart';
import 'auth_providers.dart';
import '../../services/database/database_service.dart';

part 'planning_providers.g.dart';

@riverpod
Stream<List<UserCapacityModel>> userCapacitiesStream(UserCapacitiesStreamRef ref, String email) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.status == 'Inactive') {
    return Stream.value(<UserCapacityModel>[]);
  }
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchUserCapacities(email);
}

@riverpod
Stream<List<PlanningDemandModel>> planningDemandsStream(PlanningDemandsStreamRef ref, int year) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.status == 'Inactive' || user.orgUnitId == null) {
    return Stream.value(<PlanningDemandModel>[]);
  }
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchPlanningDemands(user.orgUnitId!, year);
}

@riverpod
Stream<List<PlanningAllocationModel>> planningAllocationsStream(PlanningAllocationsStreamRef ref, int year) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.status == 'Inactive' || user.orgUnitId == null) {
    return Stream.value(<PlanningAllocationModel>[]);
  }
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchPlanningAllocations(user.orgUnitId!, year);
}

@riverpod
Stream<List<PlanningDemandModel>> allPlanningDemandsStream(AllPlanningDemandsStreamRef ref, String yearsCsv) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.status == 'Inactive') {
    return Stream.value(<PlanningDemandModel>[]);
  }
  final dbService = ref.watch(databaseServiceProvider);
  final years = yearsCsv.isEmpty
      ? <int>[]
      : yearsCsv.split(',').map(int.parse).toList();
  return dbService.watchAllPlanningDemands(years: years);
}

@riverpod
Stream<List<PlanningAllocationModel>> allPlanningAllocationsStream(AllPlanningAllocationsStreamRef ref, String yearsCsv) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.status == 'Inactive') {
    return Stream.value(<PlanningAllocationModel>[]);
  }
  final dbService = ref.watch(databaseServiceProvider);
  final years = yearsCsv.isEmpty
      ? <int>[]
      : yearsCsv.split(',').map(int.parse).toList();
  return dbService.watchAllPlanningAllocations(years: years);
}

@riverpod
Stream<List<LockModel>> locksStream(LocksStreamRef ref, int year) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.status == 'Inactive' || user.orgUnitId == null) {
    return Stream.value(<LockModel>[]);
  }
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchLocks(user.orgUnitId!, year);
}
