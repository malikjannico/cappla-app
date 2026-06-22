import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/providers.dart';
import '../../services/database/database_service.dart';
import '../../core/router/router_paths.dart';
import '../../models/user_model.dart';
import 'm3_segmented_button.dart';

import 'planning/assign_dialog.dart';
import 'planning/activity_planning_table.dart';
import 'planning/employee_planning_table.dart';





class PlanningView extends ConsumerStatefulWidget {
  final String viewType; // 'activity' or 'employee'

  const PlanningView({super.key, required this.viewType});

  @override
  ConsumerState<PlanningView> createState() => _PlanningViewState();
}

class _PlanningViewState extends ConsumerState<PlanningView> {
  // Filters State
  List<String> _selectedActivityGroups = [];
  List<String> _selectedCategories = [];
  List<String> _selectedEmployees = [];
  int _selectedYear = DateTime.now().year;
  String? _activeEmployeeEmail;

  // Track if filters have been initialized
  bool _filtersInitialized = false;

  // Editing State
  // Activity View: map of activityId -> editing mode
  final Map<String, bool> _activityEditing = {};
  // Local edit cache: activityId -> monthIdx (1-12) -> value
  final Map<String, Map<int, double>> _localDemandEdits = {};
  // Local edit cache: userEmail_activityId -> monthIdx (1-12) -> value
  final Map<String, Map<int, double>> _localAllocationEdits = {};

  // Employee View: global edit mode
  bool _employeeEditing = false;
  final _employeeTableKey = GlobalKey<EmployeePlanningTableState>();
  final _activityTableKeys = <String, GlobalKey<ActivityPlanningTableState>>{};

