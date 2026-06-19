import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/router_paths.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../models/user_model.dart';
import '../../../models/org_unit_model.dart';

final _usersStreamProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  return ref.watch(databaseServiceProvider).watchUsers();
});

final _orgsStreamProvider = StreamProvider.autoDispose<List<OrgUnitModel>>((
  ref,
) {
  return ref.watch(databaseServiceProvider).watchOrgUnits();
});

final _orgStreamProvider = StreamProvider.autoDispose
    .family<OrgUnitModel?, String>((ref, id) {
      return ref.watch(databaseServiceProvider).watchOrgUnit(id);
    });

class OrgDetailView extends ConsumerStatefulWidget {
  final String id;
  const OrgDetailView({super.key, required this.id});

  @override
  ConsumerState<OrgDetailView> createState() => _OrgDetailViewState();
}

class _OrgDetailViewState extends ConsumerState<OrgDetailView> {
  final _employeeSearchController = TextEditingController();
  final _childSearchController = TextEditingController();
  final _childIdInputController = TextEditingController(text: 'CHILD_DEPT');
  String _employeeQuery = '';
  String _childQuery = '';
  final String _orgErrorMessage = '';

  bool _formInitialized = false;
  late TextEditingController _nameController;
  late TextEditingController _abbrevController;
  String? _selectedType;
  String? _selectedHeadEmail;
  String? _selectedParentId;
  bool _statusValue = true;
  String _formErrorMessage = '';
  String? _lastLoc;
  String? _lastOrgId;

  int _employeePage = 1;
  int _childPage = 1;

