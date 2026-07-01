// File: lib/core/providers/settings_providers.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/category_model.dart';
import '../../models/activity_group_model.dart';
import '../../models/activity_model.dart';
import '../../models/user_model.dart';
import 'auth_providers.dart';
import '../../services/database/database_service.dart';

part 'settings_providers.g.dart';

@riverpod
Stream<List<CategoryModel>> categoriesStream(CategoriesStreamRef ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.status == 'Inactive') {
    return Stream.value(<CategoryModel>[]);
  }
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchCategories();
}

@riverpod
Stream<List<ActivityGroupModel>> activityGroupsStream(ActivityGroupsStreamRef ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.status == 'Inactive') {
    return Stream.value(<ActivityGroupModel>[]);
  }
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchActivityGroups();
}

@riverpod
Stream<List<ActivityModel>> activitiesStream(ActivitiesStreamRef ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.status == 'Inactive') {
    return Stream.value(<ActivityModel>[]);
  }
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchActivities();
}

@riverpod
Stream<List<UserModel>> allUsersStream(AllUsersStreamRef ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.status == 'Inactive') {
    return Stream.value(<UserModel>[]);
  }
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchUsers();
}
