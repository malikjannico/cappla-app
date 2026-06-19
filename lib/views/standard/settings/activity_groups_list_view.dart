import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/router_paths.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../models/org_unit_model.dart';
import '../../admin/org_admin/org_admin_view.dart' show PageIndicatorInput;
import 'categories_list_view.dart' show ShareWizardModal, ApplyModal;
import 'change_ownership_dialog.dart';

class ActivityGroupsListView extends ConsumerStatefulWidget {
  const ActivityGroupsListView({super.key});

  @override
  ConsumerState<ActivityGroupsListView> createState() =>
      _ActivityGroupsListViewState();
}

class _ActivityGroupsListViewState
    extends ConsumerState<ActivityGroupsListView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;

  @override
  void dispose() {
    _searchController.dispose();
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
          child: Text('Only heads of organization units can access settings.'),
        ),
      );
    }

    final groupsAsync = ref.watch(activityGroupsStreamProvider);
    final allGroups = groupsAsync.value ?? [];

    // Filter activity groups: only show groups owned by myOrg OR applied by myOrg
    final myGroups = allGroups.where((g) {
      final isOwner = g.ownerOrgUnitId == myOrg.id;
      final isApplied = g.appliedOrgUnitIds.contains(myOrg.id);
      if (!isOwner && !isApplied) return false;

      if (_searchQuery.isNotEmpty) {
        return g.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList()..sort((a, b) => a.order.compareTo(b.order));

    // Pagination
    final totalGroups = myGroups.length;
    const itemsPerPage = 5;
    final maxPage = (totalGroups / itemsPerPage).ceil().clamp(1, 9999);

    if (_currentPage > maxPage) {
      _currentPage = maxPage;
    }

    final displayedGroups = myGroups
        .skip((_currentPage - 1) * itemsPerPage)
        .take(itemsPerPage)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Text(
            'Activity Groups',
            key: const Key('activity_groups_title'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // Search & Create/Overflow Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      key: const Key('activity_group_search_input'),
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search Activity Groups',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          key: const Key('activity_group_search_button'),
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            setState(() {
                              _searchQuery = _searchController.text;
                              _currentPage = 1;
                            });
                          },
                        ),
                      ),
                      onSubmitted: (val) {
                        setState(() {
                          _searchQuery = val;
                          _currentPage = 1;
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
                    message: 'Create a new Activity Group',
                    child: FilledButton.icon(
                      key: const Key('create_activity_group_button'),
                      onPressed: () {
                        context.go(RouterPaths.settingsActivityGroupsNew);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Activity Group'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: MenuAnchor(
                      key: const Key('activity_group_list_actions_dropdown'),
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
                            key: const Key('activity_group_list_share_item'),
                            onPressed: () {
                              _showShareModal();
                            },
                            child: const Text('Share'),
                          ),
                        ),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: MenuItemButton(
                            key: const Key('activity_group_list_apply_item'),
                            onPressed: () {
                              _showApplyModal();
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: MenuItemButton(
                            key: const Key(
                              'activity_group_list_change_order_item',
                            ),
                            onPressed: () {
                              _showChangeOrderModal(myGroups);
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
          // Pagination row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                totalGroups == 0
                    ? '0 of 0'
                    : '${(_currentPage - 1) * 5 + 1}-${((_currentPage * 5) > totalGroups) ? totalGroups : (_currentPage * 5)} of $totalGroups',
                key: const Key('activity_group_pagination_displayed_count'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 16),
              IconButton(
                key: const Key('activity_group_page_back'),
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              const SizedBox(width: 8),
              PageIndicatorInput(
                currentPage: _currentPage,
                maxPage: maxPage,
                onPageChanged: (page) => setState(() => _currentPage = page),
                inputKey: const Key('activity_group_pagination_pages_input'),
              ),
              const SizedBox(width: 8),
              Text(
                '/ $maxPage',
                key: const Key('activity_group_pagination_pages'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('activity_group_page_forward'),
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < maxPage
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Table
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                    width: 0.5,
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
                    SizedBox(width: 180),
                  ],
                ),
              ),
              if (groupsAsync.value == null && groupsAsync.isLoading)
                _buildTableSkeleton(theme)
              else if (displayedGroups.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                      right: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                      bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: const Center(child: Text('No activity groups found.')),
                )
              else
                ListView.builder(
                  key: const Key('activity_group_table'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayedGroups.length,
                  itemBuilder: (context, idx) {
                    final g = displayedGroups[idx];
                    final groupStatus = g.statusMap[myOrg.id] ?? 'Active';
                    final isOwner = g.ownerOrgUnitId == myOrg.id;

                    return InkWell(
                      key: Key('activity_group_row_${g.id}'),
                      onTap: () {
                        context.go(
                          RouterPaths.settingsActivityGroupsDetailPath(g.id),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                              width: 0.5,
                            ),
                            right: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                              width: 0.5,
                            ),
                            bottom: BorderSide(
                              color: theme.colorScheme.outlineVariant,
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
                            Expanded(flex: 1, child: Text('${g.order}')),
                            Expanded(flex: 3, child: Text(g.name)),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _buildStatusChip(
                                  groupStatus,
                                  theme,
                                  context,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 180,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  FilledButton(
                                    key: Key(
                                      'activity_group_row_edit_button_${g.id}',
                                    ),
                                    onPressed: () {
                                      context.go(
                                        RouterPaths.settingsActivityGroupsEditPath(
                                          g.id,
                                        ),
                                      );
                                    },
                                    child: const Text('Edit'),
                                  ),
                                  const SizedBox(width: 8),
                                  Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: MenuAnchor(
                                      key: Key(
                                        'activity_group_row_overflow_button_${g.id}',
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
                                              'activity_group_row_toggle_status_item_${g.id}',
                                            ),
                                            onPressed: () async {
                                              const val = 'toggle';
                                              if (val == 'toggle') {
                                                final newStatus =
                                                    groupStatus == 'Active'
                                                    ? 'Inactive'
                                                    : 'Active';
                                                final newStatusMap =
                                                    Map<String, String>.from(
                                                      g.statusMap,
                                                    )..[myOrg.id] = newStatus;
                                                await ref
                                                    .read(
                                                      databaseServiceProvider,
                                                    )
                                                    .saveActivityGroup(
                                                      g.copyWith(
                                                        statusMap: newStatusMap,
                                                        lastModifiedBy:
                                                            user?.email ??
                                                            'system',
                                                        lastModifiedAt:
                                                            DateTime.now(),
                                                      ),
                                                    );
                                              } else if (val == 'share') {
                                                _showShareModal(
                                                  initialGroup: g,
                                                );
                                              } else if (val == 'delete') {
                                                try {
                                                  await ref
                                                      .read(
                                                        databaseServiceProvider,
                                                      )
                                                      .deleteActivityGroup(
                                                        g.id,
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
                                              groupStatus == 'Active'
                                                  ? 'Deactivate'
                                                  : 'Activate',
                                            ),
                                          ),
                                        ),
                                        Directionality(
                                          textDirection: TextDirection.ltr,
                                          child: MenuItemButton(
                                            key: Key(
                                              'activity_group_row_share_item_${g.id}',
                                            ),
                                            onPressed: () async {
                                              const val = 'share';
                                              if (val == 'toggle') {
                                                final newStatus =
                                                    groupStatus == 'Active'
                                                    ? 'Inactive'
                                                    : 'Active';
                                                final newStatusMap =
                                                    Map<String, String>.from(
                                                      g.statusMap,
                                                    )..[myOrg.id] = newStatus;
                                                await ref
                                                    .read(
                                                      databaseServiceProvider,
                                                    )
                                                    .saveActivityGroup(
                                                      g.copyWith(
                                                        statusMap: newStatusMap,
                                                        lastModifiedBy:
                                                            user?.email ??
                                                            'system',
                                                        lastModifiedAt:
                                                            DateTime.now(),
                                                      ),
                                                    );
                                              } else if (val == 'share') {
                                                _showShareModal(
                                                  initialGroup: g,
                                                );
                                              } else if (val == 'delete') {
                                                try {
                                                  await ref
                                                      .read(
                                                        databaseServiceProvider,
                                                      )
                                                      .deleteActivityGroup(
                                                        g.id,
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
                                              'activity_group_row_delete_item_${g.id}',
                                            ),
                                            onPressed: () async {
                                              const val = 'delete';
                                              if (val == 'toggle') {
                                                final newStatus =
                                                    groupStatus == 'Active'
                                                    ? 'Inactive'
                                                    : 'Active';
                                                final newStatusMap =
                                                    Map<String, String>.from(
                                                      g.statusMap,
                                                    )..[myOrg.id] = newStatus;
                                                await ref
                                                    .read(
                                                      databaseServiceProvider,
                                                    )
                                                    .saveActivityGroup(
                                                      g.copyWith(
                                                        statusMap: newStatusMap,
                                                        lastModifiedBy:
                                                            user?.email ??
                                                            'system',
                                                        lastModifiedAt:
                                                            DateTime.now(),
                                                      ),
                                                    );
                                              } else if (val == 'share') {
                                                _showShareModal(
                                                  initialGroup: g,
                                                );
                                              } else if (val == 'delete') {
                                                try {
                                                  await ref
                                                      .read(
                                                        databaseServiceProvider,
                                                      )
                                                      .deleteActivityGroup(
                                                        g.id,
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
                                              isOwner ? 'Delete' : 'Remove',
                                            ),
                                          ),
                                        ),
                                        if (isOwner &&
                                            myOrg.headOfEmail
                                                    .trim()
                                                    .toLowerCase() ==
                                                user?.email
                                                    .trim()
                                                    .toLowerCase())
                                          Directionality(
                                            textDirection: TextDirection.ltr,
                                            child: MenuItemButton(
                                              key: Key(
                                                'activity_group_row_change_ownership_item_${g.id}',
                                              ),
                                              onPressed: () {
                                                _showChangeOwnershipModal(
                                                  context: context,
                                                  currentOwnerId:
                                                      g.ownerOrgUnitId,
                                                  resourceName: g.name,
                                                  onConfirm: (targetOrg) async {
                                                    final updatedGroup = g.copyWith(
                                                      ownerOrgUnitId:
                                                          targetOrg.id,
                                                      sharedOrgUnitIds: <String>{
                                                        ...g.sharedOrgUnitIds,
                                                        myOrg.id,
                                                      }.toList(),
                                                      appliedOrgUnitIds: <String>{
                                                        ...g.appliedOrgUnitIds,
                                                        myOrg.id,
                                                        targetOrg.id,
                                                      }.toList(),
                                                      statusMap:
                                                          Map<
                                                              String,
                                                              String
                                                            >.from(g.statusMap)
                                                            ..[targetOrg.id] =
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
                                                        .saveActivityGroup(
                                                          updatedGroup,
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
    );
  }

  void _showShareModal({ActivityGroupModel? initialGroup}) {
    final myOrg = ref.read(userOwnedOrgUnitProvider);
    if (myOrg == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final groups = ref.watch(activityGroupsStreamProvider).value ?? [];
            final orgUnits = ref.watch(orgUnitsStreamProvider).value ?? [];

            // Eligible activity groups to share: owned by this unit
            final shareableGroups = groups
                .where((g) => g.ownerOrgUnitId == myOrg.id)
                .toList();
            // Other org units to share with
            final targetOrgUnits = orgUnits
                .where((o) => o.id != myOrg.id)
                .toList();

            return ShareWizardModal<ActivityGroupModel>(
              title: 'Select Activity Groups',
              items: shareableGroups,
              itemSearchString: (g) => g.name,
              itemTile: (g, selected, onChanged) => CheckboxListTile(
                title: Text(g.name),
                value: selected,
                onChanged: onChanged,
              ),
              orgUnits: targetOrgUnits,
              initialItem: initialGroup,
              onShare: (selectedItems, selectedOrgs) async {
                final user = ref.read(currentUserProvider);
                for (final g in selectedItems) {
                  final newShared = <String>{
                    ...g.sharedOrgUnitIds,
                    ...selectedOrgs,
                  }.toList();
                  await ref
                      .read(databaseServiceProvider)
                      .saveActivityGroup(
                        g.copyWith(
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

  void _showApplyModal() {
    final myOrg = ref.read(userOwnedOrgUnitProvider);
    if (myOrg == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final groups = ref.watch(activityGroupsStreamProvider).value ?? [];

            // Activity groups shared with this org unit but not yet applied by it
            final sharedWithMe = groups.where((g) {
              final isShared = g.sharedOrgUnitIds.contains(myOrg.id);
              final isApplied = g.appliedOrgUnitIds.contains(myOrg.id);
              final isOwner = g.ownerOrgUnitId == myOrg.id;
              return isShared && !isApplied && !isOwner;
            }).toList();

            return ApplyModal<ActivityGroupModel>(
              title: 'Apply Activity Groups',
              items: sharedWithMe,
              itemSearchString: (g) => g.name,
              itemId: (g) => g.id,
              onApply: (selectedItems) async {
                final user = ref.read(currentUserProvider);
                for (final g in selectedItems) {
                  final newApplied = <String>{
                    ...g.appliedOrgUnitIds,
                    myOrg.id,
                  }.toList();
                  final newStatusMap = Map<String, String>.from(g.statusMap)
                    ..[myOrg.id] = 'Active';
                  await ref
                      .read(databaseServiceProvider)
                      .saveActivityGroup(
                        g.copyWith(
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

  void _showChangeOrderModal(List<ActivityGroupModel> groups) {
    final localGroups = List<ActivityGroupModel>.from(groups);

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
                child: localGroups.isEmpty
                    ? const Center(child: Text('No activity groups.'))
                    : ReorderableListView.builder(
                        itemCount: localGroups.length,
                        onReorderItem: (oldIndex, newIndex) {
                          setModalState(() {
                            final item = localGroups.removeAt(oldIndex);
                            localGroups.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final g = localGroups[index];
                          return ListTile(
                            key: ValueKey(g.id),
                            title: Row(
                              children: [
                                Text(
                                  '${index + 1}. ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(child: Text(g.name)),
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
                      for (int i = 0; i < localGroups.length; i++) {
                        final g = localGroups[i];
                        final updated = g.copyWith(
                          order: i + 1,
                          lastModifiedBy:
                              ref.read(currentUserProvider)?.email ?? 'system',
                          lastModifiedAt: DateTime.now(),
                        );
                        await db.saveActivityGroup(updated);
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

  Widget _buildStatusChip(
    String status,
    ThemeData theme,
    BuildContext context,
  ) {
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
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isActive ? 'Active' : 'Inactive',
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

  Widget _buildTableSkeleton(ThemeData theme) {
    return Column(
      children: List.generate(3, (index) {
        return Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 0.5,
              ),
              right: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 0.5,
              ),
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 24),
              Container(
                width: 150,
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              Container(
                width: 60,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