  String? _employeeStatusFilter;
  String? _employeeRoleFilter;
  String? _childTypeFilter;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _abbrevController = TextEditingController();
  }

  @override
  void didUpdateWidget(OrgDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _formInitialized = false;
      _employeePage = 1;
      _childPage = 1;
      _employeeSearchController.clear();
      _childSearchController.clear();
      _employeeQuery = '';
      _childQuery = '';
      _employeeStatusFilter = null;
      _employeeRoleFilter = null;
      _childTypeFilter = null;
    }
  }

  @override
  void dispose() {
    _employeeSearchController.dispose();
    _childSearchController.dispose();
    _childIdInputController.dispose();
    _nameController.dispose();
    _abbrevController.dispose();
    super.dispose();
  }

  bool _wouldCreateCycle(
    String childId,
    String parentId,
    List<OrgUnitModel> allOrgs,
  ) {
    if (childId == parentId) return true;
    String? current = parentId;
    while (current != null) {
      if (current == childId) return true;
      final parent = allOrgs.cast<OrgUnitModel?>().firstWhere(
        (o) => o?.id == current,
        orElse: () => null,
      );
      if (parent == null) break;
      current = parent.parentId;
    }
    return false;
  }

  void _showHeadOfSelectionModal(List<UserModel> users) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String query = '';
        String? localSelectedEmail = _selectedHeadEmail;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredUsers = users.where((u) {
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
              title: const Text('Select Head Of'),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      key: const Key('user_modal_search_input'),
                      decoration: InputDecoration(
                        labelText: 'Search Users',
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
                      child: ListView.builder(
                        itemCount: filteredUsers.length + 1,
                        itemBuilder: (context, idx) {
                          if (idx == 0) {
                            final isSelected = localSelectedEmail == null;
                            return ListTile(
                              title: const Text('None'),
                              selected: isSelected,
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle,
                                      color: theme.colorScheme.primary,
                                    )
                                  : null,
                              onTap: () {
                                setDialogState(() {
                                  localSelectedEmail = null;
                                });
                              },
                            );
                          }
                          final u = filteredUsers[idx - 1];
                          final isSelected = u.email == localSelectedEmail;
                          return ListTile(
                            title: Text(u.fullName),
                            subtitle: Text(u.email),
                            selected: isSelected,
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                            onTap: () {
                              setDialogState(() {
                                localSelectedEmail = u.email;
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
                  key: const Key('user_modal_cancel_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('user_modal_select_button'),
                  onPressed: () {
                    setState(() {
                      _selectedHeadEmail = localSelectedEmail;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddChildModal(List<OrgUnitModel> allOrgs, OrgUnitModel org) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String query = '';
        OrgUnitModel? localSelectedUnit;
        String modalError = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredOrgs = allOrgs.where((o) {
              if (o.id == org.id) return false;
              if (org.childIds.contains(o.id)) return false;
              if (o.type.toLowerCase() == 'md division') return false;
              final q = query.trim().toLowerCase();
              if (q.isNotEmpty &&
                  !o.name.toLowerCase().contains(q) &&
                  !o.abbreviation.toLowerCase().contains(q) &&
                  !o.id.toLowerCase().contains(q)) {
                return false;
              }
              return true;
            }).toList();

            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: const Text('Add Child Organization Unit'),
              content: SizedBox(
                width: 400,
                height: 450,
                child: Column(
                  children: [
                    TextField(
                      key: const Key('child_modal_search_input'),
                      decoration: InputDecoration(
                        labelText: 'Search Org Units',
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
                      child: filteredOrgs.isEmpty
                          ? const Center(
                              child: Text('No matching organization units.'),
                            )
                          : ListView.builder(
                              itemCount: filteredOrgs.length,
                              itemBuilder: (context, idx) {
                                final o = filteredOrgs[idx];
                                final isSelected =
                                    localSelectedUnit?.id == o.id;
                                return ListTile(
                                  key: Key('child_modal_row_${o.id}'),
                                  title: Text(o.name),
                                  subtitle: Text(
                                    '${formatOrgType(o.type)} (${o.abbreviation})',
                                  ),
                                  selected: isSelected,
                                  trailing: isSelected
                                      ? Icon(
                                          Icons.check_circle,
                                          color: theme.colorScheme.primary,
                                        )
                                      : null,
                                  onTap: () {
                                    setDialogState(() {
                                      localSelectedUnit = o;
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    if (modalError.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        modalError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  key: const Key('child_modal_cancel_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('child_modal_save_button'),
                  onPressed: localSelectedUnit == null
                      ? null
                      : () async {
                          final childId = localSelectedUnit!.id;

                          if (_wouldCreateCycle(childId, org.id, allOrgs)) {
                            setDialogState(() {
                              modalError =
                                  'Cycle detected: Circular hierarchy not allowed.';
                            });
                            return;
                          }

                          if (localSelectedUnit!.parentId != null &&
                              localSelectedUnit!.parentId != org.id) {
                            setDialogState(() {
                              modalError =
                                  'Constraint error: Non-MD division can have at most one parent.';
                            });
                            return;
                          }

                          try {
                            final updatedChild = localSelectedUnit!.copyWith(
                              parentId: () => org.id,
                            );
                            await ref
                                .read(databaseServiceProvider)
                                .saveOrgUnit(updatedChild);

                            final updatedParent = org.copyWith(
                              childIds: [...org.childIds, childId],
                            );
                            await ref
                                .read(databaseServiceProvider)
                                .saveOrgUnit(updatedParent);

                            final updatedParentFromDb = await ref
                                .read(databaseServiceProvider)
                                .getOrgUnit(org.id);
                            if (updatedParentFromDb != null) {
                              ref
                                      .read(
                                        selectedOrgForDetailsProvider.notifier,
                                      )
                                      .state =
                                  updatedParentFromDb;
                            }
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                            setState(() {});
                          } catch (e) {
                            setDialogState(() {
                              modalError = e.toString();
                            });
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

  void _showAddUserModal(List<UserModel> allUsers, OrgUnitModel org) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String query = '';
        final localSelectedUsers = <UserModel>{};

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredUsers = allUsers.where((u) {
              if (u.orgUnitId == org.id) return false;
              final q = query.trim().toLowerCase();
              if (q.isNotEmpty &&
                  !u.fullName.toLowerCase().contains(q) &&
                  !u.email.toLowerCase().contains(q)) {
                return false;
              }
              return true;
            }).toList();

            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: const Text('Add Users to Organization Unit'),
              content: SizedBox(
                width: 400,
                height: 450,
                child: Column(
                  children: [
                    TextField(
                      key: const Key('user_add_modal_search_input'),
                      decoration: InputDecoration(
                        labelText: 'Search Users',
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
                          ? const Center(child: Text('No matching users.'))
                          : ListView.builder(
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, idx) {
                                final u = filteredUsers[idx];
                                final isSelected = localSelectedUsers.contains(
                                  u,
                                );
                                return CheckboxListTile(
                                  key: Key('user_add_modal_row_${u.id}'),
                                  title: Text(u.fullName),
                                  subtitle: Text(u.email),
                                  value: isSelected,
                                  activeColor: theme.colorScheme.primary,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        localSelectedUsers.add(u);
                                      } else {
                                        localSelectedUsers.remove(u);
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
                  key: const Key('user_add_modal_cancel_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('user_add_modal_save_button'),
                  onPressed: localSelectedUsers.isEmpty
                      ? null
                      : () async {
                          try {
                            for (final u in localSelectedUsers) {
                              final updatedUser = u.copyWith(
                                orgUnitId: () => org.id,
                              );
                              await ref
                                  .read(databaseServiceProvider)
                                  .saveUser(updatedUser);
                              final currentUser = ref.read(currentUserProvider);
                              if (currentUser != null &&
                                  currentUser.email == updatedUser.email) {
                                ref.read(currentUserProvider.notifier).state =
                                    updatedUser;
                              }
                            }
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                            setState(() {});
                          } catch (e) {
                            // handle error
                          }
                        },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showParentSelectionModal(List<OrgUnitModel> allOrgs, OrgUnitModel org) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String query = '';
        String? localSelectedId = _selectedParentId;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredOrgs = allOrgs.where((o) {
              if (o.id == org.id) return false;
              final q = query.trim().toLowerCase();
              if (q.isEmpty) return true;
              return o.name.toLowerCase().contains(q) ||
                  o.abbreviation.toLowerCase().contains(q) ||
                  o.id.toLowerCase().contains(q);
            }).toList();

            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: const Text('Select Parent Org Unit'),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      key: const Key('parent_modal_search_input'),
                      decoration: InputDecoration(
                        labelText: 'Search Org Units',
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
                      child: ListView.builder(
                        itemCount: filteredOrgs.length + 1,
                        itemBuilder: (context, idx) {
                          if (idx == 0) {
                            final isSelected = localSelectedId == null;
                            return ListTile(
                              title: const Text('None (Root)'),
                              selected: isSelected,
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle,
                                      color: theme.colorScheme.primary,
                                    )
                                  : null,
                              onTap: () {
                                setDialogState(() {
                                  localSelectedId = null;
                                });
                              },
                            );
                          }
                          final o = filteredOrgs[idx - 1];
                          final isSelected = o.id == localSelectedId;
                          return ListTile(
                            title: Text(o.name),
                            subtitle: Text(
                              '${formatOrgType(o.type)} (${o.abbreviation})',
                            ),
                            selected: isSelected,
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                            onTap: () {
                              setDialogState(() {
                                localSelectedId = o.id;
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
                  key: const Key('parent_modal_cancel_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('parent_modal_select_button'),
                  onPressed: () {
                    setState(() {
                      _selectedParentId = localSelectedId;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Select'),
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
    final orgAsync = ref.watch(_orgStreamProvider(widget.id));
    final org = orgAsync.value ?? ref.watch(selectedOrgForDetailsProvider);
    final loc = GoRouterState.of(context).matchedLocation;
    final isEditing = loc.endsWith('/edit');

    if (org == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFFFFF),
        body: Center(child: Text('No Org Unit Selected')),
      );
    }

    if (!_formInitialized || org.id != _lastOrgId || _lastLoc != loc) {
      _nameController.text = org.name;
      _abbrevController.text = org.abbreviation;
      _selectedType = formatOrgType(org.type);
      _selectedHeadEmail = org.headOfEmail;
      _selectedParentId = org.parentId;
      _statusValue = org.status == 'Active';
      _formErrorMessage = '';
      _lastOrgId = org.id;
      _lastLoc = loc;
      _formInitialized = true;
    }

    // Load related data
    final usersAsync = ref.watch(_usersStreamProvider);
    final allUsers = usersAsync.value ?? <UserModel>[];

    final assignedEmployees = allUsers
        .where(
          (u) =>
              u.orgUnitId == org.id &&
              (_employeeQuery.isEmpty ||
                  u.fullName.toLowerCase().contains(
                    _employeeQuery.toLowerCase(),
                  )) &&
              (_employeeStatusFilter == null ||
                  u.status == _employeeStatusFilter) &&
              (_employeeRoleFilter == null || u.role == _employeeRoleFilter),
        )
        .toList();

    final orgsAsync = ref.watch(_orgsStreamProvider);
    final allOrgs = orgsAsync.value ?? [];

    final childOrgs = allOrgs
        .where(
          (o) =>
              org.childIds.contains(o.id) &&
              (_childQuery.isEmpty ||
                  o.name.toLowerCase().contains(_childQuery.toLowerCase())) &&
              (_childTypeFilter == null || o.type == _childTypeFilter),
        )
        .toList();

    // Employee Pagination
    final totalEmployees = assignedEmployees.length;
    const empItemsPerPage = 5;
    final maxEmpPage = (totalEmployees / empItemsPerPage).ceil().clamp(1, 9999);
    if (_employeePage > maxEmpPage) {
      _employeePage = maxEmpPage;
    }
    final displayedEmployees = assignedEmployees
        .skip((_employeePage - 1) * empItemsPerPage)
        .take(empItemsPerPage)
        .toList();

    // Child Org Pagination
    final totalChildren = childOrgs.length;
    const childItemsPerPage = 5;
    final maxChildPage = (totalChildren / childItemsPerPage).ceil().clamp(
      1,
      9999,
    );
    if (_childPage > maxChildPage) {
      _childPage = maxChildPage;
    }
    final displayedChildren = childOrgs
        .skip((_childPage - 1) * childItemsPerPage)
        .take(childItemsPerPage)
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
                    label: 'Organization Units',
                    linkKey: const Key('org_detail_back_button'),
                    onTap: () => context.go(RouterPaths.adminOrgs),
                  ),
                  Text(
                    ' / ${org.name}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      org.name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isEditing) ...[
                            FilledButton(
                              key: const Key('org_detail_edit_button'),
                              onPressed: () {
                                context.go(
                                  RouterPaths.adminOrgEditPath(widget.id),
                                );
                              },
                              child: const Text('Edit'),
                            ),
                            const SizedBox(width: 8),
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: MenuAnchor(
                                key: const Key('org_detail_overflow_button'),
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
                                      onPressed: () async {
                                        final newStatus = org.status == 'Active'
                                            ? 'Inactive'
                                            : 'Active';
                                        await ref
                                            .read(databaseServiceProvider)
                                            .saveOrgUnit(
                                              org.copyWith(
                                                status: newStatus,
                                                lastModifiedBy:
                                                    ref
                                                        .read(
                                                          currentUserProvider,
                                                        )
                                                        ?.email ??
                                                    'system',
                                                lastModifiedAt: DateTime.now(),
                                              ),
                                            );
                                      },
                                      child: Text(
                                        org.status == 'Active'
                                            ? 'Deactivate'
                                            : 'Active',
                                      ),
                                    ),
                                  ),
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: MenuItemButton(
                                      onPressed: () async {
                                        await ref
                                            .read(databaseServiceProvider)
                                            .deleteOrgUnit(org.id);
                                        if (context.mounted) {
                                          context.go(RouterPaths.adminOrgs);
                                        }
                                      },
                                      child: const Text('Delete'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            OutlinedButton(
                              key: const Key('org_detail_cancel_button'),
                              onPressed: () {
                                context.go(
                                  RouterPaths.adminOrgDetailPath(widget.id),
                                );
                              },
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              key: const Key('org_detail_save_button'),
                              onPressed: () async {
                                try {
                                  final updated = org.copyWith(
                                    name: _nameController.text,
                                    abbreviation: _abbrevController.text,
                                    type: _selectedType?.toLowerCase(),
                                    headOfEmail: _selectedHeadEmail,
                                    parentId: () => _selectedParentId,
                                    status: _statusValue
                                        ? 'Active'
                                        : 'Inactive',
                                    lastModifiedBy:
                                        ref.read(currentUserProvider)?.email ??
                                        'system',
                                    lastModifiedAt: DateTime.now(),
                                  );
                                  await ref
                                      .read(databaseServiceProvider)
                                      .saveOrgUnit(updated);
                                  if (context.mounted) {
                                    context.go(
                                      RouterPaths.adminOrgDetailPath(widget.id),
                                    );
                                  }
                                } on OrgUnitCycleException catch (e) {
                                  setState(() => _formErrorMessage = e.message);
                                } catch (e) {
                                  setState(
                                    () => _formErrorMessage = e.toString(),
                                  );
                                }
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Fields Container (width 400)
              SizedBox(
                width: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isEditing) ...[
                      Text(
                        'Status',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        key: const Key('org_detail_status_input'),
                        child: _buildStatusChip(
                          _statusValue ? 'Active' : 'Inactive',
                          theme,
                          context,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('org_detail_name_input'),
                        controller: _nameController,
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Color(0xFFFFF9C4),
                          label: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: 'Name'),
                                TextSpan(
                                  text: ' *',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('org_detail_abbrev_input'),
                        controller: _abbrevController,
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Color(0xFFFFF9C4),
                          label: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: 'Abbreviation'),
                                TextSpan(
                                  text: ' *',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      MenuAnchor(
                        key: const Key('org_detail_type_input'),
                        builder: (context, controller, child) {
                          return InkWell(
                            onTap: () {
                              if (controller.isOpen) {
                                controller.close();
                              } else {
                                controller.open();
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Type',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.arrow_drop_down),
                              ),
                              child: Text(
                                _selectedType ?? '',
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          );
                        },
                        menuChildren:
                            const [
                              'MD Division',
                              'SVP Division',
                              'VP Division',
                              'Department',
                              'Group',
                              'Team',
                            ].map((item) {
                              return MenuItemButton(
                                onPressed: () =>
                                    setState(() => _selectedType = item),
                                child: Text(item),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 16),
                      (() {
                        final selectedUser = allUsers
                            .cast<UserModel?>()
                            .firstWhere(
                              (u) => u?.email == _selectedHeadEmail,
                              orElse: () => null,
                            );
                        return GestureDetector(
                          key: const Key('org_detail_head_input'),
                          onTap: () => _showHeadOfSelectionModal(allUsers),
                          child: AbsorbPointer(
                            child: TextField(
                              controller: TextEditingController(
                                text: selectedUser != null
                                    ? '${selectedUser.fullName} (${selectedUser.email})'
                                    : 'None',
                              ),
                              decoration: InputDecoration(
                                labelText: getHeadOfLabel(
                                  _selectedType ?? org.type,
                                ),
                                border: const OutlineInputBorder(),
                                suffixIcon: const Icon(Icons.arrow_drop_down),
                              ),
                            ),
                          ),
                        );
                      })(),
                      const SizedBox(height: 16),
                      (() {
                        final selectedParent = allOrgs
                            .cast<OrgUnitModel?>()
                            .firstWhere(
                              (o) => o?.id == _selectedParentId,
                              orElse: () => null,
                            );
                        return GestureDetector(
                          key: const Key('org_detail_parent_input'),
                          onTap: () => _showParentSelectionModal(allOrgs, org),
                          child: AbsorbPointer(
                            child: TextField(
                              controller: TextEditingController(
                                text: selectedParent != null
                                    ? selectedParent.name
                                    : 'None (Root)',
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Parent Org Unit',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.arrow_drop_down),
                              ),
                            ),
                          ),
                        );
                      })(),
                      if (_formErrorMessage.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          _formErrorMessage,
                          key: const Key('org_detail_error_text'),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                    ] else ...[
                      AbsorbPointer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status',
                                  key: const Key('org_detail_status_label'),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildStatusChip(org.status, theme, context),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('org_detail_name'),
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(text: org.name),
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('org_detail_abbrev'),
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(
                                text: org.abbreviation,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Abbreviation',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('org_detail_type'),
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(
                                text: formatOrgType(org.type),
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Type',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('org_detail_head'),
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(
                                text: org.headOfEmail,
                              ),
                              decoration: InputDecoration(
                                labelText: getHeadOfLabel(org.type),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(
                                text: org.parentId != null
                                    ? allOrgs
                                          .firstWhere(
                                            (o) => o.id == org.parentId,
                                            orElse: () => org,
                                          )
                                          .name
                                    : 'None (Root)',
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Parent Org Unit',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('org_detail_created_by'),
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(
                                text: org.createdBy,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Created By',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('org_detail_created_at'),
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(
                                text: org.createdAt.toLocal().toString().split(
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
                              key: const Key('org_detail_last_modified_by'),
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(
                                text: org.lastModifiedBy,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Last Modified By',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('org_detail_last_modified_at'),
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(
                                text: org.lastModifiedAt
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
                    ],
                  ],
                ),
              ),
              if (!isEditing) ...[
                const SizedBox(height: 24),
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
                              key: const Key('org_employee_search_input'),
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
                                  key: const Key('org_employee_search_button'),
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
                      if (!isEditing)
                        FilledButton(
                          key: const Key('org_add_employee_button'),
                          onPressed: () => _showAddUserModal(allUsers, org),
                          child: const Text('Add User'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Employee Filters & Pagination Row
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
                                  'org_employee_filter_status_dropdown',
                                ),
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_employeeStatusFilter ?? 'Status'),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_drop_down, size: 18),
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
                                  'org_employee_filter_status_all_item',
                                ),
                                onPressed: () => setState(() {
                                  _employeeStatusFilter = null;
                                  _employeePage = 1;
                                }),
                                child: const Text('All'),
                              ),
                              MenuItemButton(
                                key: const Key(
                                  'org_employee_filter_status_active_item',
                                ),
                                onPressed: () => setState(() {
                                  _employeeStatusFilter = 'Active';
                                  _employeePage = 1;
                                }),
                                child: const Text('Active'),
                              ),
                              MenuItemButton(
                                key: const Key(
                                  'org_employee_filter_status_inactive_item',
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
                                  'org_employee_filter_role_dropdown',
                                ),
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(roleLabel),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_drop_down, size: 18),
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
                                  'org_employee_filter_role_all_item',
                                ),
                                onPressed: () => setState(() {
                                  _employeeRoleFilter = null;
                                  _employeePage = 1;
                                }),
                                child: const Text('All'),
                              ),
                              MenuItemButton(
                                key: const Key(
                                  'org_employee_filter_role_admin_item',
                                ),
                                onPressed: () => setState(() {
                                  _employeeRoleFilter = 'Administrator';
                                  _employeePage = 1;
                                }),
                                child: const Text('Admin'),
                              ),
                              MenuItemButton(
                                key: const Key(
                                  'org_employee_filter_role_user_item',
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
                              'org_employee_pagination_displayed_count',
                            ),
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            key: const Key('org_employee_page_back'),
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
                              'org_employee_pagination_pages_input',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '/ $maxEmpPage',
                            key: const Key('org_employee_pagination_pages'),
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            key: const Key('org_employee_page_forward'),
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
                          SizedBox(width: 180),
                        ],
                      ),
                    ),
                    if (displayedEmployees.isEmpty)
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
                        child: const Center(
                          child: Text('No employees assigned.'),
                        ),
                      )
                    else
                      ListView.builder(
                        key: const Key('org_employees_table'),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayedEmployees.length,
                        itemBuilder: (context, idx) {
                          final employee = displayedEmployees[idx];
                          return InkWell(
                            key: Key('org_employee_row_${employee.email}'),
                            onTap: () {
                              ref
                                      .read(
                                        selectedUserForDetailsProvider.notifier,
                                      )
                                      .state =
                                  employee;
                              context.go(
                                RouterPaths.adminUserDetailPath(employee.email),
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
                                    width: 180,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        FilledButton(
                                          key: Key(
                                            'org_employee_edit_button_${employee.email}',
                                          ),
                                          onPressed: () {
                                            ref
                                                    .read(
                                                      selectedUserForDetailsProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                employee;
                                            context.go(
                                              RouterPaths.adminUserEditPath(
                                                employee.email,
                                              ),
                                            );
                                          },
                                          child: const Text('Edit'),
                                        ),
                                        Directionality(
                                          textDirection: TextDirection.rtl,
                                          child: MenuAnchor(
                                            key: Key(
                                              'org_employee_overflow_button_${employee.email}',
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
                                                textDirection:
                                                    TextDirection.ltr,
                                                child: MenuItemButton(
                                                  key: Key(
                                                    'org_employee_remove_button_${employee.email}',
                                                  ),
                                                  onPressed: () async {
                                                    final updated = UserModel(
                                                      id: employee.id,
                                                      fullName:
                                                          employee.fullName,
                                                      email: employee.email,
                                                      title: employee.title,
                                                      orgUnitId: null,
                                                      status: employee.status,
                                                      role: employee.role,
                                                    );
                                                    await ref
                                                        .read(
                                                          databaseServiceProvider,
                                                        )
                                                        .saveUser(updated);
                                                    setState(() {});
                                                  },
                                                  child: const Text('Remove'),
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
                if (org.type.toLowerCase() != 'team') ...[
                  const SizedBox(height: 32),
                  // Child Units Section
                  Text(
                    'Child Organization Units',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_orgErrorMessage.isNotEmpty) ...[
                    Text(
                      _orgErrorMessage,
                      key: const Key('org_detail_error_text'),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Child Units Search & Add Row
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
                                key: const Key('org_child_search_input'),
                                controller: _childSearchController,
                                decoration: InputDecoration(
                                  labelText: 'Search Child Units',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  suffixIcon: IconButton(
                                    key: const Key('org_child_search_button'),
                                    icon: const Icon(Icons.search),
                                    onPressed: () {
                                      setState(() {
                                        _childQuery =
                                            _childSearchController.text;
                                        _childPage = 1;
                                      });
                                    },
                                  ),
                                ),
                                onSubmitted: (val) {
                                  setState(() {
                                    _childQuery = val;
                                    _childPage = 1;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        FilledButton(
                          key: const Key('org_add_child_button'),
                          onPressed: org.type.toLowerCase() == 'team'
                              ? null
                              : () => _showAddChildModal(allOrgs, org),
                          child: const Text('Add Child'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Child Units Filters & Pagination Row
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        MenuAnchor(
                          builder: (context, controller, childWidget) {
                            return FilterChip(
                              key: const Key('org_child_filter_type_dropdown'),
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _childTypeFilter != null
                                        ? formatOrgType(_childTypeFilter!)
                                        : 'Type',
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_drop_down, size: 18),
                                ],
                              ),
                              selected: _childTypeFilter != null,
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
                              key: const Key('org_child_filter_type_all_item'),
                              onPressed: () => setState(() {
                                _childTypeFilter = null;
                                _childPage = 1;
                              }),
                              child: const Text('All'),
                            ),
                            MenuItemButton(
                              key: const Key('org_child_filter_type_md_item'),
                              onPressed: () => setState(() {
                                _childTypeFilter = 'md division';
                                _childPage = 1;
                              }),
                              child: const Text('MD Division'),
                            ),
                            MenuItemButton(
                              key: const Key('org_child_filter_type_svp_item'),
                              onPressed: () => setState(() {
                                _childTypeFilter = 'svp division';
                                _childPage = 1;
                              }),
                              child: const Text('SVP Division'),
                            ),
                            MenuItemButton(
                              key: const Key('org_child_filter_type_vp_item'),
                              onPressed: () => setState(() {
                                _childTypeFilter = 'vp division';
                                _childPage = 1;
                              }),
                              child: const Text('VP Division'),
                            ),
                            MenuItemButton(
                              key: const Key('org_child_filter_type_dept_item'),
                              onPressed: () => setState(() {
                                _childTypeFilter = 'department';
                                _childPage = 1;
                              }),
                              child: const Text('Department'),
                            ),
                            MenuItemButton(
                              key: const Key(
                                'org_child_filter_type_group_item',
                              ),
                              onPressed: () => setState(() {
                                _childTypeFilter = 'group';
                                _childPage = 1;
                              }),
                              child: const Text('Group'),
                            ),
                            MenuItemButton(
                              key: const Key('org_child_filter_type_team_item'),
                              onPressed: () => setState(() {
                                _childTypeFilter = 'team';
                                _childPage = 1;
                              }),
                              child: const Text('Team'),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              totalChildren == 0
                                  ? '0 of 0'
                                  : '${(_childPage - 1) * 5 + 1}-${((_childPage * 5) > totalChildren) ? totalChildren : (_childPage * 5)} of $totalChildren',
                              key: const Key(
                                'org_child_pagination_displayed_count',
                              ),
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              key: const Key('org_child_page_back'),
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _childPage > 1
                                  ? () => setState(() => _childPage--)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            PageIndicatorInput(
                              currentPage: _childPage,
                              maxPage: maxChildPage,
                              onPageChanged: (page) =>
                                  setState(() => _childPage = page),
                              inputKey: const Key(
                                'org_child_pagination_pages_input',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '/ $maxChildPage',
                              key: const Key('org_child_pagination_pages'),
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              key: const Key('org_child_page_forward'),
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _childPage < maxChildPage
                                  ? () => setState(() => _childPage++)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Child Units Table
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
                                'Abbreviation',
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
                            SizedBox(width: 180),
                          ],
                        ),
                      ),
                      if (displayedChildren.isEmpty)
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
                          child: const Center(
                            child: Text('No child units assigned.'),
                          ),
                        )
                      else
                        ListView.builder(
                          key: const Key('org_children_table'),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: displayedChildren.length,
                          itemBuilder: (context, idx) {
                            final child = displayedChildren[idx];
                            return InkWell(
                              key: Key('org_child_row_${child.id}'),
                              onTap: () {
                                ref
                                        .read(
                                          selectedOrgForDetailsProvider
                                              .notifier,
                                        )
                                        .state =
                                    child;
                                context.go(
                                  RouterPaths.adminOrgDetailPath(child.id),
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
                                    Expanded(flex: 3, child: Text(child.name)),
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: _buildStatusChip(
                                          child.status,
                                          theme,
                                          context,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(child.abbreviation),
                                    ),
                                    Expanded(flex: 2, child: Text(child.type)),
                                    SizedBox(
                                      width: 180,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          FilledButton(
                                            key: Key(
                                              'org_child_edit_button_${child.id}',
                                            ),
                                            onPressed: () {
                                              ref
                                                      .read(
                                                        selectedOrgForDetailsProvider
                                                            .notifier,
                                                      )
                                                      .state =
                                                  child;
                                              context.go(
                                                RouterPaths.adminOrgEditPath(
                                                  child.id,
                                                ),
                                              );
                                            },
                                            child: const Text('Edit'),
                                          ),
                                          Directionality(
                                            textDirection: TextDirection.rtl,
                                            child: MenuAnchor(
                                              key: Key(
                                                'org_child_overflow_button_${child.id}',
                                              ),
                                              builder:
                                                  (
                                                    context,
                                                    controller,
                                                    childWidget,
                                                  ) {
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
                                                  textDirection:
                                                      TextDirection.ltr,
                                                  child: MenuItemButton(
                                                    key: Key(
                                                      'org_child_remove_parent_button_${child.id}',
                                                    ),
                                                    onPressed: () async {
                                                      final updatedChild = child
                                                          .copyWith(
                                                            parentId: () =>
                                                                null,
                                                          );
                                                      await ref
                                                          .read(
                                                            databaseServiceProvider,
                                                          )
                                                          .saveOrgUnit(
                                                            updatedChild,
                                                          );

                                                      final updatedParent = org
                                                          .copyWith(
                                                            childIds: org
                                                                .childIds
                                                                .where(
                                                                  (id) =>
                                                                      id !=
                                                                      child.id,
                                                                )
                                                                .toList(),
                                                          );
                                                      await ref
                                                          .read(
                                                            databaseServiceProvider,
                                                          )
                                                          .saveOrgUnit(
                                                            updatedParent,
                                                          );

                                                      final updatedParentFromDb =
                                                          await ref
                                                              .read(
                                                                databaseServiceProvider,
                                                              )
                                                              .getOrgUnit(
                                                                org.id,
                                                              );
                                                      if (updatedParentFromDb !=
                                                          null) {
                                                        ref
                                                                .read(
                                                                  selectedOrgForDetailsProvider
                                                                      .notifier,
                                                                )
                                                                .state =
                                                            updatedParentFromDb;
                                                      }
                                                      setState(() {});
                                                    },
                                                    child: const Text('Remove'),
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String getHeadOfLabel(String type) {
  switch (type.toLowerCase()) {
    case 'md division':
      return 'Managing Director';
    case 'svp division':
      return 'SVP';
    case 'vp division':
      return 'VP';
    case 'department':
      return 'Director';
    case 'group':
      return 'Head of';
    case 'team':
      return 'Team Lead';
    default:
      return 'Head of';
  }
}

String formatOrgType(String type) {
  final lower = type.toLowerCase();
  if (lower == 'md division') return 'MD Division';
  if (lower == 'svp division') return 'SVP Division';
  if (lower == 'vp division') return 'VP Division';
  if (lower == 'department') return 'Department';
  if (lower == 'group') return 'Group';
  if (lower == 'team') return 'Team';
  return type;
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
    final primaryColor = theme.colorScheme.primary;
    final hoverColor = theme.colorScheme.secondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: widget.linkKey,
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: TextStyle(
            color: _isHovered ? hoverColor : primaryColor,
            fontWeight: FontWeight.w500,
            decoration: _isHovered
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
        ),
      ),
    );
  }
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
