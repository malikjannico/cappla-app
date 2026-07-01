import 'dart:async';
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
import '../../core/utils/org_unit_validator.dart';
import 'database_service.dart';

class FirestoreDatabaseService implements DatabaseService {
  final FirebaseFirestore _firestore;

  FirestoreDatabaseService(this._firestore);

  @override
  Future<UserModel?> getUser(String email) async {
    final doc = await _firestore
        .collection('users')
        .doc(email.trim().toLowerCase())
        .get();
    if (doc.exists && doc.data() != null && doc.data()!.isNotEmpty) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Future<UserModel?> getUserById(String id) async {
    final query = await _firestore
        .collection('users')
        .where('id', isEqualTo: id)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty && query.docs.first.data().isNotEmpty) {
      return UserModel.fromMap(query.docs.first.data());
    }
    return null;
  }

  @override
  Future<void> saveUser(UserModel user) async {
    final lowerEmail = user.email.trim().toLowerCase();
    await _firestore.collection('users').doc(lowerEmail).set(user.toMap());

    // Auto-create standard capacity row if not present
    final capacityDocId = 'standard_$lowerEmail';
    final capDoc = await _firestore
        .collection('userCapacities')
        .doc(capacityDocId)
        .get();
    if (!capDoc.exists) {
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
      await _firestore
          .collection('users')
          .doc(user.email.trim().toLowerCase())
          .delete();
    }
  }

