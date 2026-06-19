import 'dart:async';
import '../../models/user_model.dart';
import '../../models/org_unit_model.dart';
import '../../models/category_model.dart';
import '../../models/activity_group_model.dart';
import '../../models/activity_model.dart';
import '../../models/user_capacity_model.dart';
import '../../models/planning_demand_model.dart';
import '../../models/planning_allocation_model.dart';
import '../../models/lock_model.dart';
import 'database_service.dart';
import 'seed_data_provider.dart';

class MockFirestoreDatabaseServiceWrapper implements DatabaseService {
  final dynamic _mockFirestore;
  MockFirestoreDatabaseServiceWrapper(this._mockFirestore);

  @override
  Future<UserModel?> getUser(String email) async {
    final Map<String, dynamic>? usersMap = _mockFirestore.collections['users'];
    if (usersMap == null) return null;
    final normalized = email.trim().toLowerCase();
    final data = usersMap[normalized];
    if (data != null) {
      return UserModel.fromMap(Map<String, dynamic>.from(data));
    }
    return null;
  }

  @override
  Future<UserModel?> getUserById(String id) async {
    final Map<String, dynamic>? usersMap = _mockFirestore.collections['users'];
    if (usersMap == null) return null;
    for (final data in usersMap.values) {
      final user = UserModel.fromMap(Map<String, dynamic>.from(data));
      if (user.id == id) {
        return user;
      }
    }
    return null;
  }

  @override
  Future<void> saveUser(UserModel user) async {
    final lowerEmail = user.email.trim().toLowerCase();
    _mockFirestore.setData('users', lowerEmail, user.toMap());

    // Auto-create standard capacity row if not present
    final capacityDocId = 'standard_$lowerEmail';
    final capacitiesMap = _mockFirestore.collections['userCapacities'];
    final exists =
        capacitiesMap != null && capacitiesMap.containsKey(capacityDocId);
    if (!exists) {
      final defaultStandard = UserCapacityModel(
        id: capacityDocId,
        userEmail: lowerEmail,
        type: 'Standard',
        monday: 8.0,
        tuesday: 8.0,
        wednesday: 8.0,
        thursday: 8.0,
        friday: 8.0,
        saturday: 0.0,
        sunday: 0.0,
      );
      await saveUserCapacity(defaultStandard);
    }
  }

  @override
  Future<void> deleteUser(String id) async {
    final user = await getUserById(id);
    if (user != null) {
      _mockFirestore.deleteData('users', user.email.trim().toLowerCase());
    }
  }

  @override
  Stream<UserModel?> watchUser(String id) {
    Stream<UserModel?> getStream() async* {
      yield await getUserById(id);
      try {
        final Stream<void> changeStream = _mockFirestore.onChange;
        await for (final _ in changeStream) {
          yield await getUserById(id);
        }
      } catch (_) {
        while (true) {
          await Future.delayed(const Duration(milliseconds: 100));
          yield await getUserById(id);
        }
      }
    }

    return getStream().distinct((prev, next) {
      if (prev == null && next == null) return true;
      if (prev == null || next == null) return false;
      return prev.id == next.id &&
          prev.email == next.email &&
          prev.fullName == next.fullName &&
          prev.role == next.role &&
          prev.status == next.status &&
          prev.title == next.title &&
          prev.orgUnitId == next.orgUnitId;
    });
  }

  @override
  Stream<UserModel?> watchUserByEmail(String email) {
    Stream<UserModel?> getStream() async* {
      yield await getUser(email);
      try {
        final Stream<void> changeStream = _mockFirestore.onChange;
        await for (final _ in changeStream) {
          yield await getUser(email);
        }
      } catch (_) {
        while (true) {
          await Future.delayed(const Duration(milliseconds: 100));
          yield await getUser(email);
        }
      }
    }

    return getStream().distinct((prev, next) {
      if (prev == null && next == null) return true;
      if (prev == null || next == null) return false;
      return prev.id == next.id &&
          prev.email == next.email &&
          prev.fullName == next.fullName &&
          prev.role == next.role &&
          prev.status == next.status &&
          prev.title == next.title &&
          prev.orgUnitId == next.orgUnitId;
    });
  }