  // Lock and Heartbeat State
  Timer? _lockRefreshTimer;
  String? _currentLockId;
  DatabaseService? _databaseService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _databaseService = ref.read(databaseServiceProvider);
  }

  Future<bool> _tryAcquireLock({
    required String lockId,
    required String lockType,
    String? activityId,
    List<String> activityIds = const [],
    List<String> employeeEmails = const [],
    required String orgUnitId,
  }) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return false;

    final now = DateTime.now();
    final lock = LockModel(
      id: lockId,
      userId: currentUser.id,
      userEmail: currentUser.email,
      userFullName: currentUser.fullName,
      lockType: lockType,
      activityId: activityId,
      activityIds: activityIds,
      employeeEmails: employeeEmails,
      year: _selectedYear,
      orgUnitId: orgUnitId,
      lockedAt: now,
      expiresAt: now.add(const Duration(minutes: 2)),
    );

    final db = ref.read(databaseServiceProvider);
    final success = await db.acquireLock(lock);
    if (success) {
      _currentLockId = lockId;
      _lockRefreshTimer?.cancel();
      _lockRefreshTimer = Timer.periodic(const Duration(seconds: 30), (
        timer,
      ) async {
        final currentNow = DateTime.now();
        final refreshedLock = lock.copyWith(
          lockedAt: currentNow,
          expiresAt: currentNow.add(const Duration(minutes: 2)),
        );
        await db.acquireLock(refreshedLock);
      });
      return true;
    }
    return false;
  }

  Future<void> _releaseCurrentLock() async {
    _lockRefreshTimer?.cancel();
    _lockRefreshTimer = null;
    if (_currentLockId != null) {
      final db = ref.read(databaseServiceProvider);
      await db.releaseLock(_currentLockId!);
      _currentLockId = null;
    }
  }

  LockModel? _getActivityLock(
    String activityId,
    String currentUserId,
    List<LockModel> activeLocks,
  ) {
    for (final lock in activeLocks) {
      if (lock.userId == currentUserId) continue;
      if (lock.isExpired) continue;
      if (lock.lockType == 'activity' && lock.activityId == activityId) {
        return lock;
      }
      if (lock.lockType == 'employee' &&
          lock.activityIds.contains(activityId)) {
        return lock;
      }
    }
    return null;
  }

  LockModel? _getConflictingEmployeeLock(
    List<UserModel> selectedEmployeesList,
    List<ActivityModel> catActivities,
    String currentUserId,
    List<LockModel> activeLocks,
  ) {
    final myEmails = selectedEmployeesList
        .map((e) => e.email.trim().toLowerCase())
        .toSet();
    final myActIds = catActivities.map((a) => a.id).toSet();

    for (final lock in activeLocks) {
      if (lock.userId == currentUserId) continue;
      if (lock.isExpired) continue;
      if (lock.lockType == 'employee') {
        final lockEmails = lock.employeeEmails
            .map((e) => e.trim().toLowerCase())
            .toSet();
        final lockActIds = lock.activityIds.toSet();
        final commonEmps = myEmails.intersection(lockEmails);
        final commonActs = myActIds.intersection(lockActIds);
        if (commonEmps.isNotEmpty && commonActs.isNotEmpty) {
          return lock;
        }
      }
    }
    return null;
  }

  // Employee View: collapse/expand state of selected employees (defaults to collapsed)
  final Map<String, bool> _employeeExpanded = {};

  // Active table for cell selection coordination
  String? _activeTableId;

  // Controllers & FocusNodes to prevent recreation issues
  final Map<String, TextEditingController> _controllersCache = {};
  final Map<String, FocusNode> _focusNodesCache = {};

  void _clearControllersCache() {
    for (final ctrl in _controllersCache.values) {
      ctrl.dispose();
    }
    _controllersCache.clear();
  }

  @override
  void dispose() {
    _lockRefreshTimer?.cancel();
    final lockId = _currentLockId;
    final db = _databaseService;
    if (lockId != null && db != null) {
      Future.microtask(() => db.releaseLock(lockId));
    }
    for (final ctrl in _controllersCache.values) {
      ctrl.dispose();
    }
    for (final node in _focusNodesCache.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlanningView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewType != widget.viewType) {
      _employeeEditing = false;
      _activityEditing.clear();
      _localDemandEdits.clear();
      _localAllocationEdits.clear();
      _selectedActivityGroups = [];
      _selectedCategories = [];
      _releaseCurrentLock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final orgUnitId = currentUser.orgUnitId;
    if (orgUnitId == null || orgUnitId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text(
            'You are not assigned to an organization unit. Access denied.',
          ),
        ),
      );
    }

    // Load data from streams
    final usersAsync = ref.watch(allUsersStreamProvider);
    final activitiesAsync = ref.watch(activitiesStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final groupsAsync = ref.watch(activityGroupsStreamProvider);
    final demandsAsync = ref.watch(
      planningDemandsStreamProvider(_selectedYear),
    );
    final allocationsAsync = ref.watch(
      planningAllocationsStreamProvider(_selectedYear),
    );
    final locksAsync = ref.watch(locksStreamProvider(_selectedYear));

    final bool isLoading =
        usersAsync.value == null ||
        activitiesAsync.value == null ||
        categoriesAsync.value == null ||
        groupsAsync.value == null ||
        demandsAsync.value == null ||
        allocationsAsync.value == null ||
        locksAsync.value == null;

    final allUsers = usersAsync.value ?? [];
    final allActivities = activitiesAsync.value ?? [];
    final allCategories = categoriesAsync.value ?? [];
    final allGroups = groupsAsync.value ?? [];
    final allDemands = demandsAsync.value ?? [];
    final allAllocations = allocationsAsync.value ?? [];
    final allLocks = locksAsync.value ?? [];

    // Filter values based on the organization unit of the user
    final orgActivities = allActivities.where((act) {
      final isAssociated =
          act.ownerOrgUnitId == orgUnitId ||
          act.sharedOrgUnitIds.contains(orgUnitId) ||
          act.appliedOrgUnitIds.contains(orgUnitId);
      final isActive = act.statusMap[orgUnitId] == 'Active';
      final isWithinValidity =
          act.type != 'Limited' ||
          ((act.validityStart == null ||
                  act.validityStart!.year <= _selectedYear) &&
              (act.validityEnd == null ||
                  act.validityEnd!.year >= _selectedYear));
      return isAssociated && isActive && isWithinValidity;
    }).toList();

    final availableGroupIds = orgActivities
        .map((a) => a.activityGroupId)
        .toSet();
    final orgGroups = allGroups
        .where(
          (g) =>
              availableGroupIds.contains(g.id) &&
              g.statusMap[orgUnitId] == 'Active',
        )
        .toList();

    final availableCategoryIds = orgActivities
        .map((a) => a.categoryId)
        .whereType<String>()
        .toSet();
    final orgCategories = allCategories
        .where(
          (c) =>
              availableCategoryIds.contains(c.id) &&
              c.statusMap[orgUnitId] == 'Active',
        )
        .toList();

    final orgEmployees = allUsers
        .where((u) => u.orgUnitId == orgUnitId && u.status == 'Active')
        .toList();

    // Default Initialization
    if (!_filtersInitialized) {
      _selectedActivityGroups = [];
      _selectedCategories = [];
      _selectedEmployees = [currentUser.email];
      _filtersInitialized = true;
    }

    // Determine Year Filter Options
    final years = _getYearDropdownValues(
      allDemands,
      allAllocations,
      orgEmployees,
    );

    // Watch capacities for selected employees dynamically
    final selectedEmployeesCapacities = <String, List<UserCapacityModel>>{};
    for (final employeeEmail in _selectedEmployees) {
      final capsAsync = ref.watch(userCapacitiesStreamProvider(employeeEmail));
      selectedEmployeesCapacities[employeeEmail] = capsAsync.value ?? [];
    }

    return Scaffold(
      key: const Key('planning_page'),
      backgroundColor: const Color(0xFFFFFFFF),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_activeTableId != null) {
            setState(() {
              _activeTableId = null;
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.only(
            left: 24,
            right: 24,
            top: 32,
            bottom: 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title & Switch Control Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Capacity Plan',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: widget.viewType == 'activity'
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ),
                  M3SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'activity', label: Text('Activity')),
                      ButtonSegment(value: 'employee', label: Text('Employee')),
                    ],
                    selected: {widget.viewType},
                    onSelectionChanged: (val) {
                      if (val.first == 'activity') {
                        context.go(RouterPaths.planActivities);
                      } else {
                        context.go(RouterPaths.planEmployees);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Filters Section (includes Employee edit controls on right side)
              _buildFiltersRow(
                theme: theme,
                groups: orgGroups,
                categories: orgCategories,
                employees: orgEmployees,
                years: years,
                orgActivities: orgActivities,
                allAllocations: allAllocations,
                orgUnitId: orgUnitId,
                isLoading: isLoading,
                allLocks: allLocks,
              ),
              const SizedBox(height: 24),

              // Main Table content based on view type
              Expanded(
                child: isLoading
                    ? _buildTableSkeleton(theme)
                    : widget.viewType == 'activity'
                    ? _buildActivityViewContent(
                        theme,
                        orgActivities,
                        orgGroups,
                        orgCategories,
                        orgEmployees,
                        allDemands,
                        allAllocations,
                        orgUnitId,
                        allLocks,
                        currentUser,
                      )
                    : _buildEmployeeViewContent(
                        theme,
                        orgActivities,
                        orgGroups,
                        orgCategories,
                        orgEmployees,
                        allAllocations,
                        selectedEmployeesCapacities,
                        orgUnitId,
                        allLocks,
                        currentUser,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // YEAR DROP DOWN CALCULATION
  // =========================================================================
  List<int> _getYearDropdownValues(
    List<PlanningDemandModel> demands,
    List<PlanningAllocationModel> allocations,
    List<UserModel> employees,
  ) {
    final currentYear = DateTime.now().year;
    final yearsSet = <int>{};

    for (int i = 0; i <= 10; i++) {
      yearsSet.add(currentYear + i);
    }

    if (widget.viewType == 'employee') {
      final selectedLower = _selectedEmployees
          .map((e) => e.trim().toLowerCase())
          .toSet();
      for (final alloc in allocations) {
        if (selectedLower.contains(alloc.userEmail.trim().toLowerCase()) &&
            alloc.sum > 0) {
          yearsSet.add(alloc.year);
        }
      }
    } else {
      for (final demand in demands) {
        if (demand.sum > 0) yearsSet.add(demand.year);
      }
      for (final alloc in allocations) {
        if (alloc.sum > 0) yearsSet.add(alloc.year);
      }
    }

    final sortedList = yearsSet.toList()..sort();
    return sortedList;
  }

  // =========================================================================
  // FILTERS WIDGET ROW
  // =========================================================================
  Widget _buildFiltersRow({
    required ThemeData theme,
    required List<ActivityGroupModel> groups,
    required List<CategoryModel> categories,
    required List<UserModel> employees,
    required List<int> years,
    required List<ActivityModel> orgActivities,
    required List<PlanningAllocationModel> allAllocations,
    required String orgUnitId,
    required bool isLoading,
    required List<LockModel> allLocks,
  }) {
    final selectedEmployeesList = employees
        .where((e) => _selectedEmployees.contains(e.email))
        .toList();
    final catActivities = orgActivities
        .where(
          (act) =>
              _selectedCategories.isEmpty ||
              (act.categoryId != null &&
                  _selectedCategories.contains(act.categoryId)),
        )
        .toList();
    final currentUser = ref.read(currentUserProvider);
    final currentUserId = currentUser?.id ?? '';
    final conflictingLock = _getConflictingEmployeeLock(
      selectedEmployeesList,
      catActivities,
      currentUserId,
      allLocks,
    );
    final isLocked = conflictingLock != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.viewType == 'activity') ...[
                  _buildMultiSelectFilterChip(
                    label: 'Activity Group',
                    items: groups
                        .map(
                          (g) => DropdownMenuItem(
                            value: g.id,
                            child: Text(g.name),
                          ),
                        )
                        .toList(),
                    selectedValues: _selectedActivityGroups,
                    onChanged: (values) {
                      setState(() => _selectedActivityGroups = values);
                    },
                    theme: theme,
                  ),
                ],
                _buildMultiSelectFilterChip(
                  label: 'Category',
                  items: categories
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  selectedValues: _selectedCategories,
                  onChanged: (values) {
                    setState(() => _selectedCategories = values);
                  },
                  theme: theme,
                ),
                if (widget.viewType == 'employee') ...[
                  _buildMultiSelectFilterChip(
                    label: 'Employee',
                    items: employees
                        .map(
                          (u) => DropdownMenuItem(
                            value: u.email,
                            child: Text(u.fullName),
                          ),
                        )
                        .toList(),
                    selectedValues: _selectedEmployees,
                    onChanged: (values) {
                      setState(() {
                        _selectedEmployees = values;
                        if (values.isNotEmpty) {
                          if (_activeEmployeeEmail == null ||
                              !values.contains(_activeEmployeeEmail)) {
                            _activeEmployeeEmail = values.first;
                          }
                        } else {
                          _activeEmployeeEmail = null;
                        }
                      });
                    },
                    theme: theme,
                  ),
                ],
                // Year Dropdown (Single Select)
                Tooltip(
                  message: 'Select Year',
                  child: MenuAnchor(
                    builder: (context, controller, child) {
                      return FilterChip(
                        key: const Key('filter_year_dropdown'),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedYear.toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        ),
                        selected: true,
                        onSelected: (selected) {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                      );
                    },
                    menuChildren: years.map((y) {
                      return MenuItemButton(
                        key: Key('filter_year_item_$y'),
                        onPressed: () {
                          setState(() {
                            _selectedYear = y;
                            _localDemandEdits.clear();
                            _localAllocationEdits.clear();
                          });
                        },
                        child: Text(y.toString()),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          if (widget.viewType == 'employee' && !isLoading) ...[
            const SizedBox(width: 16),
            if (!_employeeEditing) ...[
              FilledButton.icon(
                key: const Key('employee_view_edit_button'),
                onPressed: isLocked
                    ? null
                    : () async {
                        final actIds = catActivities.map((a) => a.id).toList();
                        final lockId =
                            'employee_${currentUser!.email}_${_selectedYear}_$orgUnitId';
 
                        final success = await _tryAcquireLock(
                          lockId: lockId,
                          lockType: 'employee',
                          activityIds: actIds,
                          orgUnitId: orgUnitId,
                        );
                        if (!mounted) return;
                        if (!success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Cannot edit. This employee view is locked by ${conflictingLock?.userFullName}.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
 
                        setState(() {
                          _employeeEditing = true;
                          _localAllocationEdits.clear();
                          for (final emp in selectedEmployeesList) {
                            for (final act in catActivities) {
                              final allocKey = '${emp.email}_${act.id}';
                              final alloc = allAllocations.firstWhere(
                                (a) =>
                                    a.userEmail.trim().toLowerCase() ==
                                        emp.email.trim().toLowerCase() &&
                                    a.activityId == act.id &&
                                    a.year == _selectedYear,
                                orElse: () => PlanningAllocationModel(
                                  id: '${emp.email}_${act.id}_$_selectedYear',
                                  userEmail: emp.email,
                                  activityId: act.id,
                                  year: _selectedYear,
                                  orgUnitId: orgUnitId,
                                ),
                              );
                              _localAllocationEdits[allocKey] = {
                                for (int i = 0; i < 12; i++)
                                  i + 1: _getAllocationValue(
                                    alloc,
                                    i + 1,
                                  ),
                              };
                            }
                          }
                        });
                      },
                icon: Icon(
                  isLocked ? Icons.lock : Icons.edit,
                  size: 16,
                ),
                label: Text(
                  isLocked
                      ? 'Locked by ${conflictingLock.userFullName}'
                      : 'Edit',
                ),
              ),
              const SizedBox(width: 8),
              Directionality(
                textDirection: TextDirection.rtl,
                child: MenuAnchor(
                  builder: (context, controller, child) {
                    return IconButton(
                      key: const Key('export_csv_button_employee'),
                      icon: const Icon(Icons.more_vert),
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
                        onPressed: () {
                          _employeeTableKey.currentState?.exportToCsv();
                        },
                        child: const Text('Export as CSV'),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _employeeEditing = false;
                        _localAllocationEdits.clear();
                        _clearControllersCache();
                      });
                      _releaseCurrentLock();
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('employee_view_save_button'),
                    onPressed: () async {
                      await _saveEmployeeEdits(
                        selectedEmployeesList,
                        catActivities,
                        orgUnitId,
                      );
                      setState(() {
                        _employeeEditing = false;
                        _localAllocationEdits.clear();
                        _clearControllersCache();
                      });
                      await _releaseCurrentLock();
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Directionality(
                textDirection: TextDirection.rtl,
                child: MenuAnchor(
                  builder: (context, controller, child) {
                    return IconButton(
                      key: const Key('export_csv_button_employee'),
                      icon: const Icon(Icons.more_vert),
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
                        onPressed: () {
                          _employeeTableKey.currentState?.exportToCsv();
                        },
                        child: const Text('Export as CSV'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMultiSelectFilterChip({
    required String label,
    required List<DropdownMenuItem<String>> items,
    required List<String> selectedValues,
    required ValueChanged<List<String>> onChanged,
    required ThemeData theme,
  }) {
    final bool isAllSelected = label == 'Employee'
        ? selectedValues.length == items.length
        : selectedValues.isEmpty;

    final String displayLabel = isAllSelected
        ? (label == 'Category'
              ? 'All Categories'
              : (label == 'Employee' ? 'All Employees' : 'All Activity Groups'))
        : '${selectedValues.length} Selected';

    final bool isSelected = label == 'Employee'
        ? selectedValues.length != items.length
        : selectedValues.isNotEmpty;

    return MenuAnchor(
      builder: (context, controller, child) {
        return Tooltip(
          message: 'Select $label',
          child: FilterChip(
            key: Key(
              'filter_${label.toLowerCase().replaceAll(' ', '_')}_dropdown',
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayLabel,
                  style: TextStyle(
                    color: isSelected ? Colors.white : null,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: isSelected ? Colors.white : null,
                ),
              ],
            ),
            selected: isSelected,
            onSelected: (selected) {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
          ),
        );
      },
      menuChildren: items.map((item) {
        final isChecked = selectedValues.contains(item.value);
        final sanitizedValue =
            item.value?.toLowerCase().replaceAll(' ', '_') ?? '';
        return CheckboxMenuButton(
          key: Key(
            'filter_${label.toLowerCase().replaceAll(' ', '_')}_item_$sanitizedValue',
          ),
          value: isChecked,
          onChanged: (checked) {
            if (checked == null) return;
            final newValues = List<String>.from(selectedValues);
            if (checked) {
              if (item.value != null) {
                newValues.add(item.value!);
              }
            } else {
              if (newValues.length > 1 || label != 'Employee') {
                newValues.remove(item.value);
              }
            }
            onChanged(newValues);
          },
          child: item.child,
        );
      }).toList(),
    );
  }

  // =========================================================================
  // ACTIVITY VIEW CONTENT
  // =========================================================================
  Widget _buildActivityViewContent(
    ThemeData theme,
    List<ActivityModel> activities,
    List<ActivityGroupModel> groups,
    List<CategoryModel> categories,
    List<UserModel> employees,
    List<PlanningDemandModel> demands,
    List<PlanningAllocationModel> allocations,
    String orgUnitId,
    List<LockModel> allLocks,
    UserModel currentUser,
  ) {
    // Filter activities by selected groups & categories
    final filteredActivities = activities.where((act) {
      final matchesGroup =
          _selectedActivityGroups.isEmpty ||
          _selectedActivityGroups.contains(act.activityGroupId);
      final matchesCat =
          _selectedCategories.isEmpty ||
          (act.categoryId != null &&
              _selectedCategories.contains(act.categoryId));
      return matchesGroup && matchesCat;
    }).toList();

    // Sort by parent activity group order number, then by activity order number
    filteredActivities.sort((a, b) {
      final groupA = groups.firstWhere(
        (g) => g.id == a.activityGroupId,
        orElse: () => ActivityGroupModel(
          id: '',
          name: '',
          ownerOrgUnitId: '',
          sharedOrgUnitIds: [],
          appliedOrgUnitIds: [],
          statusMap: {},
          createdBy: '',
          createdAt: DateTime.now(),
          lastModifiedBy: '',
          lastModifiedAt: DateTime.now(),
          order: 999,
        ),
      );
      final groupB = groups.firstWhere(
        (g) => g.id == b.activityGroupId,
        orElse: () => ActivityGroupModel(
          id: '',
          name: '',
          ownerOrgUnitId: '',
          sharedOrgUnitIds: [],
          appliedOrgUnitIds: [],
          statusMap: {},
          createdBy: '',
          createdAt: DateTime.now(),
          lastModifiedBy: '',
          lastModifiedAt: DateTime.now(),
          order: 999,
        ),
      );
      final orderComp = groupA.order.compareTo(groupB.order);
      if (orderComp != 0) return orderComp;
      return a.order.compareTo(b.order);
    });

    final categoryMap = {for (final c in categories) c.id: c};
    final demandMap = {
      for (final d in demands)
        if (d.orgUnitId == orgUnitId) d.activityId: d,
    };
    final employeeMap = {
      for (final emp in employees) emp.email.trim().toLowerCase(): emp,
    };
    final assignedEmployeesMap = {
      for (final act in filteredActivities)
        act.id: act.assignedUserEmails
            .map((e) => employeeMap[e.trim().toLowerCase()])
            .whereType<UserModel>()
            .toList(),
    };
    final allocationsMap = <String, List<PlanningAllocationModel>>{};
    for (final alloc in allocations) {
      allocationsMap.putIfAbsent(alloc.activityId, () => []).add(alloc);
    }

    if (filteredActivities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        child: const Text('No activities match the selected filters.'),
      );
    }

    return ListView.builder(
      // ignore: deprecated_member_use
      cacheExtent: 1500.0, itemCount: filteredActivities.length,
      itemBuilder: (context, index) {
        final activity = filteredActivities[index];
        final category =
            categoryMap[activity.categoryId] ??
            CategoryModel(
              id: '',
              name: '',
              ownerOrgUnitId: '',
              sharedOrgUnitIds: [],
              appliedOrgUnitIds: [],
              statusMap: {},
              createdBy: '',
              createdAt: DateTime.now(),
              lastModifiedBy: '',
              lastModifiedAt: DateTime.now(),
              order: 0,
            );

        final demand =
            demandMap[activity.id] ??
            PlanningDemandModel(
              id: '${activity.id}_${_selectedYear}_$orgUnitId',
              activityId: activity.id,
              year: _selectedYear,
              orgUnitId: orgUnitId,
            );

        final assignedEmployees = assignedEmployeesMap[activity.id] ?? [];
        final activityAllocations = allocationsMap[activity.id] ?? [];
        final isEditing = _activityEditing[activity.id] ?? false;
        final lock = _getActivityLock(activity.id, currentUser.id, allLocks);
        final isActivityLockedByOther = lock != null;

        return RepaintBoundary(
          child: Padding(
            key: Key('activity_card_${activity.id}'),
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Table Title Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              activity.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (activity.categoryId != null &&
                              activity.categoryId!.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Chip(
                              label: Text(
                                category.name,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                              backgroundColor: theme.colorScheme.secondary,
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 0,
                              ),
                              visualDensity: VisualDensity.compact,
                              shape: const StadiumBorder(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.icon(
                          key: Key('activity_assign_button_${activity.id}'),
                          onPressed: isActivityLockedByOther
                              ? null
                              : () => _showAssignDialog(
                                  context,
                                  activity,
                                  employees,
                                  orgUnitId,
                                ),
                          icon: const Icon(Icons.person_add_alt_1, size: 16),
                          label: const Text('Assign'),
                        ),
                        const SizedBox(width: 8),
                        if (!isEditing) ...[
                          FilledButton.icon(
                            key: Key('activity_edit_button_${activity.id}'),
                            onPressed: isActivityLockedByOther
                                ? null
                                : () async {
                                    final lockId =
                                        'activity_${activity.id}_${_selectedYear}_$orgUnitId';
                                    final success = await _tryAcquireLock(
                                      lockId: lockId,
                                      lockType: 'activity',
                                      activityId: activity.id,
                                      orgUnitId: orgUnitId,
                                    );
                                     if (!context.mounted) return;
                                    if (!success) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Cannot edit. This activity is currently locked.',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    setState(() {
                                      // Initialize local edits
                                      _activityEditing[activity.id] = true;
                                      _localDemandEdits[activity.id] = {
                                        for (int i = 0; i < 12; i++)
                                          i + 1: _getDemandValue(demand, i + 1),
                                      };
                                      for (final emp in assignedEmployees) {
                                        final allocKey =
                                            '${emp.email}_${activity.id}';
                                        final alloc = activityAllocations.firstWhere(
                                          (a) =>
                                              a.userEmail
                                                  .trim()
                                                  .toLowerCase() ==
                                              emp.email.trim().toLowerCase(),
                                          orElse: () => PlanningAllocationModel(
                                            id: '${emp.email}_${activity.id}_$_selectedYear',
                                            userEmail: emp.email,
                                            activityId: activity.id,
                                            year: _selectedYear,
                                            orgUnitId: orgUnitId,
                                          ),
                                        );
                                        _localAllocationEdits[allocKey] = {
                                          for (int i = 0; i < 12; i++)
                                            i + 1: _getAllocationValue(
                                              alloc,
                                              i + 1,
                                            ),
                                        };
                                      }
                                    });
                                  },
                            icon: Icon(
                              isActivityLockedByOther ? Icons.lock : Icons.edit,
                              size: 16,
                            ),
                            label: Text(
                              isActivityLockedByOther
                                  ? 'Locked by ${lock.userFullName}'
                                  : 'Edit',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: MenuAnchor(
                              builder: (context, controller, child) {
                                return IconButton(
                                  key: Key('export_csv_button_${activity.id}'),
                                  icon: const Icon(Icons.more_vert),
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
                                    onPressed: () {
                                      _activityTableKeys[activity.id]
                                          ?.currentState
                                          ?.exportToCsv();
                                    },
                                    child: const Text('Export as CSV'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _activityEditing[activity.id] = false;
                                    _localAllocationEdits.clear();
                                    _clearControllersCache();
                                  });
                                  _releaseCurrentLock();
                                },
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                key: Key('activity_save_button_${activity.id}'),
                                onPressed: () async {
                                  await _saveActivityEdits(
                                    activity.id,
                                    demand,
                                    assignedEmployees,
                                    orgUnitId,
                                  );
                                  setState(() {
                                    _activityEditing[activity.id] = false;
                                    _localAllocationEdits.clear();
                                    _clearControllersCache();
                                  });
                                  await _releaseCurrentLock();
                                },
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: MenuAnchor(
                              builder: (context, controller, child) {
                                return IconButton(
                                  key: Key('export_csv_button_${activity.id}'),
                                  icon: const Icon(Icons.more_vert),
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
                                    onPressed: () {
                                      _activityTableKeys[activity.id]
                                          ?.currentState
                                          ?.exportToCsv();
                                    },
                                    child: const Text('Export as CSV'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Table Component
                ActivityPlanningTable(
                  key: _activityTableKeys.putIfAbsent(
                    activity.id,
                    () => GlobalKey<ActivityPlanningTableState>(),
                  ),
                  theme: theme,
                  activity: activity,
                  demand: demand,
                  employees: assignedEmployees,
                  allocations: activityAllocations,
                  isEditing: isEditing,
                  localDemandEdits: _localDemandEdits,
                  localAllocationEdits: _localAllocationEdits,
                  selectedYear: _selectedYear,
                  orgUnitId: orgUnitId,
                  controllersCache: _controllersCache,
                  activeTableId: _activeTableId,
                  onTableTap: (id) => setState(() => _activeTableId = id),
                  focusNodesCache: _focusNodesCache,
                  onDemandChanged: (val) {
                    // Update main demand edits if needed
                  },
                  onAllocationChanged: (idx, val) {
                    // Update main allocation edits if needed
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // EMPLOYEE VIEW CONTENT
  // =========================================================================
  Widget _buildEmployeeViewContent(
    ThemeData theme,
    List<ActivityModel> activities,
    List<ActivityGroupModel> groups,
    List<CategoryModel> categories,
    List<UserModel> employees,
    List<PlanningAllocationModel> allocations,
    Map<String, List<UserCapacityModel>> capacities,
    String orgUnitId,
    List<LockModel> allLocks,
    UserModel currentUser,
  ) {
    final catActivities = activities
        .where(
          (act) =>
              _selectedCategories.isEmpty ||
              (act.categoryId != null &&
                  _selectedCategories.contains(act.categoryId)),
        )
        .toList();

    if (catActivities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        child: const Text('No activities match the selected Category filter.'),
      );
    }

    final selectedEmployeesList = employees
        .where((e) => _selectedEmployees.contains(e.email))
        .toList();
    if (selectedEmployeesList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        child: const Text('Please select at least one Employee.'),
      );
    }

    if (_activeEmployeeEmail == null ||
        !_selectedEmployees.contains(_activeEmployeeEmail)) {
      if (selectedEmployeesList.isNotEmpty) {
        _activeEmployeeEmail = selectedEmployeesList.first.email;
      } else {
        _activeEmployeeEmail = null;
      }
    }

    final visibleGroupIds = catActivities.map((a) => a.activityGroupId).toSet();
    final visibleGroups =
        groups.where((g) => visibleGroupIds.contains(g.id)).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    final bool showTabs = selectedEmployeesList.isNotEmpty;
    final UserModel? activeEmployee = _activeEmployeeEmail != null
        ? selectedEmployeesList.firstWhere(
            (e) => e.email == _activeEmployeeEmail,
            orElse: () => selectedEmployeesList.first,
          )
        : null;

    final List<UserModel> tableEmployees = showTabs
        ? (activeEmployee != null ? [activeEmployee] : [])
        : selectedEmployeesList;

    Widget buildTab(UserModel emp) {
      final isActive = emp.email == _activeEmployeeEmail;
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: GestureDetector(
          key: Key('employee_tab_${emp.email}'),
          onTap: () {
            setState(() {
              _activeEmployeeEmail = emp.email;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: isActive ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emp.fullName,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  key: Key('deselect_employee_${emp.email}'),
                  onTap: () {
                    setState(() {
                      _selectedEmployees = List.from(_selectedEmployees)
                        ..remove(emp.email);
                      if (_activeEmployeeEmail == emp.email) {
                        if (_selectedEmployees.isNotEmpty) {
                          _activeEmployeeEmail = _selectedEmployees.first;
                        } else {
                          _activeEmployeeEmail = null;
                        }
                      }
                    });
                  },
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: isActive
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final Widget tabsWidget = Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: selectedEmployeesList.map(buildTab).toList(),
        ),
      ),
    );

    final mainTable = RepaintBoundary(
      child: EmployeePlanningTable(
        key: _employeeTableKey,
        theme: theme,
        selectedEmployees: tableEmployees,
        activities: catActivities,
        groups: visibleGroups,
        categories: categories,
        allocations: allocations,
        capacities: capacities,
        orgUnitId: orgUnitId,
        isEditing: _employeeEditing,
        localAllocationEdits: _localAllocationEdits,
        selectedYear: _selectedYear,
        employeeExpanded: _employeeExpanded,
        controllersCache: _controllersCache,
        activeTableId: _activeTableId,
        onTableTap: (id) => setState(() => _activeTableId = id),
        focusNodesCache: _focusNodesCache,
        onExpandedChanged: (empEmail, expanded) {
          setState(() {
            _employeeExpanded[empEmail] = expanded;
          });
        },
        activeLocks: allLocks,
        currentUserId: currentUser.id,
        showNamesRow: !showTabs,
      ),
    );

    if (showTabs) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tabsWidget,
          Expanded(child: mainTable),
        ],
      );
    } else {
      return mainTable;
    }
  }

  // =========================================================================
  // SAVE IMPLEMENTATIONS
  // =========================================================================
  Future<void> _saveActivityEdits(
    String activityId,
    PlanningDemandModel oldDemand,
    List<UserModel> employees,
    String orgUnitId,
  ) async {
    final db = ref.read(databaseServiceProvider);

    // Save demand
    final localDem = _localDemandEdits[activityId];
    if (localDem != null) {
      final demand = oldDemand.copyWith(
        january: localDem[1] ?? 0.0,
        february: localDem[2] ?? 0.0,
        march: localDem[3] ?? 0.0,
        april: localDem[4] ?? 0.0,
        may: localDem[5] ?? 0.0,
        june: localDem[6] ?? 0.0,
        july: localDem[7] ?? 0.0,
        august: localDem[8] ?? 0.0,
        september: localDem[9] ?? 0.0,
        october: localDem[10] ?? 0.0,
        november: localDem[11] ?? 0.0,
        december: localDem[12] ?? 0.0,
      );
      await db.savePlanningDemand(demand);
    }

    // Save allocations
    for (final emp in employees) {
      final allocKey = '${emp.email}_$activityId';
      final localAlloc = _localAllocationEdits[allocKey];
      if (localAlloc != null) {
        final allocation = PlanningAllocationModel(
          id: '${emp.email}_${activityId}_$_selectedYear',
          userEmail: emp.email,
          activityId: activityId,
          year: _selectedYear,
          orgUnitId: orgUnitId,
          january: localAlloc[1] ?? 0.0,
          february: localAlloc[2] ?? 0.0,
          march: localAlloc[3] ?? 0.0,
          april: localAlloc[4] ?? 0.0,
          may: localAlloc[5] ?? 0.0,
          june: localAlloc[6] ?? 0.0,
          july: localAlloc[7] ?? 0.0,
          august: localAlloc[8] ?? 0.0,
          september: localAlloc[9] ?? 0.0,
          october: localAlloc[10] ?? 0.0,
          november: localAlloc[11] ?? 0.0,
          december: localAlloc[12] ?? 0.0,
        );
        await db.savePlanningAllocation(allocation);
      }
    }
  }

  Future<void> _saveEmployeeEdits(
    List<UserModel> employees,
    List<ActivityModel> activities,
    String orgUnitId,
  ) async {
    final db = ref.read(databaseServiceProvider);

    for (final emp in employees) {
      for (final act in activities) {
        final allocKey = '${emp.email}_${act.id}';
        final localAlloc = _localAllocationEdits[allocKey];
        if (localAlloc != null) {
          final allocation = PlanningAllocationModel(
            id: '${emp.email}_${act.id}_$_selectedYear',
            userEmail: emp.email,
            activityId: act.id,
            year: _selectedYear,
            orgUnitId: orgUnitId,
            january: localAlloc[1] ?? 0.0,
            february: localAlloc[2] ?? 0.0,
            march: localAlloc[3] ?? 0.0,
            april: localAlloc[4] ?? 0.0,
            may: localAlloc[5] ?? 0.0,
            june: localAlloc[6] ?? 0.0,
            july: localAlloc[7] ?? 0.0,
            august: localAlloc[8] ?? 0.0,
            september: localAlloc[9] ?? 0.0,
            october: localAlloc[10] ?? 0.0,
            november: localAlloc[11] ?? 0.0,
            december: localAlloc[12] ?? 0.0,
          );
          await db.savePlanningAllocation(allocation);
        }
      }
    }
  }

  // =========================================================================
  // ASSIGN DIALOG
  // =========================================================================
  void _showAssignDialog(
    BuildContext context,
    ActivityModel activity,
    List<UserModel> allEmployees,
    String orgUnitId,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AssignDialog(
          activity: activity,
          allEmployees: allEmployees,
          orgUnitId: orgUnitId,
        );
      },
    );
  }

  double _getDemandValue(PlanningDemandModel demand, int month) {
    if (month == 1) return demand.january;
    if (month == 2) return demand.february;
    if (month == 3) return demand.march;
    if (month == 4) return demand.april;
    if (month == 5) return demand.may;
    if (month == 6) return demand.june;
    if (month == 7) return demand.july;
    if (month == 8) return demand.august;
    if (month == 9) return demand.september;
    if (month == 10) return demand.october;
    if (month == 11) return demand.november;
    if (month == 12) return demand.december;
    return 0.0;
  }

  double _getAllocationValue(PlanningAllocationModel alloc, int month) {
    if (month == 1) return alloc.january;
    if (month == 2) return alloc.february;
    if (month == 3) return alloc.march;
    if (month == 4) return alloc.april;
    if (month == 5) return alloc.may;
    if (month == 6) return alloc.june;
    if (month == 7) return alloc.july;
    if (month == 8) return alloc.august;
    if (month == 9) return alloc.september;
    if (month == 10) return alloc.october;
    if (month == 11) return alloc.november;
    if (month == 12) return alloc.december;
    return 0.0;
  }

  // =========================================================================
  // TABLE SKELETON
  // =========================================================================
  Widget _buildTableSkeleton(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Skeleton Header Row
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 180,
                height: 16,
                margin: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              ...List.generate(
                12,
                (_) => Expanded(
                  child: Container(
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              Container(
                width: 60,
                height: 16,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        // Skeleton Data Rows
        ...List.generate(5, (index) {
          return Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 120,
                  height: 14,
                  margin: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                ...List.generate(
                  12,
                  (_) => Container(
                    width: 32,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.06,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Container(
                  width: 40,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// =========================================================================
// ASSIGN DIALOG COMPONENT
// =========================================================================