  @override
  Stream<UserModel?> watchUser(String id) {
    return _firestore
        .collection('users')
        .where('id', isEqualTo: id)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty && snapshot.docs.first.data().isNotEmpty) {
            return UserModel.fromMap(snapshot.docs.first.data());
          }
          return null;
        });
  }

  @override
  Stream<UserModel?> watchUserByEmail(String email) {
    return _firestore
        .collection('users')
        .doc(email.trim().toLowerCase())
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null && doc.data()!.isNotEmpty) {
            return UserModel.fromMap(doc.data()!);
          }
          return null;
        });
  }

  @override
  Stream<List<UserModel>> watchUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
    });
  }

  @override
  Future<List<UserModel>> getAllUsers() async {
    final query = await _firestore.collection('users').get();
    return query.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
  }

  @override
  Future<OrgUnitModel?> getOrgUnit(String id) async {
    final doc = await _firestore.collection('orgUnits').doc(id).get();
    if (doc.exists && doc.data() != null) {
      return OrgUnitModel.fromMap(doc.data()!);
    }
    return null;
  }


  @override
  Stream<OrgUnitModel?> watchOrgUnit(String id) {
    return _firestore.collection('orgUnits').doc(id).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return OrgUnitModel.fromMap(doc.data()!);
      }
      return null;
    });
  }

  @override
  Stream<List<OrgUnitModel>> watchOrgUnits() {
    return _firestore.collection('orgUnits').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => OrgUnitModel.fromMap(doc.data()))
          .toList();
    });
  }

  @override
  Future<void> saveOrgUnit(OrgUnitModel orgUnit) async {
    await _firestore.runTransaction((transaction) async {
      Future<OrgUnitModel?> txGetOrgUnit(String id) async {
        final doc = await transaction.get(_firestore.collection('orgUnits').doc(id));
        if (doc.exists && doc.data() != null) {
          return OrgUnitModel.fromMap(doc.data()!);
        }
        return null;
      }

      await OrgUnitValidator.validate(
        orgUnit: orgUnit,
        getOrgUnit: txGetOrgUnit,
      );

      final oldOrgUnit = await txGetOrgUnit(orgUnit.id);
      final Map<String, OrgUnitModel> updates = {};
      updates[orgUnit.id] = orgUnit;

      // Dissolving relation & Syncing
      if (oldOrgUnit == null) {
        // New Org Unit
        if (orgUnit.parentId != null) {
          final parent = await txGetOrgUnit(orgUnit.parentId!);
          if (parent != null) {
            if (!parent.childIds.contains(orgUnit.id)) {
              updates[parent.id] = parent.copyWith(
                childIds: [...parent.childIds, orgUnit.id],
              );
            }
          }
        }
        if (orgUnit.childIds.isNotEmpty) {
          for (final cId in orgUnit.childIds) {
            final child = await txGetOrgUnit(cId);
            if (child != null) {
              if (child.parentId != null && child.parentId != orgUnit.id) {
                final oldParent = await txGetOrgUnit(child.parentId!);
                if (oldParent != null) {
                  updates[oldParent.id] = oldParent.copyWith(
                    childIds: oldParent.childIds.where((id) => id != cId).toList(),
                  );
                }
              }
              updates[child.id] = child.copyWith(parentId: () => orgUnit.id);
            }
          }
        }
      } else {
        // Existing Org Unit
        // If parentId changes
        if (oldOrgUnit.parentId != orgUnit.parentId) {
          if (oldOrgUnit.parentId != null) {
            final oldParent = await txGetOrgUnit(oldOrgUnit.parentId!);
            if (oldParent != null) {
              updates[oldParent.id] = oldParent.copyWith(
                childIds: oldParent.childIds.where((id) => id != orgUnit.id).toList(),
              );
            }
          }
          if (orgUnit.parentId != null) {
            final newParent = await txGetOrgUnit(orgUnit.parentId!);
            if (newParent != null) {
              if (!newParent.childIds.contains(orgUnit.id)) {
                updates[newParent.id] = newParent.copyWith(
                  childIds: [...newParent.childIds, orgUnit.id],
                );
              }
            }
          }
        }
        // If children list changes
        final oldChildren = oldOrgUnit.childIds;
        final newChildren = orgUnit.childIds;
        final removedChildren = oldChildren.where((id) => !newChildren.contains(id)).toList();
        final addedChildren = newChildren.where((id) => !oldChildren.contains(id)).toList();

        for (final cId in removedChildren) {
          final child = await txGetOrgUnit(cId);
          if (child != null && child.parentId == orgUnit.id) {
            updates[child.id] = child.copyWith(parentId: () => null);
          }
        }
        for (final cId in addedChildren) {
          final child = await txGetOrgUnit(cId);
          if (child != null) {
            if (child.parentId != null && child.parentId != orgUnit.id) {
              final oldParent = await txGetOrgUnit(child.parentId!);
              if (oldParent != null) {
                updates[oldParent.id] = oldParent.copyWith(
                  childIds: oldParent.childIds.where((id) => id != cId).toList(),
                );
              }
            }
            updates[child.id] = child.copyWith(parentId: () => orgUnit.id);
          }
        }
      }

      // Active status propagation
      if (orgUnit.status == 'Inactive') {
        Future<void> propagateInactiveStatusTx(
          List<String> childIds,
          Set<String> visited,
        ) async {
          for (final childId in childIds) {
            if (visited.contains(childId)) continue;
            visited.add(childId);
            final child = updates[childId] ?? await txGetOrgUnit(childId);
            if (child != null) {
              if (child.status != 'Inactive') {
                final updatedChild = child.copyWith(status: 'Inactive');
                updates[childId] = updatedChild;
                await propagateInactiveStatusTx(updatedChild.childIds, visited);
              }
            }
          }
        }
        await propagateInactiveStatusTx(orgUnit.childIds, {orgUnit.id});
      }

      // Commit all org unit updates
      for (final entry in updates.entries) {
        transaction.set(
          _firestore.collection('orgUnits').doc(entry.key),
          entry.value.toMap(),
        );
      }
    });
  }

  @override
  Future<void> deleteOrgUnit(String id) async {
    final allUsers = await getAllUsers();
    final usersToClear = allUsers.where((u) => u.orgUnitId == id).toList();

    await _firestore.runTransaction((transaction) async {
      Future<OrgUnitModel?> txGetOrgUnit(String id) async {
        final doc = await transaction.get(_firestore.collection('orgUnits').doc(id));
        if (doc.exists && doc.data() != null) {
          return OrgUnitModel.fromMap(doc.data()!);
        }
        return null;
      }

      final unit = await txGetOrgUnit(id);
      if (unit != null) {
        final Map<String, OrgUnitModel> updates = {};

        // Remove id from parent's childIds
        if (unit.parentId != null) {
          final parent = await txGetOrgUnit(unit.parentId!);
          if (parent != null) {
            updates[parent.id] = parent.copyWith(
              childIds: parent.childIds.where((cId) => cId != id).toList(),
            );
          }
        }

        // Clear parentId on all children
        for (final cId in unit.childIds) {
          final child = await txGetOrgUnit(cId);
          if (child != null) {
            updates[child.id] = child.copyWith(parentId: () => null);
          }
        }

        // Commit all org unit updates
        for (final entry in updates.entries) {
          transaction.set(
            _firestore.collection('orgUnits').doc(entry.key),
            entry.value.toMap(),
          );
        }

        // Clear orgUnitId on all associated users
        for (final user in usersToClear) {
          transaction.set(
            _firestore.collection('users').doc(user.id),
            user.copyWith(orgUnitId: () => null).toMap(),
          );
        }

        // Finally delete the org unit
        transaction.delete(_firestore.collection('orgUnits').doc(id));
      }
    });
  }

  @override
  Future<List<OrgUnitModel>> getAllOrgUnits() async {
    final query = await _firestore.collection('orgUnits').get();
    return query.docs.map((doc) => OrgUnitModel.fromMap(doc.data())).toList();
  }

  @override
  Future<void> seedUsers() async {
    // Seeding is disabled here to prevent cleartext credentials inside the compiled frontend.
    // Use external node scripts (provision_admin.js) instead.
    return;
  }

  // --- Categories ---
  @override
  Future<CategoryModel?> getCategory(String id) async {
    final doc = await _firestore.collection('categories').doc(id).get();
    if (doc.exists && doc.data() != null) {
      return CategoryModel.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Future<void> saveCategory(CategoryModel category) async {
    await _firestore
        .collection('categories')
        .doc(category.id)
        .set(category.toMap());
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
        await _firestore.collection('categories').doc(id).delete();
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
    final query = await _firestore.collection('categories').get();
    return query.docs.map((doc) => CategoryModel.fromMap(doc.data())).toList();
  }

  @override
  Stream<List<CategoryModel>> watchCategories() {
    return _firestore.collection('categories').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CategoryModel.fromMap(doc.data()))
          .toList();
    });
  }

  @override
  Stream<CategoryModel?> watchCategory(String id) {
    return _firestore.collection('categories').doc(id).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return CategoryModel.fromMap(snap.data()!);
    });
  }

  // --- Activity Groups ---
  @override
  Future<ActivityGroupModel?> getActivityGroup(String id) async {
    final doc = await _firestore.collection('activityGroups').doc(id).get();
    if (doc.exists && doc.data() != null) {
      return ActivityGroupModel.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Future<void> saveActivityGroup(ActivityGroupModel activityGroup) async {
    final oldGroup = await getActivityGroup(activityGroup.id);
    await _firestore
        .collection('activityGroups')
        .doc(activityGroup.id)
        .set(activityGroup.toMap());

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
        await _firestore.collection('activityGroups').doc(id).delete();
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
    final query = await _firestore.collection('activityGroups').get();
    return query.docs
        .map((doc) => ActivityGroupModel.fromMap(doc.data()))
        .toList();
  }

  @override
  Stream<List<ActivityGroupModel>> watchActivityGroups() {
    return _firestore.collection('activityGroups').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ActivityGroupModel.fromMap(doc.data()))
          .toList();
    });
  }

  @override
  Stream<ActivityGroupModel?> watchActivityGroup(String id) {
    return _firestore.collection('activityGroups').doc(id).snapshots().map((
      snap,
    ) {
      if (!snap.exists || snap.data() == null) return null;
      return ActivityGroupModel.fromMap(snap.data()!);
    });
  }

  // --- Activities ---
  Future<List<ActivityModel>> _rawGetAllActivities() async {
    final query = await _firestore.collection('activities').get();
    return query.docs.map((doc) => ActivityModel.fromMap(doc.data())).toList();
  }

  @override
  Future<ActivityModel?> getActivity(String id) async {
    final doc = await _firestore.collection('activities').doc(id).get();
    if (doc.exists && doc.data() != null) {
      return ActivityModel.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Future<void> saveActivity(ActivityModel activity) async {
    await _firestore
        .collection('activities')
        .doc(activity.id)
        .set(activity.toMap());

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
        await _firestore.collection('activities').doc(id).delete();
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
    return _firestore.collection('activities').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ActivityModel.fromMap(doc.data()))
          .toList();
    });
  }

  @override
  Stream<ActivityModel?> watchActivity(String id) {
    return _firestore.collection('activities').doc(id).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return ActivityModel.fromMap(snap.data()!);
    });
  }

  @override
  Future<List<UserCapacityModel>> getUserCapacities(String userEmail) async {
    final query = await _firestore
        .collection('userCapacities')
        .where('userEmail', isEqualTo: userEmail.trim().toLowerCase())
        .get();
    return query.docs
        .map((doc) => UserCapacityModel.fromMap(doc.data()))
        .toList();
  }

  @override
  Future<void> saveUserCapacity(UserCapacityModel capacity) async {
    await _firestore
        .collection('userCapacities')
        .doc(capacity.id)
        .set(capacity.toMap());
  }

  @override
  Future<void> deleteUserCapacity(String id) async {
    await _firestore.collection('userCapacities').doc(id).delete();
  }

  @override
  Stream<List<UserCapacityModel>> watchUserCapacities(String userEmail) {
    return _firestore
        .collection('userCapacities')
        .where('userEmail', isEqualTo: userEmail.trim().toLowerCase())
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserCapacityModel.fromMap(doc.data()))
              .toList();
        });
  }

  // Planning Demands
  @override
  Future<void> savePlanningDemand(PlanningDemandModel demand) async {
    if (demand.sum <= 0.0) {
      await deletePlanningDemand(demand.id);
    } else {
      await _firestore
          .collection('planningDemands')
          .doc(demand.id)
          .set(demand.toMap());
    }
  }

  @override
  Future<void> deletePlanningDemand(String id) async {
    await _firestore.collection('planningDemands').doc(id).delete();
  }

  @override
  Stream<List<PlanningDemandModel>> watchPlanningDemands(
    String orgUnitId,
    int year,
  ) {
    return _firestore
        .collection('planningDemands')
        .where('orgUnitId', isEqualTo: orgUnitId)
        .where('year', isEqualTo: year)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PlanningDemandModel.fromMap(doc.data()))
              .toList();
        });
  }

  @override
  Stream<List<PlanningDemandModel>> watchAllPlanningDemands({List<int>? years}) {
    Query query = _firestore.collection('planningDemands');
    if (years != null && years.isNotEmpty) {
      query = query.where('year', whereIn: years);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => PlanningDemandModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  // Planning Allocations
  @override
  Future<void> savePlanningAllocation(
    PlanningAllocationModel allocation,
  ) async {
    if (allocation.sum <= 0.0) {
      await deletePlanningAllocation(allocation.id);
    } else {
      await _firestore
          .collection('planningAllocations')
          .doc(allocation.id)
          .set(allocation.toMap());
    }
  }

  @override
  Future<void> deletePlanningAllocation(String id) async {
    await _firestore.collection('planningAllocations').doc(id).delete();
  }

  @override
  Stream<List<PlanningAllocationModel>> watchPlanningAllocations(
    String orgUnitId,
    int year,
  ) {
    return _firestore
        .collection('planningAllocations')
        .where('orgUnitId', isEqualTo: orgUnitId)
        .where('year', isEqualTo: year)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PlanningAllocationModel.fromMap(doc.data()))
              .toList();
        });
  }

  @override
  Stream<List<PlanningAllocationModel>> watchAllPlanningAllocations({List<int>? years}) {
    Query query = _firestore.collection('planningAllocations');
    if (years != null && years.isNotEmpty) {
      query = query.where('year', whereIn: years);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => PlanningAllocationModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  // Locks
  @override
  Future<bool> acquireLock(LockModel lock) async {
    final docRef = _firestore.collection('locks').doc(lock.id);

    // Clean up expired locks in this org unit/year to avoid pollution
    final querySnapshot = await _firestore
        .collection('locks')
        .where('orgUnitId', isEqualTo: lock.orgUnitId)
        .where('year', isEqualTo: lock.year)
        .get();

    final now = DateTime.now();
    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final expiresAtStr = data['expiresAt'] as String?;
      if (expiresAtStr != null) {
        final expiresAt = DateTime.parse(expiresAtStr);
        if (now.isAfter(expiresAt)) {
          await doc.reference.delete();
        }
      }
    }

    // Now re-fetch active locks
    final activeDocs = await _firestore
        .collection('locks')
        .where('orgUnitId', isEqualTo: lock.orgUnitId)
        .where('year', isEqualTo: lock.year)
        .get();

    final activeLocks = activeDocs.docs
        .map((doc) => LockModel.fromMap(doc.data()))
        .where((l) => !l.isExpired)
        .toList();

    // Check conflict
    for (final other in activeLocks) {
      if (other.userId == lock.userId) {
        continue; // Our own lock, we can overwrite/refresh it
      }

      if (lock.lockType == 'activity') {
        // We are trying to edit activity X.
        // Conflicts if:
        // 1. Someone else locked activity X directly:
        if (other.lockType == 'activity' &&
            other.activityId == lock.activityId) {
          return false;
        }
        // 2. Someone else locked employee planning which contains activity X:
        if (other.lockType == 'employee' &&
            other.activityIds.contains(lock.activityId)) {
          return false;
        }
      } else if (lock.lockType == 'employee') {
        // We are trying to edit employee-planning for employeeEmails and activityIds.
        // Conflicts if:
        // 1. Someone else locked employee planning that overlaps in BOTH employee emails AND activity IDs:
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

    // No conflict, write our lock!
    await docRef.set(lock.toMap());
    return true;
  }

  @override
  Future<void> releaseLock(String lockId) async {
    await _firestore.collection('locks').doc(lockId).delete();
  }

  @override
  Stream<List<LockModel>> watchLocks(String orgUnitId, int year) {
    return _firestore
        .collection('locks')
        .where('orgUnitId', isEqualTo: orgUnitId)
        .where('year', isEqualTo: year)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => LockModel.fromMap(doc.data()))
              .toList();
        });
  }

  @override
  Future<List<LockModel>> getLocks(String orgUnitId, int year) async {
    final snapshot = await _firestore
        .collection('locks')
        .where('orgUnitId', isEqualTo: orgUnitId)
        .where('year', isEqualTo: year)
        .get();
    return snapshot.docs.map((doc) => LockModel.fromMap(doc.data())).toList();
  }
}
