import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/router_paths.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../models/org_unit_model.dart';
import 'categories_list_view.dart' show ShareWizardModal;
import 'change_ownership_dialog.dart';
import 'activity_detail_view.dart' show PageIndicatorInput;

final categoryStreamProvider = StreamProvider.autoDispose
    .family<CategoryModel?, String>((ref, id) {
      return ref.watch(databaseServiceProvider).watchCategory(id);
    });

class CategoryDetailView extends ConsumerStatefulWidget {
  final String id;
  const CategoryDetailView({super.key, required this.id});

  @override
  ConsumerState<CategoryDetailView> createState() => _CategoryDetailViewState();
}

class _CategoryDetailViewState extends ConsumerState<CategoryDetailView> {
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
            'Only heads of organization units can view category details.',
          ),
        ),
      );
    }

    final categoryAsync = ref.watch(categoryStreamProvider(widget.id));
    final category = categoryAsync.value;

    if (category == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFFFFF),
        body: Center(child: Text('Loading Category or Category Not Found')),
      );
    }

    final catStatus = category.statusMap[myOrg.id] ?? 'Active';
    final isOwner = category.ownerOrgUnitId == myOrg.id;

    final activitiesAsync = ref.watch(activitiesStreamProvider);
    final allActivities = activitiesAsync.value ?? [];

    final activityGroupsAsync = ref.watch(activityGroupsStreamProvider);
    final allGroups = activityGroupsAsync.value ?? [];

    // Filter activities that have this categoryId and belong to myOrg (owned/applied)
    final categoryActivities = allActivities.where((act) {
      if (act.categoryId != category.id) return false;
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

    final totalActivities = categoryActivities.length;
    const itemsPerPage = 5;
    final maxPage = (totalActivities / itemsPerPage).ceil().clamp(1, 9999);

    if (_activityCurrentPage > maxPage) {
      _activityCurrentPage = maxPage;
    }

    final displayedActivities = categoryActivities
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
                    label: 'Categories',
                    linkKey: const Key('category_detail_back_button'),
                    onTap: () => context.go(RouterPaths.settingsCategories),
                  ),
                  Text(
                    ' / ${category.name}',
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
                      category.name,
                      key: const Key('category_detail_title'),
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
                          key: const Key('category_detail_edit_button'),
                          onPressed: () {
                            context.go(
                              RouterPaths.settingsCategoriesEditPath(category.id),
                            );
                          },
                          child: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: MenuAnchor(
                          key: const Key('category_detail_overflow_button'),
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
                                  'category_detail_toggle_status_item',
                                ),
                                onPressed: () async {
                                  const val = 'toggle';
                                  if (val == 'toggle') {
                                    final newStatus = catStatus == 'Active'
                                        ? 'Inactive'
                                        : 'Active';
                                    final newStatusMap =
                                        Map<String, String>.from(
                                          category.statusMap,
                                        )..[myOrg.id] = newStatus;
                                    await ref
                                        .read(databaseServiceProvider)
                                        .saveCategory(
                                          category.copyWith(
                                            statusMap: newStatusMap,
                                            lastModifiedBy:
                                                user?.email ?? 'system',
                                            lastModifiedAt: DateTime.now(),
                                          ),
                                        );
                                  } else if (val == 'share') {
                                    _showShareModal(category);
                                  } else if (val == 'delete') {
                                    try {
                                      await ref
                                          .read(databaseServiceProvider)
                                          .deleteCategory(
                                            category.id,
                                            myOrg.id,
                                          );
                                      if (context.mounted) {
                                        context.go(
                                          RouterPaths.settingsCategories,
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
                                  catStatus == 'Active'
                                      ? 'Deactivate'
                                      : 'Activate',
                                ),
                              ),
                            ),
                            if (isOwner)
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: MenuItemButton(
                                  key: Key('category_detail_share_item'),
                                  onPressed: () async {
                                    const val = 'share';
                                    if (val == 'toggle') {
                                      final newStatus = catStatus == 'Active'
                                          ? 'Inactive'
                                          : 'Active';
                                      final newStatusMap =
                                          Map<String, String>.from(
                                            category.statusMap,
                                          )..[myOrg.id] = newStatus;
                                      await ref
                                          .read(databaseServiceProvider)
                                          .saveCategory(
                                            category.copyWith(
                                              statusMap: newStatusMap,
                                              lastModifiedBy:
                                                  user?.email ?? 'system',
                                              lastModifiedAt: DateTime.now(),
                                            ),
                                          );
                                    } else if (val == 'share') {
                                      _showShareModal(category);
                                    } else if (val == 'delete') {
                                      try {
                                        await ref
                                            .read(databaseServiceProvider)
                                            .deleteCategory(
                                              category.id,
                                              myOrg.id,
                                            );
                                        if (context.mounted) {
                                          context.go(
                                            RouterPaths.settingsCategories,
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
                                key: const Key('category_detail_delete_item'),
                                onPressed: () async {
                                  const val = 'delete';
                                  if (val == 'toggle') {
                                    final newStatus = catStatus == 'Active'
                                        ? 'Inactive'
                                        : 'Active';
                                    final newStatusMap =
                                        Map<String, String>.from(
                                          category.statusMap,
                                        )..[myOrg.id] = newStatus;
                                    await ref
                                        .read(databaseServiceProvider)
                                        .saveCategory(
                                          category.copyWith(
                                            statusMap: newStatusMap,
                                            lastModifiedBy:
                                                user?.email ?? 'system',
                                            lastModifiedAt: DateTime.now(),
                                          ),
                                        );
                                  } else if (val == 'share') {
                                    _showShareModal(category);
                                  } else if (val == 'delete') {
                                    try {
                                      await ref
                                          .read(databaseServiceProvider)
                                          .deleteCategory(
                                            category.id,
                                            myOrg.id,
                                          );
                                      if (context.mounted) {
                                        context.go(
                                          RouterPaths.settingsCategories,
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
                                    'category_detail_change_ownership_item',
                                  ),
                                  onPressed: () {
                                    _showChangeOwnershipModal(
                                      context: context,
                                      currentOwnerId: category.ownerOrgUnitId,
                                      resourceName: category.name,
                                      onConfirm: (targetOrg) async {
                                        final updatedCat = category.copyWith(
                                          ownerOrgUnitId: targetOrg.id,
                                          sharedOrgUnitIds: <String>{
                                            ...category.sharedOrgUnitIds,
                                            myOrg.id,
                                          }.toList(),
                                          appliedOrgUnitIds: <String>{
                                            ...category.appliedOrgUnitIds,
                                            myOrg.id,
                                            targetOrg.id,
                                          }.toList(),
                                          statusMap: Map<String, String>.from(
                                            category.statusMap,
                                          )..[targetOrg.id] = 'Active',
                                          lastModifiedBy:
                                              user?.email ?? 'system',
                                          lastModifiedAt: DateTime.now(),
                                        );
                                        await ref
                                            .read(databaseServiceProvider)
                                            .saveCategory(updatedCat);
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
                            catStatus,
                            theme,
                            context,
                            key: const Key('category_detail_status_label'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('category_detail_name'),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(text: category.name),
                        decoration: const InputDecoration(
                          labelText: 'Category Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('category_detail_created_by'),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(
                          text: category.createdBy,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Created By',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('category_detail_created_at'),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(
                          text: category.createdAt.toLocal().toString().split(
                            '.',
                          )[0],
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Created At',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('category_detail_last_modified_by'),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(
                          text: category.lastModifiedBy,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Last Modified By',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('category_detail_last_modified_at'),
                        readOnly: true,
                        focusNode: FocusNode(
                          canRequestFocus: false,
                          skipTraversal: true,
                        ),
                        controller: TextEditingController(
                          text: category.lastModifiedAt
                              .toLocal()
                              .toString()
                              .split('.')[0],
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Last Modified At',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Activities Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Activities',
                    key: const Key('category_activities_title'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  FilledButton.icon(
                    key: const Key('category_add_activity_button'),
                    onPressed: () =>
                        _showAssignActivityModal(allActivities, allGroups),
                    icon: const Icon(Icons.add),
                    label: const Text('Assign Activity'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search & Pagination Row
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
                            key: const Key('category_activity_search_input'),
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
                                key: const Key(
                                  'category_activity_search_button',
                                ),
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          totalActivities == 0
                              ? '0 of 0'
                              : '${(_activityCurrentPage - 1) * 5 + 1}-${((_activityCurrentPage * 5) > totalActivities) ? totalActivities : (_activityCurrentPage * 5)} of $totalActivities',
                          key: const Key(
                            'category_activity_pagination_displayed_count',
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          key: const Key('category_activity_page_back'),
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
                          inputKey: const Key(
                            'category_activity_pagination_pages_input',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '/ $maxPage',
                          key: const Key('category_activity_pagination_pages'),
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: const Key('category_activity_page_forward'),
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _activityCurrentPage < maxPage
                              ? () => setState(() => _activityCurrentPage++)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Activities Table
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
                          flex: 3,
                          child: Text(
                            'Activity Group',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 80),
                      ],
                    ),
                  ),
                  if (displayedActivities.isEmpty)
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
                      child: const Center(child: Text('No activities found.')),
                    )
                  else
                    ListView.builder(
                      key: const Key('category_activities_table'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedActivities.length,
                      itemBuilder: (context, idx) {
                        final act = displayedActivities[idx];
                        final actStatus = act.statusMap[myOrg.id] ?? 'Active';
                        final groupName = allGroups
                            .firstWhere(
                              (g) => g.id == act.activityGroupId,
                              orElse: () => ActivityGroupModel(
                                id: '',
                                name: 'Unknown',
                                ownerOrgUnitId: '',
                                sharedOrgUnitIds: [],
                                appliedOrgUnitIds: [],
                                statusMap: {},
                                createdBy: '',
                                createdAt: DateTime.fromMillisecondsSinceEpoch(
                                  0,
                                ),
                                lastModifiedBy: '',
                                lastModifiedAt:
                                    DateTime.fromMillisecondsSinceEpoch(0),
                                order: 0,
                              ),
                            )
                            .name;

                        return Container(
                          key: Key('category_activity_row_${act.id}'),
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
                              Expanded(flex: 3, child: Text(act.name)),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildStatusChip(
                                    actStatus,
                                    theme,
                                    context,
                                  ),
                                ),
                              ),
                              Expanded(flex: 3, child: Text(groupName)),
                              SizedBox(
                                width: 80,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: MenuAnchor(
                                      key: Key(
                                        'category_activity_overflow_button_${act.id}',
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
                                            key: Key(
                                              'category_activity_remove_item_${act.id}',
                                            ),
                                            onPressed: () async {
                                              final updatedAct = act.copyWith(
                                                categoryId: () => null,
                                                lastModifiedBy:
                                                    user?.email ?? 'system',
                                                lastModifiedAt: DateTime.now(),
                                              );
                                              await ref
                                                  .read(databaseServiceProvider)
                                                  .saveActivity(updatedAct);
                                              setState(() {});
                                            },
                                            child: const Text('Remove'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
          ),
        ),
      ),
    );
  }

  void _showAssignActivityModal(
    List<ActivityModel> allActivities,
    List<ActivityGroupModel> allGroups,
  ) {
    final myOrg = ref.read(userOwnedOrgUnitProvider);
    if (myOrg == null) return;

    // Filter activities belonging to myOrg (owned or applied) that are NOT already in this category
    final assignableActivities = allActivities.where((act) {
      final isOwner = act.ownerOrgUnitId == myOrg.id;
      final isApplied = act.appliedOrgUnitIds.contains(myOrg.id);
      final isThisCategory = act.categoryId == widget.id;
      return (isOwner || isApplied) && !isThisCategory;
    }).toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        String query = '';
        final localSelectedIds = <String>{};

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredActs = assignableActivities.where((act) {
              final q = query.trim().toLowerCase();
              if (q.isEmpty) return true;
              return act.name.toLowerCase().contains(q);
            }).toList();

            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: const Text('Assign Activities to Category'),
              content: SizedBox(
                width: 450,
                height: 450,
                child: Column(
                  children: [
                    TextField(
                      key: const Key('activity_assign_modal_search_input'),
                      decoration: InputDecoration(
                        labelText: 'Search Activities',
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
                      child: filteredActs.isEmpty
                          ? const Center(
                              child: Text('No assignable activities found.'),
                            )
                          : ListView.builder(
                              itemCount: filteredActs.length,
                              itemBuilder: (context, idx) {
                                final act = filteredActs[idx];
                                final isSelected = localSelectedIds.contains(
                                  act.id,
                                );
                                final groupName = allGroups
                                    .firstWhere(
                                      (g) => g.id == act.activityGroupId,
                                      orElse: () => ActivityGroupModel(
                                        id: '',
                                        name: 'Unknown',
                                        ownerOrgUnitId: '',
                                        sharedOrgUnitIds: [],
                                        appliedOrgUnitIds: [],
                                        statusMap: {},
                                        createdBy: '',
                                        createdAt:
                                            DateTime.fromMillisecondsSinceEpoch(
                                              0,
                                            ),
                                        lastModifiedBy: '',
                                        lastModifiedAt:
                                            DateTime.fromMillisecondsSinceEpoch(
                                              0,
                                            ),
                                        order: 0,
                                      ),
                                    )
                                    .name;

                                return CheckboxListTile(
                                  key: Key(
                                    'activity_assign_modal_row_${act.id}',
                                  ),
                                  title: Text(act.name),
                                  subtitle: Text('Group: $groupName'),
                                  value: isSelected,
                                  activeColor: theme.colorScheme.primary,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        localSelectedIds.add(act.id);
                                      } else {
                                        localSelectedIds.remove(act.id);
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
                  key: const Key('activity_assign_modal_cancel_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('activity_assign_modal_save_button'),
                  onPressed: localSelectedIds.isEmpty
                      ? null
                      : () async {
                          try {
                            for (final actId in localSelectedIds) {
                              final act = allActivities.firstWhere(
                                (a) => a.id == actId,
                              );
                              final updatedAct = act.copyWith(
                                categoryId: () => widget.id,
                                lastModifiedBy:
                                    ref.read(currentUserProvider)?.email ??
                                    'system',
                                lastModifiedAt: DateTime.now(),
                              );
                              await ref
                                  .read(databaseServiceProvider)
                                  .saveActivity(updatedAct);
                            }
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

  void _showShareModal(CategoryModel cat) {
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

            return ShareWizardModal<CategoryModel>(
              title: 'Select Categories',
              items: [cat],
              itemSearchString: (c) => c.name,
              itemTile: (c, selected, onChanged) => CheckboxListTile(
                title: Text(c.name),
                value: selected,
                onChanged: onChanged,
              ),
              orgUnits: targetOrgUnits,
              initialItem: cat,
              onShare: (selectedItems, selectedOrgs) async {
                final user = ref.read(currentUserProvider);
                for (final item in selectedItems) {
                  final newShared = <String>{
                    ...item.sharedOrgUnitIds,
                    ...selectedOrgs,
                  }.toList();
                  await ref
                      .read(databaseServiceProvider)
                      .saveCategory(
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

class BreadcrumbLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Key? linkKey;

  const BreadcrumbLink({
    super.key,
    required this.label,
    required this.onTap,
    this.linkKey,
  });

  @override
  State<BreadcrumbLink> createState() => _BreadcrumbLinkState();
}

class _BreadcrumbLinkState extends State<BreadcrumbLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          key: widget.linkKey,
          style: TextStyle(
            color: theme.colorScheme.primary,
            decoration: _isHovered
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
        ),
      ),
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