  @override
  Stream<List<UserModel>> watchUsers() {
    Stream<List<UserModel>> getStream() async* {
      yield await getAllUsers();
      try {
        final Stream<void> changeStream = _mockFirestore.onChange;
        await for (final _ in changeStream) {
          yield await getAllUsers();
        }
      } catch (_) {
        while (true) {
          await Future.delayed(const Duration(milliseconds: 100));
          yield await getAllUsers();
        }
      }
    }

    return getStream().distinct((prev, next) {
      if (prev.length != next.length) return false;
      for (int i = 0; i < prev.length; i++) {
        final p = prev[i];
        final n = next[i];
        if (p.email != n.email ||
            p.fullName != n.fullName ||
            p.role != n.role ||
            p.status != n.status ||
            p.title != n.title ||
            p.orgUnitId != n.orgUnitId) {
          return false;
        }
      }
      return true;
    });
  }

  @override
  Future<List<UserModel>> getAllUsers() async {
    final Map<String, dynamic>? usersMap = _mockFirestore.collections['users'];
    if (usersMap == null) return [];
    return usersMap.values
        .map((e) => UserModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<OrgUnitModel?> getOrgUnit(String id) async {
    final data = _mockFirestore.getData('orgUnits', id);
    if (data != null) {
      return OrgUnitModel.fromMap(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<void> _rawWriteOrgUnit(OrgUnitModel unit) async {
    _mockFirestore.setData('orgUnits', unit.id, unit.toMap());
  }

  @override
  Stream<OrgUnitModel?> watchOrgUnit(String id) {
    Stream<OrgUnitModel?> getStream() async* {
      yield await getOrgUnit(id);
      try {
        final Stream<void> changeStream = _mockFirestore.onChange;
        await for (final _ in changeStream) {
          yield await getOrgUnit(id);
        }
      } catch (_) {
        while (true) {
          await Future.delayed(const Duration(milliseconds: 100));
          yield await getOrgUnit(id);
        }
      }
    }

    return getStream().distinct((prev, next) {
      if (prev == null && next == null) return true;
      if (prev == null || next == null) return false;
      return prev.id == next.id &&
          prev.name == next.name &&
          prev.abbreviation == next.abbreviation &&
          prev.headOfEmail == next.headOfEmail &&
          prev.type == next.type &&
          prev.parentId == next.parentId &&
          prev.status == next.status &&
          prev.childIds.join(',') == next.childIds.join(',');
    });
  }

  @override
  Stream<List<OrgUnitModel>> watchOrgUnits() {
    Stream<List<OrgUnitModel>> getStream() async* {
      yield await getAllOrgUnits();
      try {
        final Stream<void> changeStream = _mockFirestore.onChange;
        await for (final _ in changeStream) {
          yield await getAllOrgUnits();
        }
      } catch (_) {
        while (true) {
          await Future.delayed(const Duration(milliseconds: 100));
          yield await getAllOrgUnits();
        }
      }
    }

    return getStream().distinct((prev, next) {
      if (prev.length != next.length) return false;
      for (int i = 0; i < prev.length; i++) {
        final p = prev[i];
        final n = next[i];
        if (p.id != n.id ||
            p.name != n.name ||
            p.abbreviation != n.abbreviation ||
            p.headOfEmail != n.headOfEmail ||
            p.type != n.type ||
            p.parentId != n.parentId ||
            p.status != n.status ||
            p.childIds.join(',') != n.childIds.join(',')) {
          return false;
        }
      }
      return true;
    });
  }

  @override
  Future<void> saveOrgUnit(OrgUnitModel orgUnit) async {
    // Service/Database-Level Type Constraints
    if (orgUnit.type == 'md division' && orgUnit.parentId != null) {
      throw DatabaseValidationException(
        'Hierarchy error: MD Division cannot have a parent assigned.',
      );
    }
    if (orgUnit.type == 'team' && orgUnit.childIds.isNotEmpty) {
      throw DatabaseValidationException(
        'Hierarchy error: Team cannot have children.',
      );
    }

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

    // Cycle Prevention Check
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

    final oldOrgUnit = await getOrgUnit(orgUnit.id);

    // Save org unit
    await _rawWriteOrgUnit(orgUnit);

    // Dissolving relation & Syncing
    if (oldOrgUnit == null) {
      // New Org Unit
      if (orgUnit.parentId != null) {
        final parent = await getOrgUnit(orgUnit.parentId!);
        if (parent != null) {
          if (!parent.childIds.contains(orgUnit.id)) {
            await _rawWriteOrgUnit(
              parent.copyWith(childIds: [...parent.childIds, orgUnit.id]),
            );
          }
        }
      }
      if (orgUnit.childIds.isNotEmpty) {
        for (final cId in orgUnit.childIds) {
          final child = await getOrgUnit(cId);
          if (child != null) {
            if (child.parentId != null && child.parentId != orgUnit.id) {
              final oldParent = await getOrgUnit(child.parentId!);
              if (oldParent != null) {
                await _rawWriteOrgUnit(
                  oldParent.copyWith(
                    childIds: oldParent.childIds
                        .where((id) => id != cId)
                        .toList(),
                  ),
                );
              }
            }
            await _rawWriteOrgUnit(child.copyWith(parentId: () => orgUnit.id));
          }
        }
      }
    } else {
      // Existing Org Unit
      // If parentId changes
      if (oldOrgUnit.parentId != orgUnit.parentId) {
        if (oldOrgUnit.parentId != null) {
          final oldParent = await getOrgUnit(oldOrgUnit.parentId!);
          if (oldParent != null) {
            await _rawWriteOrgUnit(
              oldParent.copyWith(
                childIds: oldParent.childIds
                    .where((id) => id != orgUnit.id)
                    .toList(),
              ),
            );
          }
        }
        if (orgUnit.parentId != null) {
          final newParent = await getOrgUnit(orgUnit.parentId!);
          if (newParent != null) {
            if (!newParent.childIds.contains(orgUnit.id)) {
              await _rawWriteOrgUnit(
                newParent.copyWith(
                  childIds: [...newParent.childIds, orgUnit.id],
                ),
              );
            }
          }
        }
      }
      // If children list changes
      final oldChildren = oldOrgUnit.childIds;
      final newChildren = orgUnit.childIds;
      final removedChildren = oldChildren
          .where((id) => !newChildren.contains(id))
          .toList();
      final addedChildren = newChildren
          .where((id) => !oldChildren.contains(id))
          .toList();

      for (final cId in removedChildren) {
        final child = await getOrgUnit(cId);
        if (child != null && child.parentId == orgUnit.id) {
          await _rawWriteOrgUnit(child.copyWith(parentId: () => null));
        }
      }
      for (final cId in addedChildren) {
        final child = await getOrgUnit(cId);
        if (child != null) {
          if (child.parentId != null && child.parentId != orgUnit.id) {
            final oldParent = await getOrgUnit(child.parentId!);
            if (oldParent != null) {
              await _rawWriteOrgUnit(
                oldParent.copyWith(
                  childIds: oldParent.childIds
                      .where((id) => id != cId)
                      .toList(),
                ),
              );
            }
          }
          await _rawWriteOrgUnit(child.copyWith(parentId: () => orgUnit.id));
        }
      }
    }

    // Active status propagation
    if (orgUnit.status == 'Inactive') {
      await _propagateInactiveStatus(orgUnit.childIds, {orgUnit.id});
    }
  }

  Future<void> _propagateInactiveStatus(
    List<String> childIds,
    Set<String> visited,
  ) async {
    for (final childId in childIds) {
      if (visited.contains(childId)) continue;
      visited.add(childId);
      final child = await getOrgUnit(childId);
      if (child != null) {
        if (child.status != 'Inactive') {
          await _rawWriteOrgUnit(child.copyWith(status: 'Inactive'));
          await _propagateInactiveStatus(child.childIds, visited);
        }
      }
    }
  }

  @override
  Future<void> deleteOrgUnit(String id) async {
    final unit = await getOrgUnit(id);
    if (unit != null) {
      // Remove id from parent's childIds
      if (unit.parentId != null) {
        final parent = await getOrgUnit(unit.parentId!);
        if (parent != null) {
          await _rawWriteOrgUnit(
            parent.copyWith(
              childIds: parent.childIds.where((cId) => cId != id).toList(),
            ),
          );
        }
      }
      // Clear parentId on all children
      for (final cId in unit.childIds) {
        final child = await getOrgUnit(cId);
        if (child != null) {
          await _rawWriteOrgUnit(child.copyWith(parentId: () => null));
        }
      }
      // Clear orgUnitId on all users associated
      final allUsers = await getAllUsers();
      for (final user in allUsers) {
        if (user.orgUnitId == id) {
          await saveUser(
            UserModel(
              id: user.id,
              fullName: user.fullName,
              email: user.email,
              title: user.title,
              orgUnitId: null,
              status: user.status,
              role: user.role,
            ),
          );
        }
      }
    }
    _mockFirestore.deleteData('orgUnits', id);
  }

  @override
  Future<List<OrgUnitModel>> getAllOrgUnits() async {
    final Map<String, dynamic>? orgsMap =
        _mockFirestore.collections['orgUnits'];
    if (orgsMap == null) return [];
    return orgsMap.values
        .map((e) => OrgUnitModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<void> seedUsers() async {
    await performFullSeeding(this);
  }

  // --- Categories ---
  @override
  Future<CategoryModel?> getCategory(String id) async {
    final Map<String, dynamic>? categoriesMap =
        _mockFirestore.collections['categories'];
    if (categoriesMap == null) return null;
    final data = categoriesMap[id];
    if (data != null) {
      return CategoryModel.fromMap(Map<String, dynamic>.from(data));
    }
    return null;
  }

  @override
  Future<void> saveCategory(CategoryModel category) async {
    _mockFirestore.setData('categories', category.id, category.toMap());
  }

  @override
  Future<void> deleteCategory(String id, String deletingOrgUnitId) async {
    final category = await getCategory(id);
    if (category == null) return;

    final allActs = await getAllActivities();
    final hasActivityUsingCategory = allActs.any((act) {
      return act.categoryId == id &&
          (act.ownerOrgUnitId == deletingOrgUnitId ||
              act.appliedOrgUnitIds.contains(deletingOrgUnitId));
    });
    if (hasActivityUsingCategory) {
      throw DatabaseValidationException(
        'Cannot delete category: Category is selected in one or more activities.',
      );
    }

    if (category.ownerOrgUnitId == deletingOrgUnitId) {
      final otherApplied = category.appliedOrgUnitIds
          .where((orgId) => orgId != deletingOrgUnitId)
          .toList();
      if (otherApplied.isNotEmpty) {
        final nextOwner = otherApplied.first;
        final updated = category.copyWith(
          ownerOrgUnitId: nextOwner,
          appliedOrgUnitIds: otherApplied.sublist(1),
          statusMap: Map<String, String>.from(category.statusMap)
            ..remove(deletingOrgUnitId),
        );
        await saveCategory(updated);
      } else {
        _mockFirestore.deleteData('categories', id);
      }
    } else {
      final updated = category.copyWith(
        appliedOrgUnitIds: category.appliedOrgUnitIds
            .where((orgId) => orgId != deletingOrgUnitId)
            .toList(),
        statusMap: Map<String, String>.from(category.statusMap)
          ..remove(deletingOrgUnitId),
      );
      await saveCategory(updated);
    }
  }

  @override
  Future<List<CategoryModel>> getAllCategories() async {
    final Map<String, dynamic>? categoriesMap =
        _mockFirestore.collections['categories'];
    if (categoriesMap == null) return [];
    return categoriesMap.values
        .map((e) => CategoryModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Stream<List<CategoryModel>> watchCategories() {
    Stream<List<CategoryModel>> getStream() async* {
      yield await getAllCategories();
      try {
        final Stream<void> changeStream = _mockFirestore.onChange;
        await for (final _ in changeStream) {
          yield await getAllCategories();
        }
      } catch (_) {
        while (true) {
          await Future.delayed(const Duration(milliseconds: 100));
          yield await getAllCategories();
        }
      }
    }

    return getStream();
  }

  @override
  Stream<CategoryModel?> watchCategory(String id) {
    Stream<CategoryModel?> getStream() async* {
      yield await getCategory(id);
      try {
        final Stream<void> changeStream = _mockFirestore.onChange;
        await for (final _ in changeStream) {
          yield await getCategory(id);
        }
      } catch (_) {
        while (true) {
          await Future.delayed(const Duration(milliseconds: 100));
          yield await getCategory(id);
        }
      }
    }

    return getStream();
  }

  // --- Activity Groups ---
  @override
  Future<ActivityGroupModel?> getActivityGroup(String id) async {
    final Map<String, dynamic>? groupsMap =
        _mockFirestore.collections['activityGroups'];
    if (groupsMap == null) return null;
    final data = groupsMap[id];
    if (data != null) {
      return ActivityGroupModel.fromMap(Map<String, dynamic>.from(data));
    }
    return null;
  }

  @override
  Future<void> saveActivityGroup(ActivityGroupModel activityGroup) async {
    final oldGroup = await getActivityGroup(activityGroup.id);
    _mockFirestore.setData(
      'activityGroups',
      activityGroup.id,
      activityGroup.toMap(),
    );

    if (oldGroup != null) {
      for (final entry in activityGroup.statusMap.entries) {
        final orgId = entry.key;
        final newStatus = entry.value;
        final oldStatus = oldGroup.statusMap[orgId];
        if (newStatus == 'Inactive' && oldStatus != 'Inactive') {
          final activities = await _rawGetAllActivities();
          for (final act in activities) {
            if (act.activityGroupId == activityGroup.id &&
                act.statusMap[orgId] == 'Active') {
              final updatedAct = act.copyWith(
                statusMap: {...act.statusMap, orgId: 'Inactive'},
              );
              await saveActivity(updatedAct);
            }
          }
        }
      }
    }
  }

  @override
  Future<void> deleteActivityGroup(String id, String deletingOrgUnitId) async {
    final group = await getActivityGroup(id);
    if (group == null) return;

    final allActs = await getAllActivities();
    final hasActivities = allActs.any((act) {
      return act.activityGroupId == id &&
          (act.ownerOrgUnitId == deletingOrgUnitId ||
              act.appliedOrgUnitIds.contains(deletingOrgUnitId));
    });
    if (hasActivities) {
      throw DatabaseValidationException(
        'Cannot delete activity group: Activity group contains activities. Delete the activities first.',
      );
    }

    if (group.ownerOrgUnitId == deletingOrgUnitId) {
      final otherApplied = group.appliedOrgUnitIds
          .where((orgId) => orgId != deletingOrgUnitId)
          .toList();
      if (otherApplied.isNotEmpty) {
        final nextOwner = otherApplied.first;
        final updated = group.copyWith(
          ownerOrgUnitId: nextOwner,
          appliedOrgUnitIds: otherApplied.sublist(1),
          statusMap: Map<String, String>.from(group.statusMap)
            ..remove(deletingOrgUnitId),
        );
        await saveActivityGroup(updated);
      } else {
        _mockFirestore.deleteData('activityGroups', id);
      }
    } else {
      final updated = group.copyWith(
        appliedOrgUnitIds: group.appliedOrgUnitIds
            .where((orgId) => orgId != deletingOrgUnitId)
            .toList(),
        statusMap: Map<String, String>.from(group.statusMap)
          ..remove(deletingOrgUnitId),
      );
      await saveActivityGroup(updated);
    }
  }

  @override
  Future<List<ActivityGroupModel>> getAllActivityGroups() async {
    final Map<String, dynamic>? groupsMap =
        _mockFirestore.collections['activityGroups'];
    if (groupsMap == null) return [];
    return groupsMap.values
        .map((e) => ActivityGroupModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Stream<List<ActivityGroupModel>> watchActivityGroups() {
    Stream<List<ActivityGroupModel>> getStream() async* {
      yield await getAllActivityGroups();
      try {
        final Stream<void> changeStream = _mockFirestore.onChange;
        await for (final _ in changeStream) {
          yield await getAllActivityGroups();
        }
      } catch (_) {
        while (true) {
          await Future.delayed(const Duration(milliseconds: 100));
          yield await getAllActivityGroups();
        }
      }
    }

    return getStream();
  }

  @override
  Stream<ActivityGroupModel?> watchActivityGroup(String id) {
    Stream<ActivityGroupModel?> getStream() async* {
      yield await getActivityGroup(id);
      try {
        final Stream<void> changeStream = _mockFirestore.onChange;
        await for (final _ in changeStream) {
          yield await getActivityGroup(id);
        }
      } catch (_) {
        while (true) {
          await Future.delayed(const Duration(milliseconds: 100));
          yield await getActivityGroup(id);
        }
      }
    }

    return getStream();
  }

  // --- Activities ---
  Future<List<ActivityModel>> _rawGetAllActivities() async {
    final Map<String, dynamic>? activitiesMap =
        _mockFirestore.collections['activities'];
    if (activitiesMap == null) return [];
    return activitiesMap.values
        .map((e) => ActivityModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<ActivityModel?> getActivity(String id) async {
    final Map<String, dynamic>? activitiesMap =
        _mockFirestore.collections['activities'];
    if (activitiesMap == null) return null;
    final data = activitiesMap[id];
    if (data != null) {
      return ActivityModel.fromMap(Map<String, dynamic>.from(data));
    }
    return null;
  }

  @override
  Future<void> saveActivity(ActivityModel activity) async {
    _mockFirestore.setData('activities', activity.id, activity.toMap());

    // Propagate to activity group
    for (final entry in activity.statusMap.entries) {
      final orgId = entry.key;
      final status = entry.value;

      if (status == 'Active') {
        final group = await getActivityGroup(activity.activityGroupId);
        if (group != null && group.statusMap[orgId] != 'Active') {
          final updatedGroup = group.copyWith(
            statusMap: {...group.statusMap, orgId: 'Active'},
          );
          await saveActivityGroup(updatedGroup);
        }
      } else if (status == 'Inactive') {
        final group = await getActivityGroup(activity.activityGroupId);
        if (group != null && group.statusMap[orgId] == 'Active') {
          final allActs = await _rawGetAllActivities();
          final groupActs = allActs
              .where((a) => a.activityGroupId == group.id)
              .toList();
          final hasActive = groupActs.any((a) {
            if (a.id == activity.id) return false;
            return a.statusMap[orgId] == 'Active';
          });
          if (!hasActive) {
            final updatedGroup = group.copyWith(
              statusMap: {...group.statusMap, orgId: 'Inactive'},
            );
            await saveActivityGroup(updatedGroup);
          }
        }
      }
    }
  }

  @override
  Future<void> deleteActivity(String id, String deletingOrgUnitId) async {
    final activity = await getActivity(id);
    if (activity == null) return;

    if (activity.ownerOrgUnitId == deletingOrgUnitId) {
      final otherApplied = activity.appliedOrgUnitIds
          .where((orgId) => orgId != deletingOrgUnitId)
          .toList();
      if (otherApplied.isNotEmpty) {
        final nextOwner = otherApplied.first;
        final updated = activity.copyWith(
          ownerOrgUnitId: nextOwner,
          appliedOrgUnitIds: otherApplied.sublist(1),
          statusMap: Map<String, String>.from(activity.statusMap)
            ..remove(deletingOrgUnitId),
        );
        await saveActivity(updated);
      } else {
        _mockFirestore.deleteData('activities', id);
      }
    } else {
      final updated = activity.copyWith(
        appliedOrgUnitIds: activity.appliedOrgUnitIds
            .where((orgId) => orgId != deletingOrgUnitId)
            .toList(),
        statusMap: Map<String, String>.from(activity.statusMap)
          ..remove(deletingOrgUnitId),
      );
      await saveActivity(updated);
    }
  }

  @override
  Future<List<ActivityModel>> getAllActivities() async {
    return _rawGetAllActivities();
  }

  @override
  Stream<List<ActivityModel>> watchActivities() {
    Stream<List<ActivityModel>> getStream() async* {
      yield await getAllActivities();
      try {
        final Stream<void> changeStream = _mockFirestore.onChange;
        await for (final _ in changeStream) {
          yield await getAllActivities();
        }
      } catch (_) {
        while (true) {
          await Future.delayed(const Duration(milliseconds: 100));
          yield await getAllActivities();
        }
      }
    }

    return getStream();
  }

  @override
  Stream<ActivityModel?> watchActivity(String id) {
    Stream<ActivityModel?> getStream() async* {
      yield await getActivity(id);
      try {
        final Stream<void> changeStream = _mockFirestore.onChange;
        await for (final _ in changeStream) {
          yield await getActivity(id);
        }
      } catch (_) {
        while (true) {
          await Future.delayed(const Duration(milliseconds: 100));
          yield await getActivity(id);
        }
      }
    }

    return getStream();
  }

  @override
  Future<List<UserCapacityModel>> getUserCapacities(String userEmail) async {
    final Map<String, dynamic>? capacitiesMap =
        _mockFirestore.collections['userCapacities'];
    if (capacitiesMap == null) return [];
    final normalized = userEmail.trim().toLowerCase();
    final list = <UserCapacityModel>[];
    for (final data in capacitiesMap.values) {
      final capacity = UserCapacityModel.fromMap(
        Map<String, dynamic>.from(data),
      );
      if (capacity.userEmail.trim().toLowerCase() == normalized) {
        list.add(capacity);
      }
    }
    return list;
  }

  @override
  Future<void> saveUserCapacity(UserCapacityModel capacity) async {
    _mockFirestore.setData('userCapacities', capacity.id, capacity.toMap());
  }

  @override
  Future<void> deleteUserCapacity(String id) async {
    _mockFirestore.deleteData('userCapacities', id);
  }

  @override
  Stream<List<UserCapacityModel>> watchUserCapacities(String userEmail) {
    Stream<List<UserCapacityModel>> getStream() async* {
      yield await getUserCapacities(userEmail);
      try {
        final Stream<void> changeStream = _mockFirestore.onChange;
        await for (final _ in changeStream) {
          yield await getUserCapacities(userEmail);
        }
      } catch (_) {
        while (true) {
          await Future.delayed(const Duration(milliseconds: 100));
          yield await getUserCapacities(userEmail);
        }
      }
    }

    return getStream();
  }

  // Mock Planning Demands
  @override
  Future<void> savePlanningDemand(PlanningDemandModel demand) async {
    if (demand.sum <= 0.0) {
      await deletePlanningDemand(demand.id);
    } else {
      _mockFirestore.setData('planningDemands', demand.id, demand.toMap());
    }
  }

  @override
  Future<void> deletePlanningDemand(String id) async {
    _mockFirestore.deleteData('planningDemands', id);
  }

  @override
  Stream<List<PlanningDemandModel>> watchPlanningDemands(
    String orgUnitId,
    int year,
  ) {
    Stream<List<PlanningDemandModel>> getStream() async* {
      Future<List<PlanningDemandModel>> getList() async {
        final Map<String, dynamic>? demandsMap =
            _mockFirestore.collections['planningDemands'];
        if (demandsMap == null) return [];
        final list = <PlanningDemandModel>[];
        for (final data in demandsMap.values) {
          final demand = PlanningDemandModel.fromMap(
            Map<String, dynamic>.from(data),
          );
          if (demand.orgUnitId == orgUnitId && demand.year == year) {
            list.add(demand);
          }
        }
        return list;
      }

      yield await getList();
      try {
        final Stream<void> changeStream = _mockFirestore.onChange;
        await for (final _ in changeStream) {
          yield await getList();
        }
      } catch (_) {
        while (true) {
          await Future.delayed(const Duration(milliseconds: 100));
          yield await getList();
        }
      }
    }

    return getStream();
  }

  @override
  Stream<List<PlanningDemandModel>> watchAllPlanningDemands({List<int>? years}) {
    Stream<List<PlanningDemandModel>> getStream() async* {
      Future<List<PlanningDemandModel>> getList() async {
        final Map<String, dynamic>? demandsMap =
            _mockFirestore.collections['planningDemands'];
        if (demandsMap == null) return [];
        final list = demandsMap.values
            .map(
              (data) =>
                  PlanningDemandModel.fromMap(Map<String, dynamic>.from(data)),
            )
            .toList();
        if (years != null && years.isNotEmpty) {
          return list.where((d) => years.contains(d.year)).toList();
        }
        return list;
      }

      yield await getList();
      try {
        final Stream<void> changeStream = _mockFirestore.onChange;
        await for (final _ in changeStream) {
          yield await getList();
        }
      } catch (_) {
        while (true) {
          await Future.delayed(const Duration(milliseconds: 100));
          yield await getList();
        }
      }
    }

    return getStream();
  }

  // Mock Planning Allocations
  @override
  Future<void> savePlanningAllocation(
    PlanningAllocationModel allocation,
  ) async {
    if (allocation.sum <= 0.0) {
      await deletePlanningAllocation(allocation.id);
    } else {
      _mockFirestore.setData(
        'planningAllocations',
        allocation.id,
        allocation.toMap(),
      );
    }
  }

  @override
  Future<void> deletePlanningAllocation(String id) async {
    _mockFirestore.deleteData('planningAllocations', id);
  }

  @override
  Stream<List<PlanningAllocationModel>> watchPlanningAllocations(
    String orgUnitId,
    int year,
  ) {
    Stream<List<PlanningAllocationModel>> getStream() async* {
      Future<List<PlanningAllocationModel>> getList() async {
        final Map<String, dynamic>? allocationsMap =
            _mockFirestore.collections['planningAllocations'];
        if (allocationsMap == null) return [];
        final list = <PlanningAllocationModel>[];
        for (final data in allocationsMap.values) {
          final allocation = PlanningAllocationModel.fromMap(
            Map<String, dynamic>.from(data),
          );
          if (allocation.orgUnitId == orgUnitId && allocation.year == year) {
            list.add(allocation);
          }
        }
        return list;
      }

      yield await getList();
      try {
        final Stream<void> changeStream = _mockFirestore.onChange;
        await for (final _ in changeStream) {
          yield await getList();
        }
      } catch (_) {
        while (true) {
          await Future.delayed(const Duration(milliseconds: 100));
          yield await getList();
        }
      }
    }

    return getStream();
  }

  @override
  Stream<List<PlanningAllocationModel>> watchAllPlanningAllocations({List<int>? years}) {
    Stream<List<PlanningAllocationModel>> getStream() async* {
      Future<List<PlanningAllocationModel>> getList() async {
        final Map<String, dynamic>? allocationsMap =
            _mockFirestore.collections['planningAllocations'];
        if (allocationsMap == null) return [];
        final list = allocationsMap.values
            .map(
              (data) => PlanningAllocationModel.fromMap(
                Map<String, dynamic>.from(data),
              ),
            )
            .toList();
        if (years != null && years.isNotEmpty) {
          return list.where((a) => years.contains(a.year)).toList();
        }
        return list;
      }

      yield await getList();
      try {
        final Stream<void> changeStream = _mockFirestore.onChange;
        await for (final _ in changeStream) {
          yield await getList();
        }
      } catch (_) {
        while (true) {
          await Future.delayed(const Duration(milliseconds: 100));
          yield await getList();
        }
      }
    }

    return getStream();
  }

  // Locks
  @override
  Future<bool> acquireLock(LockModel lock) async {
    // Clean up expired locks in this org unit/year to avoid pollution
    final Map<String, dynamic>? locksMap = _mockFirestore.collections['locks'];
    if (locksMap != null) {
      final expiredIds = <String>[];
      for (final entry in locksMap.entries) {
        final l = LockModel.fromMap(Map<String, dynamic>.from(entry.value));
        if (l.orgUnitId == lock.orgUnitId && l.year == lock.year && l.isExpired) {
          expiredIds.add(entry.key);
        }
      }
      for (final id in expiredIds) {
        _mockFirestore.deleteData('locks', id);
      }
    }

    // Now re-fetch active locks
    final activeLocks = <LockModel>[];
    if (locksMap != null) {
      for (final data in locksMap.values) {
        final l = LockModel.fromMap(Map<String, dynamic>.from(data));
        if (l.orgUnitId == lock.orgUnitId && l.year == lock.year && !l.isExpired) {
          activeLocks.add(l);
        }
      }
    }

    // Check conflict
    for (final other in activeLocks) {
      if (other.userId == lock.userId) {
        continue; // Our own lock, we can overwrite/refresh it
      }

      if (lock.lockType == 'activity') {
        if (other.lockType == 'activity' &&
            other.activityId == lock.activityId) {
          return false;
        }
        if (other.lockType == 'employee' &&
            other.activityIds.contains(lock.activityId)) {
          return false;
        }
      } else if (lock.lockType == 'employee') {
        if (other.lockType == 'employee') {
          final commonEmployees = other.employeeEmails.toSet().intersection(
            lock.employeeEmails.toSet(),
          );
          final commonActivities = other.activityIds.toSet().intersection(
            lock.activityIds.toSet(),
          );
          if (commonEmployees.isNotEmpty && commonActivities.isNotEmpty) {
            return false;
          }
        }
      }
    }

    // Set lock
    _mockFirestore.setData('locks', lock.id, lock.toMap());
    return true;
  }

  @override
  Future<void> releaseLock(String lockId) async {
    _mockFirestore.deleteData('locks', lockId);
  }

  @override
  Stream<List<LockModel>> watchLocks(String orgUnitId, int year) {
    Stream<List<LockModel>> getStream() async* {
      Future<List<LockModel>> getList() async {
        final Map<String, dynamic>? locksMap =
            _mockFirestore.collections['locks'];
        if (locksMap == null) return [];
        final list = <LockModel>[];
        for (final data in locksMap.values) {
          final l = LockModel.fromMap(Map<String, dynamic>.from(data));
          if (l.orgUnitId == orgUnitId && l.year == year) {
            list.add(l);
          }
        }
        return list;
      }

      yield await getList();
      try {
        final Stream<void> changeStream = _mockFirestore.onChange;
        await for (final _ in changeStream) {
          yield await getList();
        }
      } catch (_) {
        while (true) {
          await Future.delayed(const Duration(milliseconds: 100));
          yield await getList();
        }
      }
    }

    return getStream();
  }

  @override
  Future<List<LockModel>> getLocks(String orgUnitId, int year) async {
    final Map<String, dynamic>? locksMap = _mockFirestore.collections['locks'];
    if (locksMap == null) return [];
    final list = <LockModel>[];
    for (final data in locksMap.values) {
      final l = LockModel.fromMap(Map<String, dynamic>.from(data));
      if (l.orgUnitId == orgUnitId && l.year == year) {
        list.add(l);
      }
    }
    return list;
  }
}
