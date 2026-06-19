import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/org_unit_model.dart';
import '../../models/category_model.dart';
import '../../models/activity_group_model.dart';
import '../../models/activity_model.dart';
import '../../models/user_capacity_model.dart';
import '../../models/planning_demand_model.dart';
import '../../models/planning_allocation_model.dart';
import '../../models/lock_model.dart';
import '../../services/auth_service.dart';
import '../../services/database/database_service.dart';

export '../../services/database/database_service.dart'
    show
        databaseServiceProvider,
        DatabaseValidationException,
        OrgUnitCycleException;
export '../../services/auth_service.dart' show authServiceProvider;
export '../../models/category_model.dart' show CategoryModel;
export '../../models/activity_group_model.dart' show ActivityGroupModel;
export '../../models/activity_model.dart' show ActivityModel;
export '../../models/user_capacity_model.dart' show UserCapacityModel;
export '../../models/planning_demand_model.dart' show PlanningDemandModel;
export '../../models/planning_allocation_model.dart'
    show PlanningAllocationModel;
export '../../models/lock_model.dart' show LockModel;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import '../../firebase_options.dart';

enum AppEnvironment { local, dev, staging, prod }

class AppConfig {
  final AppEnvironment environment;
  final FirebaseOptions firebaseOptions;
  final bool useEmulator;

  const AppConfig({
    required this.environment,
    required this.firebaseOptions,
    required this.useEmulator,
  });
}

// Global Provider for the Active Environment Configuration
final appConfigProvider = Provider<AppConfig>((ref) {
  // Default to local/emulator configuration for safety (e.g. during testing)
  return const AppConfig(
    environment: AppEnvironment.local,
    firebaseOptions: DefaultFirebaseOptions.local,
    useEmulator: true,
  );
});

// Firebase Service Providers (mockable in tests)
final firebaseAuthProvider = Provider<Object>((ref) {
  final auth = FirebaseAuth.instance;
  final config = ref.watch(appConfigProvider);
  if (config.useEmulator) {
    try {
      auth.useAuthEmulator('127.0.0.1', 9099);
    } catch (_) {}
  }
  return auth;
});
final firestoreProvider = Provider<Object>((ref) {
  final firestore = FirebaseFirestore.instance;
  final config = ref.watch(appConfigProvider);
  if (config.useEmulator) {
    try {
      firestore.useFirestoreEmulator('127.0.0.1', 8080);
    } catch (_) {}
  }
  return firestore;
});

final authStateSyncProvider = StreamProvider<UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  final stream = authService.userStateChanges;
  final subscription = stream.listen((user) {
    if (user == null || user.status == 'Inactive') {
      authService.signOut();
    }
    ref.read(currentUserProvider.notifier).state = user;
  });
  ref.onDispose(() => subscription.cancel());
  return stream;
});

// User State Providers
final currentUserProvider = StateProvider<UserModel?>((ref) => null);

// Reset Password State Providers
final resetPasswordEmailProvider = StateProvider<String>((ref) => '');
final resetPasswordCodeProvider = StateProvider<String>((ref) => '123456');

// Navigation State Providers
final selectedTabCollectionProvider = StateProvider<String>(
  (ref) => 'Standard',
);
final currentAdminRouteProvider = StateProvider<String>(
  (ref) => 'users',
); // 'users' or 'orgs'
final selectedUserForDetailsProvider = StateProvider<UserModel?>((ref) => null);
final selectedOrgForDetailsProvider = StateProvider<OrgUnitModel?>(
  (ref) => null,
);

// Detailed form visibility providers for simulation
final showDetailedUserCreateFormProvider = StateProvider<bool>((ref) => false);
final showDetailedOrgCreateFormProvider = StateProvider<bool>((ref) => false);
final showDetailedOrgChildInputProvider = StateProvider<bool>((ref) => false);

// Stream Providers for Org Units
final orgUnitsStreamProvider = StreamProvider<List<OrgUnitModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.status == 'Inactive') {
    return Stream.value(<OrgUnitModel>[]);
  }
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchOrgUnits();
});

