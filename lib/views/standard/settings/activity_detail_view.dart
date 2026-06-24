import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/router_paths.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../models/org_unit_model.dart';
import '../../../models/user_model.dart';
import 'categories_list_view.dart' show ShareWizardModal;
import 'category_create_view.dart' show BreadcrumbLink;
import 'change_ownership_dialog.dart';

final activityStreamProvider = StreamProvider.autoDispose
    .family<ActivityModel?, String>((ref, id) {
      return ref.watch(databaseServiceProvider).watchActivity(id);
    });

final _usersStreamProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  return ref.watch(databaseServiceProvider).watchUsers();
});

class ActivityDetailView extends ConsumerStatefulWidget {
  final String activityGroupId;
  final String activityId;
  const ActivityDetailView({
    super.key,
    required this.activityGroupId,
    required this.activityId,
  });

  @override
  ConsumerState<ActivityDetailView> createState() => _ActivityDetailViewState();
}

class _ActivityDetailViewState extends ConsumerState<ActivityDetailView> {
  final _employeeSearchController = TextEditingController();
  String _employeeQuery = '';
  int _employeePage = 1;
  String? _employeeStatusFilter;
  String? _employeeRoleFilter;

  @override
  void dispose() {
    _employeeSearchController.dispose();
    super.dispose();
  }

