import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/router_paths.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../models/org_unit_model.dart';
import '../../admin/org_admin/org_admin_view.dart' show PageIndicatorInput;
import 'change_ownership_dialog.dart';

class CategoriesListView extends ConsumerStatefulWidget {
  const CategoriesListView({super.key});

  @override
  ConsumerState<CategoriesListView> createState() => _CategoriesListViewState();
}

class _CategoriesListViewState extends ConsumerState<CategoriesListView> {
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

    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final allCategories = categoriesAsync.value ?? [];

    // Filter categories: only show categories owned by myOrg OR applied by myOrg
    final myCategories = allCategories.where((cat) {
      final isOwner = cat.ownerOrgUnitId == myOrg.id;
      final isApplied = cat.appliedOrgUnitIds.contains(myOrg.id);
      if (!isOwner && !isApplied) return false;

      if (_searchQuery.isNotEmpty) {
        return cat.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList()..sort((a, b) => a.order.compareTo(b.order));

    // Pagination
    final totalCategories = myCategories.length;
    const itemsPerPage = 5;
    final maxPage = (totalCategories / itemsPerPage).ceil().clamp(1, 9999);

    if (_currentPage > maxPage) {
      _currentPage = maxPage;
    }

    final displayedCategories = myCategories
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
            'Categories',
            key: const Key('categories_title'),
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
                      key: const Key('category_search_input'),
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search Categories',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          key: const Key('category_search_button'),
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
                  FilledButton.icon(
                    key: const Key('create_category_button'),
                    onPressed: () {
                      context.go(RouterPaths.settingsCategoriesNew);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Category'),
                  ),
                  const SizedBox(width: 8),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: MenuAnchor(
                      key: const Key('category_list_actions_dropdown'),
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
                            key: const Key('category_list_share_item'),
                            onPressed: () {
                              _showShareModal();
                            },
                            child: const Text('Share'),
                          ),
                        ),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: MenuItemButton(
                            key: const Key('category_list_apply_item'),
                            onPressed: () {
                              _showApplyModal();
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: MenuItemButton(
                            key: const Key('category_list_change_order_item'),
                            onPressed: () {
                              _showChangeOrderModal(myCategories);
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
                totalCategories == 0
                    ? '0 of 0'
                    : '${(_currentPage - 1) * 5 + 1}-${((_currentPage * 5) > totalCategories) ? totalCategories : (_currentPage * 5)} of $totalCategories',
                key: const Key('category_pagination_displayed_count'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 16),
              IconButton(
                key: const Key('category_page_back'),
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
                inputKey: const Key('category_pagination_pages_input'),
              ),
              const SizedBox(width: 8),
              Text(
                '/ $maxPage',
                key: const Key('category_pagination_pages'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('category_page_forward'),
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
              if (categoriesAsync.value == null && categoriesAsync.isLoading)
                _buildTableSkeleton(theme)
              else if (displayedCategories.isEmpty)
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
                  child: const Center(child: Text('No categories found.')),
                )
              else
                ListView.builder(
                  key: const Key('category_table'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayedCategories.length,
                  itemBuilder: (context, idx) {
                    final cat = displayedCategories[idx];
                    final catStatus = cat.statusMap[myOrg.id] ?? 'Active';
                    final isOwner = cat.ownerOrgUnitId == myOrg.id;

                    return InkWell(
                      key: Key('category_row_${cat.id}'),
                      onTap: () {
                        context.go(
                          RouterPaths.settingsCategoriesDetailPath(cat.id),
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
                            Expanded(flex: 1, child: Text('${cat.order}')),
                            Expanded(flex: 3, child: Text(cat.name)),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _buildStatusChip(
                                  catStatus,
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
                                      'category_row_edit_button_${cat.id}',
                                    ),
                                    onPressed: () {
                                      context.go(
                                        RouterPaths.settingsCategoriesEditPath(
                                          cat.id,
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
                                        'category_row_overflow_button_${cat.id}',
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
                                              'category_row_toggle_status_item_${cat.id}',
                                            ),
                                            onPressed: () async {
                                              const val = 'toggle';
                                              if (val == 'toggle') {
                                                final newStatus =
                                                    catStatus == 'Active'
                                                    ? 'Inactive'
                                                    : 'Active';
                                                final newStatusMap =
                                                    Map<String, String>.from(
                                                      cat.statusMap,
                                                    )..[myOrg.id] = newStatus;
                                                await ref
                                                    .read(
                                                      databaseServiceProvider,
                                                    )
                                                    .saveCategory(
                                                      cat.copyWith(
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
                                                  initialCategory: cat,
                                                );
                                              } else if (val == 'delete') {
                                                try {
                                                  await ref
                                                      .read(
                                                        databaseServiceProvider,
                                                      )
                                                      .deleteCategory(
                                                        cat.id,
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
                                              catStatus == 'Active'
                                                  ? 'Deactivate'
                                                  : 'Activate',
                                            ),
                                          ),
                                        ),
                                        Directionality(
                                          textDirection: TextDirection.ltr,
                                          child: MenuItemButton(
                                            key: Key(
                                              'category_row_share_item_${cat.id}',
                                            ),
                                            onPressed: () async {
                                              const val = 'share';
                                              if (val == 'toggle') {
                                                final newStatus =
                                                    catStatus == 'Active'
                                                    ? 'Inactive'
                                                    : 'Active';
                                                final newStatusMap =
                                                    Map<String, String>.from(
                                                      cat.statusMap,
                                                    )..[myOrg.id] = newStatus;
                                                await ref
                                                    .read(
                                                      databaseServiceProvider,
                                                    )
                                                    .saveCategory(
                                                      cat.copyWith(
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
                                                  initialCategory: cat,
                                                );
                                              } else if (val == 'delete') {
                                                try {
                                                  await ref
                                                      .read(
                                                        databaseServiceProvider,
                                                      )
                                                      .deleteCategory(
                                                        cat.id,
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
                                              'category_row_delete_item_${cat.id}',
                                            ),
                                            onPressed: () async {
                                              const val = 'delete';
                                              if (val == 'toggle') {
                                                final newStatus =
                                                    catStatus == 'Active'
                                                    ? 'Inactive'
                                                    : 'Active';
                                                final newStatusMap =
                                                    Map<String, String>.from(
                                                      cat.statusMap,
                                                    )..[myOrg.id] = newStatus;
                                                await ref
                                                    .read(
                                                      databaseServiceProvider,
                                                    )
                                                    .saveCategory(
                                                      cat.copyWith(
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
                                                  initialCategory: cat,
                                                );
                                              } else if (val == 'delete') {
                                                try {
                                                  await ref
                                                      .read(
                                                        databaseServiceProvider,
                                                      )
                                                      .deleteCategory(
                                                        cat.id,
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
                                                'category_row_change_ownership_item_${cat.id}',
                                              ),
                                              onPressed: () {
                                                _showChangeOwnershipModal(
                                                  context: context,
                                                  currentOwnerId:
                                                      cat.ownerOrgUnitId,
                                                  resourceName: cat.name,
                                                  onConfirm: (targetOrg) async {
                                                    final updatedCat = cat.copyWith(
                                                      ownerOrgUnitId:
                                                          targetOrg.id,
                                                      sharedOrgUnitIds: <String>{
                                                        ...cat.sharedOrgUnitIds,
                                                        myOrg.id,
                                                      }.toList(),
                                                      appliedOrgUnitIds: <String>{
                                                        ...cat
                                                            .appliedOrgUnitIds,
                                                        myOrg.id,
                                                        targetOrg.id,
                                                      }.toList(),
                                                      statusMap:
                                                          Map<
                                                              String,
                                                              String
                                                            >.from(
                                                              cat.statusMap,
                                                            )
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
                                                        .saveCategory(
                                                          updatedCat,
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

  void _showShareModal({CategoryModel? initialCategory}) {
    final myOrg = ref.read(userOwnedOrgUnitProvider);
    if (myOrg == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final categories = ref.watch(categoriesStreamProvider).value ?? [];
            final orgUnits = ref.watch(orgUnitsStreamProvider).value ?? [];

            // Eligible categories to share: owned by this unit
            final shareableCategories = categories
                .where((c) => c.ownerOrgUnitId == myOrg.id)
                .toList();
            // Other org units to share with
            final targetOrgUnits = orgUnits
                .where((o) => o.id != myOrg.id)
                .toList();

            return ShareWizardModal<CategoryModel>(
              title: 'Select Categories',
              items: shareableCategories,
              itemSearchString: (c) => c.name,
              itemTile: (c, selected, onChanged) => CheckboxListTile(
                title: Text(c.name),
                value: selected,
                onChanged: onChanged,
              ),
              orgUnits: targetOrgUnits,
              initialItem: initialCategory,
              onShare: (selectedItems, selectedOrgs) async {
                final user = ref.read(currentUserProvider);
                for (final cat in selectedItems) {
                  final newShared = <String>{
                    ...cat.sharedOrgUnitIds,
                    ...selectedOrgs,
                  }.toList();
                  await ref
                      .read(databaseServiceProvider)
                      .saveCategory(
                        cat.copyWith(
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
            final categories = ref.watch(categoriesStreamProvider).value ?? [];

            // Categories shared with this org unit but not yet applied by it
            final sharedWithMe = categories.where((c) {
              final isShared = c.sharedOrgUnitIds.contains(myOrg.id);
              final isApplied = c.appliedOrgUnitIds.contains(myOrg.id);
              final isOwner = c.ownerOrgUnitId == myOrg.id;
              return isShared && !isApplied && !isOwner;
            }).toList();

            return ApplyModal<CategoryModel>(
              title: 'Apply Categories',
              items: sharedWithMe,
              itemSearchString: (c) => c.name,
              itemId: (c) => c.id,
              onApply: (selectedItems) async {
                final user = ref.read(currentUserProvider);
                for (final cat in selectedItems) {
                  final newApplied = <String>{
                    ...cat.appliedOrgUnitIds,
                    myOrg.id,
                  }.toList();
                  final newStatusMap = Map<String, String>.from(cat.statusMap)
                    ..[myOrg.id] = 'Active';
                  await ref
                      .read(databaseServiceProvider)
                      .saveCategory(
                        cat.copyWith(
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

  void _showChangeOrderModal(List<CategoryModel> categories) {
    final localCategories = List<CategoryModel>.from(categories);

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
                child: localCategories.isEmpty
                    ? const Center(child: Text('No categories.'))
                    : ReorderableListView.builder(
                        itemCount: localCategories.length,
                        onReorderItem: (oldIndex, newIndex) {
                          setModalState(() {
                            final item = localCategories.removeAt(oldIndex);
                            localCategories.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final c = localCategories[index];
                          return ListTile(
                            key: ValueKey(c.id),
                            title: Row(
                              children: [
                                Text(
                                  '${index + 1}. ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(child: Text(c.name)),
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
                      for (int i = 0; i < localCategories.length; i++) {
                        final c = localCategories[i];
                        final updated = c.copyWith(
                          order: i + 1,
                          lastModifiedBy:
                              ref.read(currentUserProvider)?.email ?? 'system',
                          lastModifiedAt: DateTime.now(),
                        );
                        await db.saveCategory(updated);
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

// Reusable components for Share Wizard and Apply modals
class ShareWizardModal<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) itemSearchString;
  final Widget Function(T, bool, ValueChanged<bool?>) itemTile;
  final List<OrgUnitModel> orgUnits;
  final T? initialItem;
  final Future<void> Function(List<T>, List<String>) onShare;

  const ShareWizardModal({
    super.key,
    required this.title,
    required this.items,
    required this.itemSearchString,
    required this.itemTile,
    required this.orgUnits,
    this.initialItem,
    required this.onShare,
  });

  @override
  State<ShareWizardModal<T>> createState() => ShareWizardModalState<T>();
}

class ShareWizardModalState<T> extends State<ShareWizardModal<T>> {
  int _step = 1; // 1: Select Items, 2: Select Org Units
  final List<T> _selectedItems = [];
  final List<String> _selectedOrgs = [];
  String _itemSearchQuery = '';
  String _orgSearchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialItem != null) {
      _selectedItems.add(widget.initialItem as T);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPage1 = _step == 1;

    final filteredItems = widget.items.where((item) {
      final q = _itemSearchQuery.trim().toLowerCase();
      if (q.isEmpty) return true;
      return widget.itemSearchString(item).toLowerCase().contains(q);
    }).toList();

    final filteredOrgs = widget.orgUnits.where((org) {
      final q = _orgSearchQuery.trim().toLowerCase();
      if (q.isEmpty) return true;
      return org.name.toLowerCase().contains(q) ||
          org.abbreviation.toLowerCase().contains(q);
    }).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(
        isPage1 ? widget.title : 'Select Organization Units',
        key: Key(
          isPage1 ? 'share_modal_title_step1' : 'share_modal_title_step2',
        ),
      ),
      content: SizedBox(
        width: 450,
        height: 400,
        child: Column(
          children: [
            TextField(
              key: Key(
                isPage1
                    ? 'share_modal_search_step1'
                    : 'share_modal_search_step2',
              ),
              decoration: InputDecoration(
                labelText: isPage1
                    ? 'Search items'
                    : 'Search organization units',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  if (isPage1) {
                    _itemSearchQuery = val;
                  } else {
                    _orgSearchQuery = val;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isPage1
                  ? (filteredItems.isEmpty
                        ? const Center(child: Text('No items available.'))
                        : ListView.builder(
                            itemCount: filteredItems.length,
                            itemBuilder: (context, idx) {
                              final item = filteredItems[idx];
                              final isSel = _selectedItems.contains(item);
                              return widget.itemTile(item, isSel, (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedItems.add(item);
                                  } else {
                                    _selectedItems.remove(item);
                                  }
                                });
                              });
                            },
                          ))
                  : (filteredOrgs.isEmpty
                        ? const Center(
                            child: Text('No organization units available.'),
                          )
                        : ListView.builder(
                            itemCount: filteredOrgs.length,
                            itemBuilder: (context, idx) {
                              final org = filteredOrgs[idx];
                              final isSel = _selectedOrgs.contains(org.id);
                              return CheckboxListTile(
                                key: Key('share_modal_row_${org.id}'),
                                title: Text(
                                  '${org.name} (${org.abbreviation})',
                                ),
                                value: isSel,
                                activeColor: theme.colorScheme.primary,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedOrgs.add(org.id);
                                    } else {
                                      _selectedOrgs.remove(org.id);
                                    }
                                  });
                                },
                              );
                            },
                          )),
            ),
          ],
        ),
      ),
      actions: [
        if (isPage1) ...[
          OutlinedButton(
            key: const Key('share_modal_cancel_button'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('share_modal_next_button'),
            onPressed: _selectedItems.isNotEmpty
                ? () => setState(() => _step = 2)
                : null,
            child: const Text('Next'),
          ),
        ] else ...[
          OutlinedButton(
            key: const Key('share_modal_back_button'),
            onPressed: () => setState(() => _step = 1),
            child: const Text('Back'),
          ),
          FilledButton(
            key: const Key('share_modal_share_button'),
            onPressed: _selectedOrgs.isNotEmpty
                ? () async {
                    await widget.onShare(_selectedItems, _selectedOrgs);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                : null,
            child: const Text('Share'),
          ),
        ],
      ],
    );
  }
}

class ApplyModal<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) itemSearchString;
  final String Function(T) itemId;
  final Future<void> Function(List<T>) onApply;

  const ApplyModal({
    super.key,
    required this.title,
    required this.items,
    required this.itemSearchString,
    required this.itemId,
    required this.onApply,
  });

  @override
  State<ApplyModal<T>> createState() => ApplyModalState<T>();
}

class ApplyModalState<T> extends State<ApplyModal<T>> {
  final List<T> _selectedItems = [];
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredItems = widget.items.where((item) {
      final q = _searchQuery.trim().toLowerCase();
      if (q.isEmpty) return true;
      return widget.itemSearchString(item).toLowerCase().contains(q);
    }).toList();

    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(widget.title, key: const Key('apply_modal_title')),
      content: SizedBox(
        width: 450,
        height: 400,
        child: Column(
          children: [
            TextField(
              key: const Key('apply_modal_search'),
              decoration: InputDecoration(
                labelText: 'Search shared items',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredItems.isEmpty
                  ? const Center(child: Text('No shared items to apply.'))
                  : ListView.builder(
                      itemCount: filteredItems.length,
                      itemBuilder: (context, idx) {
                        final item = filteredItems[idx];
                        final isSel = _selectedItems.contains(item);
                        return CheckboxListTile(
                          key: Key('apply_modal_row_${widget.itemId(item)}'),
                          title: Text(widget.itemSearchString(item)),
                          value: isSel,
                          activeColor: theme.colorScheme.primary,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedItems.add(item);
                              } else {
                                _selectedItems.remove(item);
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
        OutlinedButton(
          key: const Key('apply_modal_cancel_button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('apply_modal_save_button'),
          onPressed: _selectedItems.isNotEmpty
              ? () async {
                  await widget.onApply(_selectedItems);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

Widget _buildStatusChip(String status, ThemeData theme, BuildContext context) {
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