final orgUnitStreamProvider = StreamProvider.family<OrgUnitModel?, String>((
  ref,
  id,
) {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchOrgUnit(id);
});

// Stream Providers for Settings Features
final categoriesStreamProvider = StreamProvider<List<CategoryModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.status == 'Inactive') {
    return Stream.value(<CategoryModel>[]);
  }
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchCategories();
});

final activityGroupsStreamProvider = StreamProvider<List<ActivityGroupModel>>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.status == 'Inactive') {
    return Stream.value(<ActivityGroupModel>[]);
  }
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchActivityGroups();
});

final activitiesStreamProvider = StreamProvider<List<ActivityModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.status == 'Inactive') {
    return Stream.value(<ActivityModel>[]);
  }
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchActivities();
});

// Provider to get the organization unit that the current user is head of
final userOwnedOrgUnitProvider = Provider<OrgUnitModel?>((ref) {
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
});

// Stream Provider for User Capacities
final userCapacitiesStreamProvider =
    StreamProvider.family<List<UserCapacityModel>, String>((ref, email) {
      final user = ref.watch(currentUserProvider);
      if (user == null || user.status == 'Inactive') {
        return Stream.value(<UserCapacityModel>[]);
      }
      final dbService = ref.watch(databaseServiceProvider);
      return dbService.watchUserCapacities(email);
    });

// Stream Provider for Planning Demands
final planningDemandsStreamProvider =
    StreamProvider.family<List<PlanningDemandModel>, int>((ref, year) {
      final user = ref.watch(currentUserProvider);
      if (user == null || user.status == 'Inactive' || user.orgUnitId == null) {
        return Stream.value(<PlanningDemandModel>[]);
      }
      final dbService = ref.watch(databaseServiceProvider);
      return dbService.watchPlanningDemands(user.orgUnitId!, year);
    });

// Stream Provider for Planning Allocations
final planningAllocationsStreamProvider =
    StreamProvider.family<List<PlanningAllocationModel>, int>((ref, year) {
      final user = ref.watch(currentUserProvider);
      if (user == null || user.status == 'Inactive' || user.orgUnitId == null) {
        return Stream.value(<PlanningAllocationModel>[]);
      }
      final dbService = ref.watch(databaseServiceProvider);
      return dbService.watchPlanningAllocations(user.orgUnitId!, year);
    });

// Stream Provider for All Planning Demands (Global)
final allPlanningDemandsStreamProvider =
    StreamProvider.family<List<PlanningDemandModel>, String>((ref, yearsCsv) {
      final user = ref.watch(currentUserProvider);
      if (user == null || user.status == 'Inactive') {
        return Stream.value(<PlanningDemandModel>[]);
      }
      final dbService = ref.watch(databaseServiceProvider);
      final years = yearsCsv.isEmpty
          ? <int>[]
          : yearsCsv.split(',').map(int.parse).toList();
      return dbService.watchAllPlanningDemands(years: years);
    });

// Stream Provider for All Planning Allocations (Global)
final allPlanningAllocationsStreamProvider =
    StreamProvider.family<List<PlanningAllocationModel>, String>((ref, yearsCsv) {
      final user = ref.watch(currentUserProvider);
      if (user == null || user.status == 'Inactive') {
        return Stream.value(<PlanningAllocationModel>[]);
      }
      final dbService = ref.watch(databaseServiceProvider);
      final years = yearsCsv.isEmpty
          ? <int>[]
          : yearsCsv.split(',').map(int.parse).toList();
      return dbService.watchAllPlanningAllocations(years: years);
    });

// Stream Provider for All Users
final allUsersStreamProvider = StreamProvider<List<UserModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.status == 'Inactive') {
    return Stream.value(<UserModel>[]);
  }
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchUsers();
});

// Stream Provider for Locks
final locksStreamProvider = StreamProvider.family<List<LockModel>, int>((
  ref,
  year,
) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.status == 'Inactive' || user.orgUnitId == null) {
    return Stream.value(<LockModel>[]);
  }
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchLocks(user.orgUnitId!, year);
});