  void _showAssignEmployeeModal(
    List<UserModel> allUsers,
    ActivityModel activity,
  ) {
    final myOrg = ref.read(userOwnedOrgUnitProvider);
    if (myOrg == null) return;

    final assignableUsers = allUsers.where((u) {
      return u.orgUnitId == myOrg.id &&
          !activity.assignedUserEmails.contains(u.email);
    }).toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        String query = '';
        final localSelectedEmails = <String>{};

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredUsers = assignableUsers.where((u) {
              final q = query.trim().toLowerCase();
              if (q.isEmpty) return true;
              return u.fullName.toLowerCase().contains(q) ||
                  u.email.toLowerCase().contains(q);
            }).toList();

            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: const Text('Assign Employees to Activity'),
              content: SizedBox(
                width: 400,
                height: 450,
                child: Column(
                  children: [
                    TextField(
                      key: const Key('employee_assign_modal_search_input'),
                      decoration: InputDecoration(
                        labelText: 'Search Employees',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          query = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filteredUsers.isEmpty
                          ? const Center(
                              child: Text('No assignable employees found.'),
                            )
                          : ListView.builder(
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, idx) {
                                final u = filteredUsers[idx];
                                final isSelected = localSelectedEmails.contains(
                                  u.email,
                                );
                                return CheckboxListTile(
                                  key: Key(
                                    'employee_assign_modal_row_${u.email}',
                                  ),
                                  title: Text(u.fullName),
                                  subtitle: Text(u.email),
                                  value: isSelected,
                                  activeColor: theme.colorScheme.primary,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        localSelectedEmails.add(u.email);
                                      } else {
                                        localSelectedEmails.remove(u.email);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  key: const Key('employee_assign_modal_cancel_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('employee_assign_modal_save_button'),
                  onPressed: localSelectedEmails.isEmpty
                      ? null
                      : () async {
                          try {
                            final updatedEmails = [
                              ...activity.assignedUserEmails,
                              ...localSelectedEmails,
                            ];
                            final updatedActivity = activity.copyWith(
                              assignedUserEmails: updatedEmails,
                              lastModifiedBy:
                                  ref.read(currentUserProvider)?.email ??
                                  'system',
                              lastModifiedAt: DateTime.now(),
                            );
                            await ref
                                .read(databaseServiceProvider)
                                .saveActivity(updatedActivity);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                            setState(() {});
                          } catch (e) {
                            // handle error
                          }
                        },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final myOrg = ref.watch(userOwnedOrgUnitProvider);

    if (myOrg == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Only heads of organization units can view activity details.',
          ),
        ),
      );
    }

    final activityAsync = ref.watch(activityStreamProvider(widget.activityId));
    final activity = activityAsync.value;

    final usersAsync = ref.watch(_usersStreamProvider);
    final allUsers = usersAsync.value ?? <UserModel>[];

    if (activity == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFFFFF),
        body: Center(child: Text('Loading Activity or Activity Not Found')),
      );
    }

    final actStatus = activity.statusMap[myOrg.id] ?? 'Active';
    final isOwner = activity.ownerOrgUnitId == myOrg.id;

    // Load category and group info
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final allCategories = categoriesAsync.value ?? [];
    final category = allCategories.cast<CategoryModel?>().firstWhere(
      (c) => c?.id == activity.categoryId,
      orElse: () => null,
    );

    final groupsAsync = ref.watch(activityGroupsStreamProvider);
    final allGroups = groupsAsync.value ?? [];
    final group = allGroups.cast<ActivityGroupModel?>().firstWhere(
      (g) => g?.id == activity.activityGroupId,
      orElse: () => null,
    );

    final validityStr = activity.type == 'Limited'
        ? '${activity.validityStart?.toLocal().toString().split(' ')[0]} to ${activity.validityEnd?.toLocal().toString().split(' ')[0]}'
        : '-';

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Align(
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumbs
              Row(
                children: [
                  BreadcrumbLink(
                    label: 'Activity Groups',
                    linkKey: const Key('activity_detail_back_button'),
                    onTap: () => context.go(RouterPaths.settingsActivityGroups),
                  ),
                  if (group != null) ...[
                    Text(
                      ' / ',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    BreadcrumbLink(
                      label: group.name,
                      linkKey: const Key('activity_detail_group_breadcrumb'),
                      onTap: () => context.go(
                        RouterPaths.settingsActivityGroupsDetailPath(
                          widget.activityGroupId,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    ' / ${activity.name}',
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Header Row (Title and Actions)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      activity.name,
                      key: const Key('activity_detail_title'),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isOwner) ...[
                        FilledButton(
                          key: const Key('activity_detail_edit_button'),
                          onPressed: () {
                            context.go(
                              RouterPaths.settingsActivitiesEditPath(
                                widget.activityGroupId,
                                activity.id,
                              ),
                            );
                          },
                          child: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: MenuAnchor(
                          key: const Key('activity_detail_overflow_button'),
                          builder: (context, controller, child) {
                            return IconButton(
                              icon: const Icon(Icons.more_vert),
                              tooltip: 'Show menu',
                              onPressed: () {
                                if (controller.isOpen) {
                                  controller.close();
                                } else {
                                  controller.open();
                                }
                              },
                            );
                          },
                          menuChildren: [
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: MenuItemButton(
                                key: const Key(
                                  'activity_detail_toggle_status_item',
                                ),
                                onPressed: () async {
                                  const val = 'toggle';
                                  if (val == 'toggle') {
                                    if (actStatus == 'Inactive') {
                                      // If it is Limited and expired, require a new date range
                                      final isExpired =
                                          activity.type == 'Limited' &&
                                          activity.validityEnd != null &&
                                          activity.validityEnd!.isBefore(
                                            DateTime.now(),
                                          );

                                      if (isExpired) {
                                        _showReactivateModal(activity);
                                        return;
                                      }
                                    }
                                    final newStatus = actStatus == 'Active'
                                        ? 'Inactive'
                                        : 'Active';
                                    final newStatusMap =
                                        Map<String, String>.from(
                                          activity.statusMap,
                                        )..[myOrg.id] = newStatus;
                                    await ref
                                        .read(databaseServiceProvider)
                                        .saveActivity(
                                          activity.copyWith(
                                            statusMap: newStatusMap,
                                            lastModifiedBy:
                                                user?.email ?? 'system',
                                            lastModifiedAt: DateTime.now(),
                                          ),
                                        );
                                  } else if (val == 'share') {
                                    _showShareModal(activity);
                                  } else if (val == 'delete') {
                                    try {
                                      await ref
                                          .read(databaseServiceProvider)
                                          .deleteActivity(
                                            activity.id,
                                            myOrg.id,
                                          );
                                      if (context.mounted) {
                                        context.go(
                                          RouterPaths.settingsActivityGroupsDetailPath(
                                            widget.activityGroupId,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              e.toString().replaceAll(
                                                'Exception: ',
                                                '',
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                child: Text(
                                  actStatus == 'Active'
                                      ? 'Deactivate'
                                      : 'Activate',
                                ),
                              ),
                            ),
                            if (isOwner)
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: MenuItemButton(
                                  key: Key('activity_detail_share_item'),
                                  onPressed: () async {
                                    const val = 'share';
                                    if (val == 'toggle') {
                                      if (actStatus == 'Inactive') {
                                        // If it is Limited and expired, require a new date range
                                        final isExpired =
                                            activity.type == 'Limited' &&
                                            activity.validityEnd != null &&
                                            activity.validityEnd!.isBefore(
                                              DateTime.now(),
                                            );

                                        if (isExpired) {
                                          _showReactivateModal(activity);
                                          return;
                                        }
                                      }
                                      final newStatus = actStatus == 'Active'
                                          ? 'Inactive'
                                          : 'Active';
                                      final newStatusMap =
                                          Map<String, String>.from(
                                            activity.statusMap,
                                          )..[myOrg.id] = newStatus;
                                      await ref
                                          .read(databaseServiceProvider)
                                          .saveActivity(
                                            activity.copyWith(
                                              statusMap: newStatusMap,
                                              lastModifiedBy:
                                                  user?.email ?? 'system',
                                              lastModifiedAt: DateTime.now(),
                                            ),
                                          );
                                    } else if (val == 'share') {
                                      _showShareModal(activity);
                                    } else if (val == 'delete') {
                                      try {
                                        await ref
                                            .read(databaseServiceProvider)
                                            .deleteActivity(
                                              activity.id,
                                              myOrg.id,
                                            );
                                        if (context.mounted) {
                                          context.go(
                                            RouterPaths.settingsActivityGroupsDetailPath(
                                              widget.activityGroupId,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e.toString().replaceAll(
                                                  'Exception: ',
                                                  '',
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  child: Text('Share'),
                                ),
                              ),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: MenuItemButton(
                                key: const Key('activity_detail_delete_item'),
                                onPressed: () async {
                                  const val = 'delete';
                                  if (val == 'toggle') {
                                    if (actStatus == 'Inactive') {
                                      // If it is Limited and expired, require a new date range
                                      final isExpired =
                                          activity.type == 'Limited' &&
                                          activity.validityEnd != null &&
                                          activity.validityEnd!.isBefore(
                                            DateTime.now(),
                                          );

                                      if (isExpired) {
                                        _showReactivateModal(activity);
                                        return;
                                      }
                                    }
                                    final newStatus = actStatus == 'Active'
                                        ? 'Inactive'
                                        : 'Active';
                                    final newStatusMap =
                                        Map<String, String>.from(
                                          activity.statusMap,
                                        )..[myOrg.id] = newStatus;
                                    await ref
                                        .read(databaseServiceProvider)
                                        .saveActivity(
                                          activity.copyWith(
                                            statusMap: newStatusMap,
                                            lastModifiedBy:
                                                user?.email ?? 'system',
                                            lastModifiedAt: DateTime.now(),
                                          ),
                                        );
                                  } else if (val == 'share') {
                                    _showShareModal(activity);
                                  } else if (val == 'delete') {
                                    try {
                                      await ref
                                          .read(databaseServiceProvider)
                                          .deleteActivity(
                                            activity.id,
                                            myOrg.id,
                                          );
                                      if (context.mounted) {
                                        context.go(
                                          RouterPaths.settingsActivityGroupsDetailPath(
                                            widget.activityGroupId,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              e.toString().replaceAll(
                                                'Exception: ',
                                                '',
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                child: Text(isOwner ? 'Delete' : 'Remove'),
                              ),
                            ),
                            if (isOwner &&
                                myOrg.headOfEmail.trim().toLowerCase() ==
                                    user?.email.trim().toLowerCase())
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: MenuItemButton(
                                  key: const Key(
                                    'activity_detail_change_ownership_item',
                                  ),
                                  onPressed: () {
                                    _showChangeOwnershipModal(
                                      context: context,
                                      currentOwnerId: activity.ownerOrgUnitId,
                                      resourceName: activity.name,
                                      onConfirm: (targetOrg) async {
                                        final updatedAct = activity.copyWith(
                                          ownerOrgUnitId: targetOrg.id,
                                          sharedOrgUnitIds: <String>{
                                            ...activity.sharedOrgUnitIds,
                                            myOrg.id,
                                          }.toList(),
                                          appliedOrgUnitIds: <String>{
                                            ...activity.appliedOrgUnitIds,
                                            myOrg.id,
                                            targetOrg.id,
                                          }.toList(),
                                          statusMap: Map<String, String>.from(
                                            activity.statusMap,
                                          )..[targetOrg.id] = 'Active',
                                          lastModifiedBy:
                                              user?.email ?? 'system',
                                          lastModifiedAt: DateTime.now(),
                                        );
                                        await ref
                                            .read(databaseServiceProvider)
                                            .saveActivity(updatedAct);
                                      },
                                    );
                                  },
                                  child: const Text('Change Ownership'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 400,
                child: AbsorbPointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildStatusChip(
                            actStatus,
                            theme,
                            context,
                            key: const Key('activity_detail_status_label'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('activity_detail_name'),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(text: activity.name),
                        decoration: const InputDecoration(
                          labelText: 'Activity Name',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('activity_detail_group'),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(
                          text: group?.name ?? '',
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Activity Group',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('activity_detail_category'),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(
                          text: category?.name ?? '',
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('activity_detail_type'),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(text: activity.type),
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (activity.type == 'Limited') ...[
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('activity_detail_validity'),
                          readOnly: true,
                          focusNode: FocusNode(
                            canRequestFocus: false,
                            skipTraversal: true,
                          ),
                          controller: TextEditingController(text: validityStr),
                          decoration: const InputDecoration(
                            labelText: 'Validity',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('activity_detail_created_by'),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(
                          text: activity.createdBy,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Created By',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('activity_detail_created_at'),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(
                          text: activity.createdAt.toLocal().toString().split(
                            '.',
                          )[0],
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Created At',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('activity_detail_last_modified_by'),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(
                          text: activity.lastModifiedBy,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Last Modified By',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('activity_detail_last_modified_at'),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(
                          text: activity.lastModifiedAt
                              .toLocal()
                              .toString()
                              .split('.')[0],
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Last Modified At',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Employees Section
              Text(
                'Employees',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Search & Add Employee Row
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 320,
                          child: TextField(
                            key: const Key('activity_employee_search_input'),
                            controller: _employeeSearchController,
                            decoration: InputDecoration(
                              labelText: 'Search Employees',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: IconButton(
                                key: const Key(
                                  'activity_employee_search_button',
                                ),
                                icon: const Icon(Icons.search),
                                onPressed: () {
                                  setState(() {
                                    _employeeQuery =
                                        _employeeSearchController.text;
                                    _employeePage = 1;
                                  });
                                },
                              ),
                            ),
                            onSubmitted: (val) {
                              setState(() {
                                _employeeQuery = val;
                                _employeePage = 1;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    FilledButton(
                      key: const Key('activity_add_employee_button'),
                      onPressed: () =>
                          _showAssignEmployeeModal(allUsers, activity),
                      child: const Text('Assign User'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Employee Filters & Pagination Row
              (() {
                final assignedEmployees = allUsers.where((u) {
                  final isAssigned = activity.assignedUserEmails.contains(
                    u.email,
                  );
                  if (!isAssigned) return false;
                  if (u.orgUnitId != myOrg.id) return false;
                  final q = _employeeQuery.trim().toLowerCase();
                  if (q.isNotEmpty &&
                      !u.fullName.toLowerCase().contains(q) &&
                      !u.email.toLowerCase().contains(q)) {
                    return false;
                  }
                  if (_employeeStatusFilter != null &&
                      u.status != _employeeStatusFilter) {
                    return false;
                  }
                  if (_employeeRoleFilter != null &&
                      u.role != _employeeRoleFilter) {
                    return false;
                  }
                  return true;
                }).toList();

                final totalEmployees = assignedEmployees.length;
                const empItemsPerPage = 5;
                final maxEmpPage = (totalEmployees / empItemsPerPage)
                    .ceil()
                    .clamp(1, 9999);
                if (_employeePage > maxEmpPage) {
                  _employeePage = maxEmpPage;
                }
                final displayedEmployees = assignedEmployees
                    .skip((_employeePage - 1) * empItemsPerPage)
                    .take(empItemsPerPage)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              MenuAnchor(
                                builder: (context, controller, child) {
                                  return FilterChip(
                                    key: const Key(
                                      'activity_employee_filter_status_dropdown',
                                    ),
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_employeeStatusFilter ?? 'Status'),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.arrow_drop_down,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                    selected: _employeeStatusFilter != null,
                                    onSelected: (selected) {
                                      if (controller.isOpen) {
                                        controller.close();
                                      } else {
                                        controller.open();
                                      }
                                    },
                                  );
                                },
                                menuChildren: [
                                  MenuItemButton(
                                    key: const Key(
                                      'activity_employee_filter_status_all_item',
                                    ),
                                    onPressed: () => setState(() {
                                      _employeeStatusFilter = null;
                                      _employeePage = 1;
                                    }),
                                    child: const Text('All'),
                                  ),
                                  MenuItemButton(
                                    key: const Key(
                                      'activity_employee_filter_status_active_item',
                                    ),
                                    onPressed: () => setState(() {
                                      _employeeStatusFilter = 'Active';
                                      _employeePage = 1;
                                    }),
                                    child: const Text('Active'),
                                  ),
                                  MenuItemButton(
                                    key: const Key(
                                      'activity_employee_filter_status_inactive_item',
                                    ),
                                    onPressed: () => setState(() {
                                      _employeeStatusFilter = 'Inactive';
                                      _employeePage = 1;
                                    }),
                                    child: const Text('Inactive'),
                                  ),
                                ],
                              ),
                              MenuAnchor(
                                builder: (context, controller, child) {
                                  String roleLabel = 'Role';
                                  if (_employeeRoleFilter == 'Administrator') {
                                    roleLabel = 'Admin';
                                  }
                                  if (_employeeRoleFilter == 'User') {
                                    roleLabel = 'User';
                                  }
                                  return FilterChip(
                                    key: const Key(
                                      'activity_employee_filter_role_dropdown',
                                    ),
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(roleLabel),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.arrow_drop_down,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                    selected: _employeeRoleFilter != null,
                                    onSelected: (selected) {
                                      if (controller.isOpen) {
                                        controller.close();
                                      } else {
                                        controller.open();
                                      }
                                    },
                                  );
                                },
                                menuChildren: [
                                  MenuItemButton(
                                    key: const Key(
                                      'activity_employee_filter_role_all_item',
                                    ),
                                    onPressed: () => setState(() {
                                      _employeeRoleFilter = null;
                                      _employeePage = 1;
                                    }),
                                    child: const Text('All'),
                                  ),
                                  MenuItemButton(
                                    key: const Key(
                                      'activity_employee_filter_role_admin_item',
                                    ),
                                    onPressed: () => setState(() {
                                      _employeeRoleFilter = 'Administrator';
                                      _employeePage = 1;
                                    }),
                                    child: const Text('Admin'),
                                  ),
                                  MenuItemButton(
                                    key: const Key(
                                      'activity_employee_filter_role_user_item',
                                    ),
                                    onPressed: () => setState(() {
                                      _employeeRoleFilter = 'User';
                                      _employeePage = 1;
                                    }),
                                    child: const Text('User'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                totalEmployees == 0
                                    ? '0 of 0'
                                    : '${(_employeePage - 1) * 5 + 1}-${((_employeePage * 5) > totalEmployees) ? totalEmployees : (_employeePage * 5)} of $totalEmployees',
                                key: const Key(
                                  'activity_employee_pagination_displayed_count',
                                ),
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                key: const Key('activity_employee_page_back'),
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _employeePage > 1
                                    ? () => setState(() => _employeePage--)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              PageIndicatorInput(
                                currentPage: _employeePage,
                                maxPage: maxEmpPage,
                                onPageChanged: (page) =>
                                    setState(() => _employeePage = page),
                                inputKey: const Key(
                                  'activity_employee_pagination_pages_input',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '/ $maxEmpPage',
                                key: const Key(
                                  'activity_employee_pagination_pages',
                                ),
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                key: const Key(
                                  'activity_employee_page_forward',
                                ),
                                icon: const Icon(Icons.chevron_right),
                                onPressed: _employeePage < maxEmpPage
                                    ? () => setState(() => _employeePage++)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Employees Table
                    Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              bottom: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 2.0,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          child: Row(
                            children: const [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Full Name',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Status',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'Email',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Title',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              SizedBox(width: 80),
                            ],
                          ),
                        ),
                        if (displayedEmployees.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: const Center(
                              child: Text('No employees assigned.'),
                            ),
                          )
                        else
                          ListView.builder(
                            key: const Key('activity_employees_table'),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: displayedEmployees.length,
                            itemBuilder: (context, idx) {
                              final employee = displayedEmployees[idx];
                              return Container(
                                key: Key(
                                  'activity_employee_row_${employee.email}',
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: idx == displayedEmployees.length - 1
                                        ? BorderSide.none
                                        : BorderSide(
                                            color: theme.colorScheme.primary,
                                            width: 0.5,
                                          ),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(employee.fullName),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: _buildStatusChip(
                                          employee.status,
                                          theme,
                                          context,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text(employee.email),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(employee.title),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child:
                                            (myOrg.id ==
                                                activity.ownerOrgUnitId)
                                            ? Directionality(
                                                textDirection:
                                                    TextDirection.rtl,
                                                child: MenuAnchor(
                                                  key: Key(
                                                    'activity_employee_overflow_button_${employee.email}',
                                                  ),
                                                  builder:
                                                      (
                                                        context,
                                                        controller,
                                                        child,
                                                      ) {
                                                        return IconButton(
                                                          icon: const Icon(
                                                            Icons.more_vert,
                                                          ),
                                                          tooltip: 'Show menu',
                                                          onPressed: () {
                                                            if (controller
                                                                .isOpen) {
                                                              controller
                                                                  .close();
                                                            } else {
                                                              controller.open();
                                                            }
                                                          },
                                                        );
                                                      },
                                                  menuChildren: [
                                                    Directionality(
                                                      textDirection:
                                                          TextDirection.ltr,
                                                      child: MenuItemButton(
                                                        key: Key(
                                                          'activity_employee_remove_button_${employee.email}',
                                                        ),
                                                        onPressed: () async {
                                                          final updatedEmails =
                                                              activity
                                                                  .assignedUserEmails
                                                                  .where(
                                                                    (e) =>
                                                                        e !=
                                                                        employee
                                                                            .email,
                                                                  )
                                                                  .toList();
                                                          final updatedActivity =
                                                              activity.copyWith(
                                                                assignedUserEmails:
                                                                    updatedEmails,
                                                                lastModifiedBy:
                                                                    ref
                                                                        .read(
                                                                          currentUserProvider,
                                                                        )
                                                                        ?.email ??
                                                                    'system',
                                                                lastModifiedAt:
                                                                    DateTime.now(),
                                                              );
                                                          await ref
                                                              .read(
                                                                databaseServiceProvider,
                                                              )
                                                              .saveActivity(
                                                                updatedActivity,
                                                              );
                                                          setState(() {});
                                                        },
                                                        child: const Text(
                                                          'Remove',
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                );
              })(),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareModal(ActivityModel act) {
    final myOrg = ref.read(userOwnedOrgUnitProvider);
    if (myOrg == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final orgUnits = ref.watch(orgUnitsStreamProvider).value ?? [];
            final targetOrgUnits = orgUnits
                .where((o) => o.id != myOrg.id)
                .toList();

            return ShareWizardModal<ActivityModel>(
              title: 'Select Activities',
              items: [act],
              itemSearchString: (item) => item.name,
              itemTile: (item, selected, onChanged) => CheckboxListTile(
                title: Text(item.name),
                value: selected,
                onChanged: onChanged,
              ),
              orgUnits: targetOrgUnits,
              initialItem: act,
              onShare: (selectedItems, selectedOrgs) async {
                final user = ref.read(currentUserProvider);
                for (final item in selectedItems) {
                  final newShared = <String>{
                    ...item.sharedOrgUnitIds,
                    ...selectedOrgs,
                  }.toList();
                  await ref
                      .read(databaseServiceProvider)
                      .saveActivity(
                        item.copyWith(
                          sharedOrgUnitIds: newShared,
                          lastModifiedBy: user?.email ?? 'system',
                          lastModifiedAt: DateTime.now(),
                        ),
                      );
                }
              },
            );
          },
        );
      },
    );
  }

  void _showReactivateModal(ActivityModel act) {
    final startController = TextEditingController(
      text: act.validityStart != null
          ? act.validityStart!.toLocal().toString().split(' ')[0]
          : '',
    );
    final endController = TextEditingController(
      text: act.validityEnd != null
          ? act.validityEnd!.toLocal().toString().split(' ')[0]
          : '',
    );
    final startFocusNode = FocusNode();
    final endFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (context) {
        DateTime? localStart = act.validityStart;
        DateTime? localEnd = act.validityEnd;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> selectDate(bool isStart) async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: isStart
                    ? (localStart ?? DateTime.now())
                    : (localEnd ?? DateTime.now()),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null) {
                setDialogState(() {
                  if (isStart) {
                    localStart = picked;
                    startController.text = picked.toLocal().toString().split(
                      ' ',
                    )[0];
                  } else {
                    localEnd = picked;
                    endController.text = picked.toLocal().toString().split(
                      ' ',
                    )[0];
                  }
                });
              }
            }

            final hasRange =
                startController.text.trim().isNotEmpty &&
                endController.text.trim().isNotEmpty;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: const Text(
                'Reactivate Activity',
                key: Key('reactivate_modal_title'),
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'This activity validity has expired. Please pick a new validity range:',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('reactivate_modal_validity_start_input'),
                      controller: startController,
                      focusNode: startFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Start Date',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => selectDate(true),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('reactivate_modal_validity_end_input'),
                      controller: endController,
                      focusNode: endFocusNode,
                      decoration: InputDecoration(
                        labelText: 'End Date',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => selectDate(false),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  key: const Key('reactivate_modal_cancel_button'),
                  onPressed: () {
                    startController.dispose();
                    endController.dispose();
                    startFocusNode.dispose();
                    endFocusNode.dispose();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('reactivate_modal_confirm_button'),
                  onPressed: hasRange
                      ? () async {
                          final user = ref.read(currentUserProvider);
                          final myOrg = ref.read(userOwnedOrgUnitProvider);
                          if (myOrg == null) return;

                          final startParsed = DateTime.tryParse(
                            startController.text.trim(),
                          );
                          final endParsed = DateTime.tryParse(
                            endController.text.trim(),
                          );
                          if (startParsed != null) {
                            localStart = startParsed;
                          }
                          if (endParsed != null) {
                            localEnd = endParsed;
                          }

                          if (localStart == null || localEnd == null) return;

                          final newStatusMap = Map<String, String>.from(
                            act.statusMap,
                          )..[myOrg.id] = 'Active';
                          await ref
                              .read(databaseServiceProvider)
                              .saveActivity(
                                act.copyWith(
                                  statusMap: newStatusMap,
                                  validityStart: () => localStart,
                                  validityEnd: () => localEnd,
                                  lastModifiedBy: user?.email ?? 'system',
                                  lastModifiedAt: DateTime.now(),
                                ),
                              );

                          startController.dispose();
                          endController.dispose();
                          startFocusNode.dispose();
                          endFocusNode.dispose();

                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      : null,
                  child: const Text('Reactivate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showChangeOwnershipModal({
    required BuildContext context,
    required String currentOwnerId,
    required String resourceName,
    required ValueChanged<OrgUnitModel> onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final orgUnits = ref.watch(orgUnitsStreamProvider).value ?? [];
            return ChangeOwnershipDialog(
              title: 'Change Ownership',
              currentOwnerId: currentOwnerId,
              orgUnits: orgUnits,
              onConfirm: onConfirm,
            );
          },
        );
      },
    );
  }
}

Widget _buildStatusChip(
  String status,
  ThemeData theme,
  BuildContext context, {
  Key? key,
}) {
  final isActive = status == 'Active';
  final colors = context.colors;

  final bgColor = isActive
      ? colors.successContainer
      : theme.colorScheme.errorContainer;
  final textColor = isActive
      ? colors.onSuccessContainer
      : theme.colorScheme.onErrorContainer;
  final dotColor = isActive
      ? colors.onSuccessContainer
      : theme.colorScheme.onErrorContainer;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Inactive',
            key: key,
            style: theme.textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

class PageIndicatorInput extends StatefulWidget {
  final int currentPage;
  final int maxPage;
  final ValueChanged<int> onPageChanged;
  final Key? inputKey;

  const PageIndicatorInput({
    super.key,
    required this.currentPage,
    required this.maxPage,
    required this.onPageChanged,
    this.inputKey,
  });

  @override
  State<PageIndicatorInput> createState() => _PageIndicatorInputState();
}

class _PageIndicatorInputState extends State<PageIndicatorInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentPage.toString());
  }

  @override
  void didUpdateWidget(covariant PageIndicatorInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      _controller.text = widget.currentPage.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 48,
      child: TextField(
        key: widget.inputKey,
        controller: _controller,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: TextInputType.number,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 6,
          ),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onSubmitted: (val) {
          final page = int.tryParse(val);
          if (page != null && page >= 1 && page <= widget.maxPage) {
            widget.onPageChanged(page);
          } else {
            _controller.text = widget.currentPage.toString();
          }
        },
      ),
    );
  }
}
