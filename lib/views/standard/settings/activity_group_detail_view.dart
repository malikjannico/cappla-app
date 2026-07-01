import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/router_paths.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../models/org_unit_model.dart';
import '../../admin/org_admin/org_admin_list_view.dart' show PageIndicatorInput;
import 'categories_list_view.dart' show ShareWizardModal, ApplyModal;
import 'category_create_view.dart' show BreadcrumbLink;
import 'change_ownership_dialog.dart';

final activityGroupStreamProvider = StreamProvider.autoDispose
    .family<ActivityGroupModel?, String>((ref, id) {
      return ref.watch(databaseServiceProvider).watchActivityGroup(id);
    });

class ActivityGroupDetailView extends ConsumerStatefulWidget {
  final String id;
  const ActivityGroupDetailView({super.key, required this.id});

  @override
  ConsumerState<ActivityGroupDetailView> createState() =>
      _ActivityGroupDetailViewState();
}

class _ActivityGroupDetailViewState
    extends ConsumerState<ActivityGroupDetailView> {
  final _activitySearchController = TextEditingController();
  String _activitySearchQuery = '';
  int _activityCurrentPage = 1;

  @override
  void dispose() {
    _activitySearchController.dispose();
    super.dispose();
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
            'Only heads of organization units can view activity group details.',
          ),
        ),
      );
    }

    final groupAsync = ref.watch(activityGroupStreamProvider(widget.id));
    final group = groupAsync.value;

    if (group == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFFFFF),
        body: Center(child: Text('Loading Activity Group or Group Not Found')),
      );
    }

    final groupStatus = group.statusMap[myOrg.id] ?? 'Active';
    final isOwner = group.ownerOrgUnitId == myOrg.id;

    // Load activities & categories
    final activitiesAsync = ref.watch(activitiesStreamProvider);
    final allActivities = activitiesAsync.value ?? [];

    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final allCategories = categoriesAsync.value ?? [];

    // Filter activities belonging to this group and owned/applied by myOrg
    final groupActivities = allActivities.where((act) {
      if (act.activityGroupId != group.id) return false;
      final isActOwner = act.ownerOrgUnitId == myOrg.id;
      final isActApplied = act.appliedOrgUnitIds.contains(myOrg.id);
      if (!isActOwner && !isActApplied) return false;

      if (_activitySearchQuery.isNotEmpty) {
        return act.name.toLowerCase().contains(
          _activitySearchQuery.toLowerCase(),
        );
      }
      return true;
    }).toList()..sort((a, b) => a.order.compareTo(b.order));

    // Pagination for activities
    final totalActivities = groupActivities.length;
    const itemsPerPage = 5;
    final maxPage = (totalActivities / itemsPerPage).ceil().clamp(1, 9999);

    if (_activityCurrentPage > maxPage) {
      _activityCurrentPage = maxPage;
    }

    final displayedActivities = groupActivities
        .skip((_activityCurrentPage - 1) * itemsPerPage)
        .take(itemsPerPage)
        .toList();

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
                    linkKey: const Key('activity_group_detail_back_button'),
                    onTap: () => context.go(RouterPaths.settingsActivityGroups),
                  ),
                  Text(
                    ' / ${group.name}',
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
                      group.name,
                      key: const Key('activity_group_detail_title'),
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
                          key: const Key('activity_group_detail_edit_button'),
                          onPressed: () {
                            context.go(
                              RouterPaths.settingsActivityGroupsEditPath(
                                group.id,
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
                          key: const Key(
                            'activity_group_detail_overflow_button',
                          ),
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
                                  'activity_group_detail_toggle_status_item',
                                ),
                                onPressed: () async {
                                  const val = 'toggle';
                                  if (val == 'toggle') {
                                    final newStatus = groupStatus == 'Active'
                                        ? 'Inactive'
                                        : 'Active';
                                    final newStatusMap =
                                        Map<String, String>.from(
                                          group.statusMap,
                                        )..[myOrg.id] = newStatus;
                                    await ref
                                        .read(databaseServiceProvider)
                                        .saveActivityGroup(
                                          group.copyWith(
                                            statusMap: newStatusMap,
                                            lastModifiedBy:
                                                user?.email ?? 'system',
                                            lastModifiedAt: DateTime.now(),
                                          ),
                                        );
                                  } else if (val == 'share') {
                                    _showShareGroupModal(group);
                                  } else if (val == 'delete') {
                                    try {
                                      await ref
                                          .read(databaseServiceProvider)
                                          .deleteActivityGroup(
                                            group.id,
                                            myOrg.id,
                                          );
                                      if (context.mounted) {
                                        context.go(
                                          RouterPaths.settingsActivityGroups,
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
                                  groupStatus == 'Active'
                                      ? 'Deactivate'
                                      : 'Activate',
                                ),
                              ),
                            ),
                            if (isOwner)
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: MenuItemButton(
                                  key: Key('activity_group_detail_share_item'),
                                  onPressed: () async {
                                    const val = 'share';
                                    if (val == 'toggle') {
                                      final newStatus = groupStatus == 'Active'
                                          ? 'Inactive'
                                          : 'Active';
                                      final newStatusMap =
                                          Map<String, String>.from(
                                            group.statusMap,
                                          )..[myOrg.id] = newStatus;
                                      await ref
                                          .read(databaseServiceProvider)
                                          .saveActivityGroup(
                                            group.copyWith(
                                              statusMap: newStatusMap,
                                              lastModifiedBy:
                                                  user?.email ?? 'system',
                                              lastModifiedAt: DateTime.now(),
                                            ),
                                          );
                                    } else if (val == 'share') {
                                      _showShareGroupModal(group);
                                    } else if (val == 'delete') {
                                      try {
                                        await ref
                                            .read(databaseServiceProvider)
                                            .deleteActivityGroup(
                                              group.id,
                                              myOrg.id,
                                            );
                                        if (context.mounted) {
                                          context.go(
                                            RouterPaths.settingsActivityGroups,
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
                                key: const Key(
                                  'activity_group_detail_delete_item',
                                ),
                                onPressed: () async {
                                  const val = 'delete';
                                  if (val == 'toggle') {
                                    final newStatus = groupStatus == 'Active'
                                        ? 'Inactive'
                                        : 'Active';
                                    final newStatusMap =
                                        Map<String, String>.from(
                                          group.statusMap,
                                        )..[myOrg.id] = newStatus;
                                    await ref
                                        .read(databaseServiceProvider)
                                        .saveActivityGroup(
                                          group.copyWith(
                                            statusMap: newStatusMap,
                                            lastModifiedBy:
                                                user?.email ?? 'system',
                                            lastModifiedAt: DateTime.now(),
                                          ),
                                        );
                                  } else if (val == 'share') {
                                    _showShareGroupModal(group);
                                  } else if (val == 'delete') {
                                    try {
                                      await ref
                                          .read(databaseServiceProvider)
                                          .deleteActivityGroup(
                                            group.id,
                                            myOrg.id,
                                          );
                                      if (context.mounted) {
                                        context.go(
                                          RouterPaths.settingsActivityGroups,
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
                                    'activity_group_detail_change_ownership_item',
                                  ),
                                  onPressed: () {
                                    _showChangeOwnershipModal(
                                      context: context,
                                      currentOwnerId: group.ownerOrgUnitId,
                                      resourceName: group.name,
                                      onConfirm: (targetOrg) async {
                                        final updatedGroup = group.copyWith(
                                          ownerOrgUnitId: targetOrg.id,
                                          sharedOrgUnitIds: <String>{
                                            ...group.sharedOrgUnitIds,
                                            myOrg.id,
                                          }.toList(),
                                          appliedOrgUnitIds: <String>{
                                            ...group.appliedOrgUnitIds,
                                            myOrg.id,
                                            targetOrg.id,
                                          }.toList(),
                                          statusMap: Map<String, String>.from(
                                            group.statusMap,
                                          )..[targetOrg.id] = 'Active',
                                          lastModifiedBy:
                                              user?.email ?? 'system',
                                          lastModifiedAt: DateTime.now(),
                                        );
                                        await ref
                                            .read(databaseServiceProvider)
                                            .saveActivityGroup(updatedGroup);
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
              // Activity Group Details Card
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
                            groupStatus,
                            theme,
                            context,
                            key: const Key(
                              'activity_group_detail_status_label',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('activity_group_detail_name'),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(text: group.name),
                        decoration: const InputDecoration(
                          labelText: 'Activity Group Name',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('activity_group_detail_created_by'),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(
                          text: group.createdBy,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Created By',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('activity_group_detail_created_at'),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(
                          text: group.createdAt.toLocal().toString().split(
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
                        key: const Key(
                          'activity_group_detail_last_modified_by',
                        ),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(
                          text: group.lastModifiedBy,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Last Modified By',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key(
                          'activity_group_detail_last_modified_at',
                        ),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(
                          text: group.lastModifiedAt.toLocal().toString().split(
                            '.',
                          )[0],
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
              // Activities Section Title
              Text(
                'Activities',
                key: const Key('activities_section_title'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Search & Create/Actions Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 320,
                        child: TextField(
                          key: const Key('activity_search_input'),
                          controller: _activitySearchController,
                          decoration: InputDecoration(
                            labelText: 'Search Activities',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: IconButton(
                              key: const Key('activity_search_button'),
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                setState(() {
                                  _activitySearchQuery =
                                      _activitySearchController.text;
                                  _activityCurrentPage = 1;
                                });
                              },
                            ),
                          ),
                          onSubmitted: (val) {
                            setState(() {
                              _activitySearchQuery = val;
                              _activityCurrentPage = 1;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Create a new Activity',
                        child: FilledButton.icon(
                          key: const Key('create_activity_button'),
                          onPressed: () {
                            context.go(
                              RouterPaths.settingsActivitiesNewPath(group.id),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Activity'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: MenuAnchor(
                          key: const Key('activity_list_actions_dropdown'),
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
                            if (isOwner)
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: MenuItemButton(
                                  key: Key('activity_list_share_item'),
                                  onPressed: () {
                                    const val = 'share';
                                    if (val == 'share') {
                                      _showShareActivitiesModal(groupActivities);
                                    } else if (val == 'apply') {
                                      _showApplyActivitiesModal();
                                    }
                                  },
                                  child: Text('Share'),
                                ),
                              ),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: MenuItemButton(
                                key: Key('activity_list_apply_item'),
                                onPressed: () {
                                  const val = 'apply';
                                  if (val == 'share') {
                                    _showShareActivitiesModal(groupActivities);
                                  } else if (val == 'apply') {
                                    _showApplyActivitiesModal();
                                  }
                                },
                                child: Text('Apply'),
                              ),
                            ),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: MenuItemButton(
                                key: const Key(
                                  'activity_list_change_order_item',
                                ),
                                onPressed: () {
                                  _showChangeOrderModal(groupActivities);
                                },
                                child: const Text('Change Order'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Pagination Row for activities
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    totalActivities == 0
                        ? '0 of 0'
                        : '${(_activityCurrentPage - 1) * 5 + 1}-${((_activityCurrentPage * 5) > totalActivities) ? totalActivities : (_activityCurrentPage * 5)} of $totalActivities',
                    key: const Key('activity_pagination_displayed_count'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    key: const Key('activity_page_back'),
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _activityCurrentPage > 1
                        ? () => setState(() => _activityCurrentPage--)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  PageIndicatorInput(
                    currentPage: _activityCurrentPage,
                    maxPage: maxPage,
                    onPageChanged: (page) =>
                        setState(() => _activityCurrentPage = page),
                    inputKey: const Key('activity_pagination_pages_input'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '/ $maxPage',
                    key: const Key('activity_pagination_pages'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('activity_page_forward'),
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _activityCurrentPage < maxPage
                        ? () => setState(() => _activityCurrentPage++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Table of activities
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
                          flex: 1,
                          child: Text(
                            'Order',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Name',
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
                          flex: 2,
                          child: Text(
                            'Category',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Type',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Validity',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 180),
                      ],
                    ),
                  ),
                  if (displayedActivities.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: const Center(child: Text('No activities found.')),
                    )
                  else
                    ListView.builder(
                      key: const Key('activity_table'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedActivities.length,
                      itemBuilder: (context, idx) {
                        final act = displayedActivities[idx];
                        final actStatus = act.statusMap[myOrg.id] ?? 'Active';
                        final actOwner = act.ownerOrgUnitId == myOrg.id;

                        final categoryName = (() {
                          if (act.categoryId == null ||
                              act.categoryId!.isEmpty) {
                            return '-';
                          }
                          final c = allCategories.firstWhere(
                            (cat) => cat.id == act.categoryId,
                            orElse: () => CategoryModel(
                              id: '',
                              name: 'Unknown',
                              ownerOrgUnitId: '',
                              sharedOrgUnitIds: [],
                              appliedOrgUnitIds: [],
                              statusMap: {},
                              createdBy: '',
                              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                              lastModifiedBy: '',
                              lastModifiedAt:
                                  DateTime.fromMillisecondsSinceEpoch(0),
                              order: 0,
                            ),
                          );
                          return c.name;
                        })();

                        final validityStr = act.type == ActivityType.limited
                            ? '${act.validityStart?.toLocal().toString().split(' ')[0]} to ${act.validityEnd?.toLocal().toString().split(' ')[0]}'
                            : '-';

                        return InkWell(
                          key: Key('activity_row_${act.id}'),
                          onTap: () {
                            context.go(
                              RouterPaths.settingsActivitiesDetailPath(
                                group.id,
                                act.id,
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: idx == displayedActivities.length - 1
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
                                Expanded(flex: 1, child: Text('${act.order}')),
                                Expanded(flex: 3, child: Text(act.name)),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _buildStatusChip(
                                      actStatus,
                                      theme,
                                      context,
                                      key: Key('activity_row_status_${act.id}'),
                                    ),
                                  ),
                                ),
                                Expanded(flex: 2, child: Text(categoryName)),
                                Expanded(flex: 2, child: Text(act.type.value)),
                                Expanded(flex: 3, child: Text(validityStr)),
                                SizedBox(
                                  width: 180,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (actOwner) ...[
                                        FilledButton(
                                          key: Key(
                                            'activity_row_edit_button_${act.id}',
                                          ),
                                          onPressed: () {
                                            context.go(
                                              RouterPaths.settingsActivitiesEditPath(
                                                group.id,
                                                act.id,
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
                                          key: Key(
                                            'activity_row_overflow_button_${act.id}',
                                          ),
                                          builder:
                                              (context, controller, child) {
                                                return IconButton(
                                                  icon: const Icon(
                                                    Icons.more_vert,
                                                  ),
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
                                                key: Key(
                                                  'activity_row_toggle_status_item_${act.id}',
                                                ),
                                                onPressed: () async {
                                                  const val = 'toggle';
                                                  if (val == 'toggle') {
                                                    final newStatus =
                                                        actStatus == 'Active'
                                                        ? 'Inactive'
                                                        : 'Active';
                                                    final newStatusMap =
                                                        Map<
                                                            String,
                                                            String
                                                          >.from(act.statusMap)
                                                          ..[myOrg.id] =
                                                              newStatus;
                                                    await ref
                                                        .read(
                                                          databaseServiceProvider,
                                                        )
                                                        .saveActivity(
                                                          act.copyWith(
                                                            statusMap:
                                                                newStatusMap,
                                                            lastModifiedBy:
                                                                user?.email ??
                                                                'system',
                                                            lastModifiedAt:
                                                                DateTime.now(),
                                                          ),
                                                        );
                                                  } else if (val == 'share') {
                                                    _showShareActivitiesModal([
                                                      act,
                                                    ]);
                                                  } else if (val == 'delete') {
                                                    try {
                                                      await ref
                                                          .read(
                                                            databaseServiceProvider,
                                                          )
                                                          .deleteActivity(
                                                            act.id,
                                                            myOrg.id,
                                                          );
                                                    } catch (e) {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              e
                                                                  .toString()
                                                                  .replaceAll(
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
                                            if (actOwner)
                                              Directionality(
                                                textDirection: TextDirection.ltr,
                                                child: MenuItemButton(
                                                  key: Key(
                                                    'activity_row_share_item_${act.id}',
                                                  ),
                                                  onPressed: () async {
                                                    const val = 'share';
                                                    if (val == 'toggle') {
                                                      final newStatus =
                                                          actStatus == 'Active'
                                                          ? 'Inactive'
                                                          : 'Active';
                                                      final newStatusMap =
                                                          Map<
                                                              String,
                                                              String
                                                            >.from(act.statusMap)
                                                            ..[myOrg.id] =
                                                                newStatus;
                                                      await ref
                                                          .read(
                                                            databaseServiceProvider,
                                                          )
                                                          .saveActivity(
                                                            act.copyWith(
                                                              statusMap:
                                                                  newStatusMap,
                                                              lastModifiedBy:
                                                                  user?.email ??
                                                                  'system',
                                                              lastModifiedAt:
                                                                  DateTime.now(),
                                                            ),
                                                          );
                                                    } else if (val == 'share') {
                                                      _showShareActivitiesModal([
                                                        act,
                                                      ]);
                                                    } else if (val == 'delete') {
                                                      try {
                                                        await ref
                                                            .read(
                                                              databaseServiceProvider,
                                                            )
                                                            .deleteActivity(
                                                              act.id,
                                                              myOrg.id,
                                                            );
                                                      } catch (e) {
                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                e
                                                                    .toString()
                                                                    .replaceAll(
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
                                                  child: const Text('Share'),
                                                ),
                                              ),
                                            Directionality(
                                              textDirection: TextDirection.ltr,
                                              child: MenuItemButton(
                                                key: Key(
                                                  'activity_row_delete_item_${act.id}',
                                                ),
                                                onPressed: () async {
                                                  const val = 'delete';
                                                  if (val == 'toggle') {
                                                    final newStatus =
                                                        actStatus == 'Active'
                                                        ? 'Inactive'
                                                        : 'Active';
                                                    final newStatusMap =
                                                        Map<
                                                            String,
                                                            String
                                                          >.from(act.statusMap)
                                                          ..[myOrg.id] =
                                                              newStatus;
                                                    await ref
                                                        .read(
                                                          databaseServiceProvider,
                                                        )
                                                        .saveActivity(
                                                          act.copyWith(
                                                            statusMap:
                                                                newStatusMap,
                                                            lastModifiedBy:
                                                                user?.email ??
                                                                'system',
                                                            lastModifiedAt:
                                                                DateTime.now(),
                                                          ),
                                                        );
                                                  } else if (val == 'share') {
                                                    _showShareActivitiesModal([
                                                      act,
                                                    ]);
                                                  } else if (val == 'delete') {
                                                    try {
                                                      await ref
                                                          .read(
                                                            databaseServiceProvider,
                                                          )
                                                          .deleteActivity(
                                                            act.id,
                                                            myOrg.id,
                                                          );
                                                    } catch (e) {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              e
                                                                  .toString()
                                                                  .replaceAll(
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
                                                  actOwner
                                                      ? 'Delete'
                                                      : 'Remove',
                                                ),
                                              ),
                                            ),
                                            if (actOwner &&
                                                myOrg.headOfEmail
                                                        .trim()
                                                        .toLowerCase() ==
                                                    user?.email
                                                        .trim()
                                                        .toLowerCase())
                                              Directionality(
                                                textDirection:
                                                    TextDirection.ltr,
                                                child: MenuItemButton(
                                                  key: Key(
                                                    'activity_row_change_ownership_item_${act.id}',
                                                  ),
                                                  onPressed: () {
                                                    _showChangeOwnershipModal(
                                                      context: context,
                                                      currentOwnerId:
                                                          act.ownerOrgUnitId,
                                                      resourceName: act.name,
                                                      onConfirm: (targetOrg) async {
                                                        final updatedAct = act.copyWith(
                                                          ownerOrgUnitId:
                                                              targetOrg.id,
                                                          sharedOrgUnitIds:
                                                              <String>{
                                                                ...act
                                                                    .sharedOrgUnitIds,
                                                                myOrg.id,
                                                              }.toList(),
                                                          appliedOrgUnitIds:
                                                              <String>{
                                                                ...act
                                                                    .appliedOrgUnitIds,
                                                                myOrg.id,
                                                                targetOrg.id,
                                                              }.toList(),
                                                          statusMap:
                                                              Map<
                                                                  String,
                                                                  String
                                                                >.from(
                                                                  act.statusMap,
                                                                )
                                                                ..[targetOrg
                                                                        .id] =
                                                                    'Active',
                                                          lastModifiedBy:
                                                              user?.email ??
                                                              'system',
                                                          lastModifiedAt:
                                                              DateTime.now(),
                                                        );
                                                        await ref
                                                            .read(
                                                              databaseServiceProvider,
                                                            )
                                                            .saveActivity(
                                                              updatedAct,
                                                            );
                                                      },
                                                    );
                                                  },
                                                  child: const Text(
                                                    'Change Ownership',
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareGroupModal(ActivityGroupModel g) {
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

            return ShareWizardModal<ActivityGroupModel>(
              title: 'Select Activity Groups',
              items: [g],
              itemSearchString: (item) => item.name,
              itemTile: (item, selected, onChanged) => CheckboxListTile(
                title: Text(item.name),
                value: selected,
                onChanged: onChanged,
              ),
              orgUnits: targetOrgUnits,
              initialItem: g,
              onShare: (selectedItems, selectedOrgs) async {
                final user = ref.read(currentUserProvider);
                for (final item in selectedItems) {
                  final newShared = <String>{
                    ...item.sharedOrgUnitIds,
                    ...selectedOrgs,
                  }.toList();
                  await ref
                      .read(databaseServiceProvider)
                      .saveActivityGroup(
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

  void _showShareActivitiesModal(List<ActivityModel> groupActs) {
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
            final shareableActs = groupActs
                .where((a) => a.ownerOrgUnitId == myOrg.id)
                .toList();

            return ShareWizardModal<ActivityModel>(
              title: 'Select Activities',
              items: shareableActs,
              itemSearchString: (a) => a.name,
              itemTile: (a, selected, onChanged) => CheckboxListTile(
                title: Text(a.name),
                value: selected,
                onChanged: onChanged,
              ),
              orgUnits: targetOrgUnits,
              onShare: (selectedItems, selectedOrgs) async {
                final user = ref.read(currentUserProvider);
                for (final a in selectedItems) {
                  final newShared = <String>{
                    ...a.sharedOrgUnitIds,
                    ...selectedOrgs,
                  }.toList();
                  await ref
                      .read(databaseServiceProvider)
                      .saveActivity(
                        a.copyWith(
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

  void _showApplyActivitiesModal() {
    final myOrg = ref.read(userOwnedOrgUnitProvider);
    if (myOrg == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final activities = ref.watch(activitiesStreamProvider).value ?? [];

            // Shared activities in this group but not applied yet
            final sharedWithMe = activities.where((a) {
              if (a.activityGroupId != widget.id) return false;
              final isShared = a.sharedOrgUnitIds.contains(myOrg.id);
              final isApplied = a.appliedOrgUnitIds.contains(myOrg.id);
              final isOwner = a.ownerOrgUnitId == myOrg.id;
              return isShared && !isApplied && !isOwner;
            }).toList();

            return ApplyModal<ActivityModel>(
              title: 'Apply Activities',
              items: sharedWithMe,
              itemSearchString: (a) => a.name,
              itemId: (a) => a.id,
              onApply: (selectedItems) async {
                final user = ref.read(currentUserProvider);
                for (final a in selectedItems) {
                  final newApplied = <String>{
                    ...a.appliedOrgUnitIds,
                    myOrg.id,
                  }.toList();
                  final newStatusMap = Map<String, String>.from(a.statusMap)
                    ..[myOrg.id] = 'Active';
                  await ref
                      .read(databaseServiceProvider)
                      .saveActivity(
                        a.copyWith(
                          appliedOrgUnitIds: newApplied,
                          statusMap: newStatusMap,
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

  void _showChangeOrderModal(List<ActivityModel> activities) {
    final localActivities = List<ActivityModel>.from(activities);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: const Text('Change Order'),
              content: SizedBox(
                width: 400,
                height: 400,
                child: localActivities.isEmpty
                    ? const Center(child: Text('No activities.'))
                    : ReorderableListView.builder(
                        itemCount: localActivities.length,
                        onReorderItem: (oldIndex, newIndex) {
                          setModalState(() {
                            final item = localActivities.removeAt(oldIndex);
                            localActivities.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final act = localActivities[index];
                          return ListTile(
                            key: ValueKey(act.id),
                            title: Row(
                              children: [
                                Text(
                                  '${index + 1}. ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(child: Text(act.name)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  key: const Key('change_order_cancel_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('change_order_save_button'),
                  onPressed: () async {
                    try {
                      final db = ref.read(databaseServiceProvider);
                      for (int i = 0; i < localActivities.length; i++) {
                        final act = localActivities[i];
                        final updated = act.copyWith(
                          order: i + 1,
                          lastModifiedBy:
                              ref.read(currentUserProvider)?.email ?? 'system',
                          lastModifiedAt: DateTime.now(),
                        );
                        await db.saveActivity(updated);
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                      setState(() {});
                    } catch (e) {
                      // handle error
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
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
