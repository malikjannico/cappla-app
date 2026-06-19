// File: lib/views/standard/reports_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/router_paths.dart';
import '../../core/providers/providers.dart';
import '../../core/utils/capacity_calculator.dart';
import '../../models/org_unit_model.dart';
import '../../models/user_model.dart';
import '../../core/utils/csv_export_helper.dart';
import 'm3_segmented_button.dart';

const List<String> _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

enum EmployeeRowDisplayMode {
  available,
  planned,
  delta,
}

class ReportsView extends ConsumerStatefulWidget {
  const ReportsView({super.key});

  @override
  ConsumerState<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends ConsumerState<ReportsView> {
  EmployeeRowDisplayMode _empRowDisplayMode = EmployeeRowDisplayMode.planned;

  // Activity Groups Section Filters
  int _agSelectedYear = DateTime.now().year;
  List<String> _agSelectedOrgUnits = [];
  List<String> _agSelectedEmployees = [];
  List<String> _agSelectedActivityGroups = [];
  List<String> _agSelectedCategories = [];

  // Categories Section Filters
  int _catSelectedYear = DateTime.now().year;
  List<String> _catSelectedOrgUnits = [];
  List<String> _catSelectedEmployees = [];
  List<String> _catSelectedActivityGroups = [];
  List<String> _catSelectedCategories = [];

  // Employees Section Filters
  int _empSelectedYear = DateTime.now().year;
  List<String> _empSelectedOrgUnits = [];
  List<String> _empSelectedEmployees = [];
  List<String> _empSelectedActivityGroups = [];
  List<String> _empSelectedCategories = [];

  // Allowed Org Units Cache
  List<OrgUnitModel> _allowedOrgUnits = [];
  bool _initialized = false;

  List<String> _getDescendantOrgUnitIds(
    String parentId,
    List<OrgUnitModel> allOrgs,
  ) {
    final descendants = <String>[];
    void traverse(String currentId) {
      final directChildren = allOrgs
          .where((o) => o.parentId == currentId)
          .map((o) => o.id)
          .toList();
      for (final childId in directChildren) {
        if (!descendants.contains(childId)) {
          descendants.add(childId);
          traverse(childId);
        }
      }
    }

    traverse(parentId);
    return descendants;
  }

  void _initializeAllowedOrgUnits(UserModel user, List<OrgUnitModel> allOrgs) {
    if (_initialized) return;

    final userOrgId = user.orgUnitId;
    if (userOrgId == null || userOrgId.isEmpty) {
      _allowedOrgUnits = [];
      _initialized = true;
      return;
    }

    final ownedOrgs = allOrgs.where(
      (org) =>
          org.headOfEmail.trim().toLowerCase() ==
          user.email.trim().toLowerCase(),
    );
    if (ownedOrgs.isEmpty) {
      // Normal user: only their own active org unit
      _allowedOrgUnits = allOrgs
          .where((org) => org.id == userOrgId && org.status == 'Active')
          .toList();
    } else {
      // Head of unit: owned org unit + descendants
      final headOrg = ownedOrgs.first;
      final descendants = _getDescendantOrgUnitIds(headOrg.id, allOrgs);
      final allowedIds = {headOrg.id, ...descendants};
      _allowedOrgUnits = allOrgs
          .where((org) => allowedIds.contains(org.id) && org.status == 'Active')
          .toList();
    }
    _initialized = true;
  }

  double _getAllocationMonthValue(PlanningAllocationModel alloc, int month) {
    switch (month) {
      case 1:
        return alloc.january;
      case 2:
        return alloc.february;
      case 3:
        return alloc.march;
      case 4:
        return alloc.april;
      case 5:
        return alloc.may;
      case 6:
        return alloc.june;
      case 7:
        return alloc.july;
      case 8:
        return alloc.august;
      case 9:
        return alloc.september;
      case 10:
        return alloc.october;
      case 11:
        return alloc.november;
      case 12:
        return alloc.december;
      default:
        return 0.0;
    }
  }

  List<int> _getYearDropdownValues({
    required List<String> selectedEmployees,
    required List<UserModel> filteredEmployees,
    required List<PlanningAllocationModel> allocations,
  }) {
    final currentYear = DateTime.now().year;
    final yearsSet = <int>{};

    for (int i = 0; i <= 10; i++) {
      yearsSet.add(currentYear + i);
    }

    final effectiveEmployees = selectedEmployees.isEmpty
        ? filteredEmployees.map((u) => u.email).toList()
        : selectedEmployees;

    final selectedLower = effectiveEmployees
        .map((e) => e.trim().toLowerCase())
        .toSet();
    for (final alloc in allocations) {
      if (selectedLower.contains(alloc.userEmail.trim().toLowerCase()) &&
          alloc.sum > 0) {
        yearsSet.add(alloc.year);
      }
    }

    final sortedList = yearsSet.toList()..sort();
    return sortedList;
  }

  void _exportTableAsCsv({
    required String tableType,
    required int selectedYear,
    required List<String> selectedOrgUnits,
    required List<String> selectedEmployees,
    required List<String> selectedActivityGroups,
    required List<String> selectedCategories,
    required List<UserModel> allUsers,
    required List<ActivityModel> allActivities,
    required List<CategoryModel> allCategories,
    required List<ActivityGroupModel> allGroups,
    required List<PlanningAllocationModel> allAllocations,
  }) {
    final activeOUIds = selectedOrgUnits.isEmpty
        ? _allowedOrgUnits.map((o) => o.id).toList()
        : selectedOrgUnits;

    final targetOUs = _allowedOrgUnits
        .where((o) => activeOUIds.contains(o.id))
        .toList();

    final capacitiesCache = <String, List<UserCapacityModel>>{};
    for (final u in allUsers) {
      if (u.status == 'Active' && u.orgUnitId != null) {
        final caps =
            ref.read(userCapacitiesStreamProvider(u.email)).value ?? [];
        capacitiesCache[u.email] = caps;
      }
    }

    final buffer = StringBuffer();
    String csvEscape(String value) {
      if (value.contains(',') ||
          value.contains('"') ||
          value.contains('\n') ||
          value.contains('\r')) {
        return '"${value.replaceAll('"', '""')}"';
      }
      return value;
    }

    final headers = [
      tableType == 'employee'
          ? 'Employees'
          : (tableType == 'category' ? 'Categories' : 'Activity Groups'),
      ..._months.map((m) => m.substring(0, 3)),
      'Sum',
    ];
    buffer.writeln(headers.map(csvEscape).join(','));

    final displayOUs = <OrgUnitModel>[];
    final Map<String, List<UserModel>> ouEmployeesMap = {};
    final Map<String, List<ActivityModel>> ouActivitiesMap = {};
    final Map<String, List<_RowEntity>> rowEntitiesMap = {};

    for (final ou in targetOUs) {
      final ouEmployees = allUsers
          .where(
            (u) =>
                u.orgUnitId == ou.id &&
                u.status == 'Active' &&
                (selectedEmployees.isEmpty ||
                    selectedEmployees.contains(u.email)),
          )
          .toList();

      final ouActivities = allActivities.where((act) {
        final isAssociated =
            act.ownerOrgUnitId == ou.id ||
            act.sharedOrgUnitIds.contains(ou.id) ||
            act.appliedOrgUnitIds.contains(ou.id);
        final isActive = act.statusMap[ou.id] == 'Active';
        final isWithinValidity =
            act.type != 'Limited' ||
            ((act.validityStart == null ||
                    act.validityStart!.year <= selectedYear) &&
                (act.validityEnd == null ||
                    act.validityEnd!.year >= selectedYear));
        final matchesCategory =
            selectedCategories.isEmpty ||
            (act.categoryId != null &&
                selectedCategories.contains(act.categoryId));
        return isAssociated && isActive && isWithinValidity && matchesCategory;
      }).toList();

      List<_RowEntity> rowEntities = [];
      if (tableType == 'employee') {
        if (ouEmployees.isNotEmpty) {
          rowEntities = ouEmployees
              .map((e) => _RowEntity(id: e.email, name: e.fullName))
              .toList();
        }
      } else if (tableType == 'category') {
        final ouCategories = allCategories
            .where(
              (c) =>
                  c.statusMap[ou.id] == 'Active' &&
                  (selectedCategories.isEmpty ||
                      selectedCategories.contains(c.id)),
            )
            .toList();
        if (ouEmployees.isNotEmpty && ouCategories.isNotEmpty) {
          rowEntities = ouCategories
              .map((c) => _RowEntity(id: c.id, name: c.name))
              .toList();
        }
      } else {
        final visibleGroupIds = ouActivities
            .map((a) => a.activityGroupId)
            .toSet();
        final ouGroups = allGroups
            .where(
              (g) =>
                  visibleGroupIds.contains(g.id) &&
                  g.statusMap[ou.id] == 'Active' &&
                  (selectedActivityGroups.isEmpty ||
                      selectedActivityGroups.contains(g.id)),
            )
            .toList();
        if (ouEmployees.isNotEmpty && ouGroups.isNotEmpty) {
          rowEntities = ouGroups
              .map((g) => _RowEntity(id: g.id, name: g.name))
              .toList();
        }
      }

      if (rowEntities.isNotEmpty) {
        displayOUs.add(ou);
        ouEmployeesMap[ou.id] = ouEmployees;
        ouActivitiesMap[ou.id] = ouActivities;
        rowEntitiesMap[ou.id] = rowEntities;
      }
    }

    final grandAvailableMonthly = List.generate(12, (_) => 0.0);
    final grandPlannedMonthly = List.generate(12, (_) => 0.0);

    for (final ou in displayOUs) {
      final ouEmployees = ouEmployeesMap[ou.id]!;
      final ouActivities = ouActivitiesMap[ou.id]!;
      final rowEntities = rowEntitiesMap[ou.id]!;

      final groupHeaderValues = [ou.name, ...List.generate(13, (_) => '')];
      buffer.writeln(groupHeaderValues.map(csvEscape).join(','));

      final availableMonthly = List.generate(12, (mIdx) {
        double sum = 0.0;
        for (final emp in ouEmployees) {
          final caps = capacitiesCache[emp.email] ?? [];
          sum += CapacityCalculator.calculateMonthlyCapacity(
            caps,
            selectedYear,
            mIdx + 1,
          );
        }
        return sum;
      });
      _writeCsvRow(buffer, 'Available Capacity', availableMonthly, csvEscape);

      for (int mIdx = 0; mIdx < 12; mIdx++) {
        grandAvailableMonthly[mIdx] += availableMonthly[mIdx];
      }

      final middleRowsPlannedValues = <String, List<double>>{};
      for (final entity in rowEntities) {
        middleRowsPlannedValues[entity.id] = List.generate(12, (mIdx) {
          double val = 0.0;
          if (tableType == 'employee') {
            final empAllocs = allAllocations.where(
              (a) =>
                  a.userEmail == entity.id &&
                  a.year == selectedYear &&
                  a.orgUnitId ==
                      ouEmployees
                          .firstWhere((u) => u.email == entity.id)
                          .orgUnitId,
            );
            for (final alloc in empAllocs) {
              if (ouActivities.any((act) => act.id == alloc.activityId)) {
                val += _getAllocationMonthValue(alloc, mIdx + 1);
              }
            }
          } else if (tableType == 'category') {
            for (final emp in ouEmployees) {
              final empAllocs = allAllocations.where(
                (a) => a.userEmail == emp.email && a.year == selectedYear,
              );
              for (final alloc in empAllocs) {
                final activityMatches = ouActivities.where(
                  (act) =>
                      act.id == alloc.activityId && act.categoryId == entity.id,
                );
                if (activityMatches.isNotEmpty) {
                  val += _getAllocationMonthValue(alloc, mIdx + 1);
                }
              }
            }
          } else {
            for (final emp in ouEmployees) {
              final empAllocs = allAllocations.where(
                (a) => a.userEmail == emp.email && a.year == selectedYear,
              );
              for (final alloc in empAllocs) {
                final activityMatches = ouActivities.where(
                  (act) =>
                      act.id == alloc.activityId &&
                      act.activityGroupId == entity.id,
                );
                if (activityMatches.isNotEmpty) {
                  val += _getAllocationMonthValue(alloc, mIdx + 1);
                }
              }
            }
          }
          return val;
        });
      }

      final middleRowsValues = <String, List<double>>{};
      for (final entity in rowEntities) {
        final rowVal = List.generate(12, (mIdx) {
          if (tableType == 'employee') {
            if (_empRowDisplayMode == EmployeeRowDisplayMode.available) {
              final caps = capacitiesCache[entity.id] ?? [];
              return CapacityCalculator.calculateMonthlyCapacity(
                caps,
                selectedYear,
                mIdx + 1,
              );
            } else if (_empRowDisplayMode == EmployeeRowDisplayMode.delta) {
              final caps = capacitiesCache[entity.id] ?? [];
              final avail = CapacityCalculator.calculateMonthlyCapacity(
                caps,
                selectedYear,
                mIdx + 1,
              );
              final planned = middleRowsPlannedValues[entity.id]![mIdx];
              return avail - planned;
            } else {
              return middleRowsPlannedValues[entity.id]![mIdx];
            }
          } else {
            return middleRowsPlannedValues[entity.id]![mIdx];
          }
        });
        middleRowsValues[entity.id] = rowVal;
        _writeCsvRow(buffer, entity.name, rowVal, csvEscape);
      }

      final plannedMonthly = List.generate(12, (mIdx) {
        double sum = 0.0;
        for (final entity in rowEntities) {
          sum += middleRowsPlannedValues[entity.id]![mIdx];
        }
        return sum;
      });
      _writeCsvRow(buffer, 'Planned Capacity', plannedMonthly, csvEscape);

      for (int mIdx = 0; mIdx < 12; mIdx++) {
        grandPlannedMonthly[mIdx] += plannedMonthly[mIdx];
      }

      final deltaMonthly = List.generate(12, (mIdx) {
        return availableMonthly[mIdx] - plannedMonthly[mIdx];
      });
      _writeCsvRow(buffer, 'Delta', deltaMonthly, csvEscape);
    }

    if (displayOUs.length > 1) {
      buffer.writeln(
        ['Total', ...List.generate(13, (_) => '')].map(csvEscape).join(','),
      );
      _writeCsvRow(
        buffer,
        'Total Available Capacity',
        grandAvailableMonthly,
        csvEscape,
      );
      _writeCsvRow(
        buffer,
        'Total Planned Capacity',
        grandPlannedMonthly,
        csvEscape,
      );
      final grandDeltaMonthly = List.generate(
        12,
        (i) => grandAvailableMonthly[i] - grandPlannedMonthly[i],
      );
      _writeCsvRow(buffer, 'Total Delta', grandDeltaMonthly, csvEscape);
    }

    final sanitizedTitle = (tableType == 'employee'
        ? 'employees'
        : (tableType == 'category' ? 'categories' : 'activity_groups'));
    final fileName = 'reports_${sanitizedTitle}_$selectedYear.csv';
    saveCsvFile(buffer.toString(), fileName);
  }

  void _writeCsvRow(
    StringBuffer buffer,
    String title,
    List<double> values,
    String Function(String) csvEscape,
  ) {
    final rowSum = values.fold(0.0, (sum, val) => sum + val);
    final rowValues = <String>[
      title,
      ...values.map(
        (val) => val == 0
            ? '0'
            : val.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
      ),
      rowSum == 0
          ? '0'
          : rowSum.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
    ];
    buffer.writeln(rowValues.map(csvEscape).join(','));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final queryYears = {
      _agSelectedYear,
      _catSelectedYear,
      _empSelectedYear,
      _agSelectedYear - 1, _agSelectedYear + 1,
      _catSelectedYear - 1, _catSelectedYear + 1,
      _empSelectedYear - 1, _empSelectedYear + 1,
    }.toList()..sort();
    final String yearsCsv = queryYears.join(',');

    // Watch global data streams
    final allOrgs = ref.watch(orgUnitsStreamProvider).value ?? [];
    final allUsers = ref.watch(allUsersStreamProvider).value ?? [];
    final allActivities = ref.watch(activitiesStreamProvider).value ?? [];
    final allCategories = ref.watch(categoriesStreamProvider).value ?? [];
    final allGroups = ref.watch(activityGroupsStreamProvider).value ?? [];
    final allAllocations =
        ref.watch(allPlanningAllocationsStreamProvider(yearsCsv)).value ?? [];

    _initializeAllowedOrgUnits(currentUser, allOrgs);

    final agActiveOUIds = _agSelectedOrgUnits.isEmpty
        ? _allowedOrgUnits.map((o) => o.id).toList()
        : _agSelectedOrgUnits;
    final agFilteredEmployees = allUsers
        .where(
          (u) =>
              u.status == 'Active' &&
              u.orgUnitId != null &&
              agActiveOUIds.contains(u.orgUnitId!),
        )
        .toList();
    final agYears = _getYearDropdownValues(
      selectedEmployees: _agSelectedEmployees,
      filteredEmployees: agFilteredEmployees,
      allocations: allAllocations,
    );

    final catActiveOUIds = _catSelectedOrgUnits.isEmpty
        ? _allowedOrgUnits.map((o) => o.id).toList()
        : _catSelectedOrgUnits;
    final catFilteredEmployees = allUsers
        .where(
          (u) =>
              u.status == 'Active' &&
              u.orgUnitId != null &&
              catActiveOUIds.contains(u.orgUnitId!),
        )
        .toList();
    final catYears = _getYearDropdownValues(
      selectedEmployees: _catSelectedEmployees,
      filteredEmployees: catFilteredEmployees,
      allocations: allAllocations,
    );

    final empActiveOUIds = _empSelectedOrgUnits.isEmpty
        ? _allowedOrgUnits.map((o) => o.id).toList()
        : _empSelectedOrgUnits;
    final empFilteredEmployees = allUsers
        .where(
          (u) =>
              u.status == 'Active' &&
              u.orgUnitId != null &&
              empActiveOUIds.contains(u.orgUnitId!),
        )
        .toList();
    final empYears = _getYearDropdownValues(
      selectedEmployees: _empSelectedEmployees,
      filteredEmployees: empFilteredEmployees,
      allocations: allAllocations,
    );

    if (_allowedOrgUnits.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        body: Center(
          child: Text(
            'You are not associated with any active organization unit.',
            style: theme.textTheme.titleMedium,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title & Segmented Button Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reports',
                  key: const Key('reports_title_header'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                 M3SegmentedButton<String>(
                  segmentedButtonKey: const Key('reports_view_segmented_button'),
                  segments: const [
                    ButtonSegment(
                      value: 'reports',
                      label: Text('Reports View'),
                    ),
                    ButtonSegment(
                      value: 'dashboard',
                      label: Text('Dashboard View'),
                    ),
                  ],
                  selected: const {'reports'},
                  onSelectionChanged: (val) {
                    if (val.first == 'dashboard') {
                      context.go(RouterPaths.dashboards);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Section 1: Activity Groups
            _buildSectionHeader(
              'Activity Groups',
              () => _exportTableAsCsv(
                tableType: 'activityGroup',
                selectedYear: _agSelectedYear,
                selectedOrgUnits: _agSelectedOrgUnits,
                selectedEmployees: _agSelectedEmployees,
                selectedActivityGroups: _agSelectedActivityGroups,
                selectedCategories: _agSelectedCategories,
                allUsers: allUsers,
                allActivities: allActivities,
                allCategories: allCategories,
                allGroups: allGroups,
                allAllocations: allAllocations,
              ),
            ),
            const SizedBox(height: 16),
            _buildFiltersRow(
              theme: theme,
              sectionPrefix: 'ag',
              selectedYear: _agSelectedYear,
              selectedOrgUnits: _agSelectedOrgUnits,
              selectedEmployees: _agSelectedEmployees,
              selectedActivityGroups: _agSelectedActivityGroups,
              selectedCategories: _agSelectedCategories,
              allUsers: allUsers,
              allActivities: allActivities,
              allCategories: allCategories,
              allGroups: allGroups,
              onYearChanged: (y) => setState(() => _agSelectedYear = y),
              onOrgUnitsChanged: (val) => setState(() {
                _agSelectedOrgUnits = val;
                _agSelectedEmployees.clear();
                _agSelectedActivityGroups.clear();
                _agSelectedCategories.clear();
              }),
              onEmployeesChanged: (val) =>
                  setState(() => _agSelectedEmployees = val),
              onActivityGroupsChanged: (val) =>
                  setState(() => _agSelectedActivityGroups = val),
              onCategoriesChanged: (val) =>
                  setState(() => _agSelectedCategories = val),
              years: agYears,
            ),
            const SizedBox(height: 16),
            _buildTableContainer(
              theme: theme,
              tableType: 'activityGroup',
              selectedYear: _agSelectedYear,
              selectedOrgUnits: _agSelectedOrgUnits,
              selectedEmployees: _agSelectedEmployees,
              selectedActivityGroups: _agSelectedActivityGroups,
              selectedCategories: _agSelectedCategories,
              allUsers: allUsers,
              allActivities: allActivities,
              allCategories: allCategories,
              allGroups: allGroups,
              allAllocations: allAllocations,
            ),
            const SizedBox(height: 48),

            // Section 2: Categories
            _buildSectionHeader(
              'Categories',
              () => _exportTableAsCsv(
                tableType: 'category',
                selectedYear: _catSelectedYear,
                selectedOrgUnits: _catSelectedOrgUnits,
                selectedEmployees: _catSelectedEmployees,
                selectedActivityGroups: _catSelectedActivityGroups,
                selectedCategories: _catSelectedCategories,
                allUsers: allUsers,
                allActivities: allActivities,
                allCategories: allCategories,
                allGroups: allGroups,
                allAllocations: allAllocations,
              ),
            ),
            const SizedBox(height: 16),
            _buildFiltersRow(
              theme: theme,
              sectionPrefix: 'cat',
              selectedYear: _catSelectedYear,
              selectedOrgUnits: _catSelectedOrgUnits,
              selectedEmployees: _catSelectedEmployees,
              selectedActivityGroups: _catSelectedActivityGroups,
              selectedCategories: _catSelectedCategories,
              allUsers: allUsers,
              allActivities: allActivities,
              allCategories: allCategories,
              allGroups: allGroups,
              onYearChanged: (y) => setState(() => _catSelectedYear = y),
              onOrgUnitsChanged: (val) => setState(() {
                _catSelectedOrgUnits = val;
                _catSelectedEmployees.clear();
                _catSelectedActivityGroups.clear();
                _catSelectedCategories.clear();
              }),
              onEmployeesChanged: (val) =>
                  setState(() => _catSelectedEmployees = val),
              onActivityGroupsChanged: (val) =>
                  setState(() => _catSelectedActivityGroups = val),
              onCategoriesChanged: (val) =>
                  setState(() => _catSelectedCategories = val),
              years: catYears,
            ),
            const SizedBox(height: 16),
            _buildTableContainer(
              theme: theme,
              tableType: 'category',
              selectedYear: _catSelectedYear,
              selectedOrgUnits: _catSelectedOrgUnits,
              selectedEmployees: _catSelectedEmployees,
              selectedActivityGroups: _catSelectedActivityGroups,
              selectedCategories: _catSelectedCategories,
              allUsers: allUsers,
              allActivities: allActivities,
              allCategories: allCategories,
              allGroups: allGroups,
              allAllocations: allAllocations,
            ),
            const SizedBox(height: 48),

            // Section 3: Employees
            _buildSectionHeader(
              'Employees',
              () => _exportTableAsCsv(
                tableType: 'employee',
                selectedYear: _empSelectedYear,
                selectedOrgUnits: _empSelectedOrgUnits,
                selectedEmployees: _empSelectedEmployees,
                selectedActivityGroups: _empSelectedActivityGroups,
                selectedCategories: _empSelectedCategories,
                allUsers: allUsers,
                allActivities: allActivities,
                allCategories: allCategories,
                allGroups: allGroups,
                allAllocations: allAllocations,
              ),
               additionalWidget: M3SegmentedButton<EmployeeRowDisplayMode>(
                segments: const [
                  ButtonSegment<EmployeeRowDisplayMode>(
                    value: EmployeeRowDisplayMode.available,
                    label: Text('Available'),
                  ),
                  ButtonSegment<EmployeeRowDisplayMode>(
                    value: EmployeeRowDisplayMode.planned,
                    label: Text('Planned'),
                  ),
                  ButtonSegment<EmployeeRowDisplayMode>(
                    value: EmployeeRowDisplayMode.delta,
                    label: Text('Delta'),
                  ),
                ],
                selected: {_empRowDisplayMode},
                onSelectionChanged: (Set<EmployeeRowDisplayMode> newSelection) {
                  setState(() {
                    _empRowDisplayMode = newSelection.first;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildFiltersRow(
              theme: theme,
              sectionPrefix: 'emp',
              selectedYear: _empSelectedYear,
              selectedOrgUnits: _empSelectedOrgUnits,
              selectedEmployees: _empSelectedEmployees,
              selectedActivityGroups: _empSelectedActivityGroups,
              selectedCategories: _empSelectedCategories,
              allUsers: allUsers,
              allActivities: allActivities,
              allCategories: allCategories,
              allGroups: allGroups,
              onYearChanged: (y) => setState(() => _empSelectedYear = y),
              onOrgUnitsChanged: (val) => setState(() {
                _empSelectedOrgUnits = val;
                _empSelectedEmployees.clear();
                _empSelectedActivityGroups.clear();
                _empSelectedCategories.clear();
              }),
              onEmployeesChanged: (val) =>
                  setState(() => _empSelectedEmployees = val),
              onActivityGroupsChanged: (val) =>
                  setState(() => _empSelectedActivityGroups = val),
              onCategoriesChanged: (val) =>
                  setState(() => _empSelectedCategories = val),
              years: empYears,
            ),
            const SizedBox(height: 16),
            _buildTableContainer(
              theme: theme,
              tableType: 'employee',
              selectedYear: _empSelectedYear,
              selectedOrgUnits: _empSelectedOrgUnits,
              selectedEmployees: _empSelectedEmployees,
              selectedActivityGroups: _empSelectedActivityGroups,
              selectedCategories: _empSelectedCategories,
              allUsers: allUsers,
              allActivities: allActivities,
              allCategories: allCategories,
              allGroups: allGroups,
              allAllocations: allAllocations,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    VoidCallback onExportCsv, {
    Widget? additionalWidget,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (additionalWidget != null) ...[
              additionalWidget,
              const SizedBox(width: 8),
            ],
            Directionality(
              textDirection: TextDirection.rtl,
              child: MenuAnchor(
                builder: (context, controller, child) {
                  return IconButton(
                    key: Key(
                      'export_csv_button_${title.toLowerCase().replaceAll(' ', '_')}',
                    ),
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
                      onPressed: onExportCsv,
                      child: const Text('Export as CSV'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFiltersRow({
    required ThemeData theme,
    required String sectionPrefix,
    required int selectedYear,
    required List<String> selectedOrgUnits,
    required List<String> selectedEmployees,
    required List<String> selectedActivityGroups,
    required List<String> selectedCategories,
    required List<UserModel> allUsers,
    required List<ActivityModel> allActivities,
    required List<CategoryModel> allCategories,
    required List<ActivityGroupModel> allGroups,
    required ValueChanged<int> onYearChanged,
    required ValueChanged<List<String>> onOrgUnitsChanged,
    required ValueChanged<List<String>> onEmployeesChanged,
    required ValueChanged<List<String>> onActivityGroupsChanged,
    required ValueChanged<List<String>> onCategoriesChanged,
    required List<int> years,
  }) {
    // Determine active OUs based on selection or fallback to all allowed
    final activeOUIds = selectedOrgUnits.isEmpty
        ? _allowedOrgUnits.map((o) => o.id).toList()
        : selectedOrgUnits;

    // Filter active employees belonging to active OUs
    final filteredEmployees = allUsers
        .where(
          (u) =>
              u.status == 'Active' &&
              u.orgUnitId != null &&
              activeOUIds.contains(u.orgUnitId!),
        )
        .toList();

    // Filter active categories for active OUs
    final filteredCategories = allCategories
        .where((c) => activeOUIds.any((ouId) => c.statusMap[ouId] == 'Active'))
        .toList();

    // Filter active groups for active OUs
    final filteredGroups = allGroups
        .where((g) => activeOUIds.any((ouId) => g.statusMap[ouId] == 'Active'))
        .toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Year Dropdown
        Tooltip(
          message: 'Select Year',
          child: MenuAnchor(
            builder: (context, controller, child) {
              return FilterChip(
                key: Key('filter_${sectionPrefix}_year_dropdown'),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(selectedYear.toString()),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 18),
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
                key: Key('filter_${sectionPrefix}_year_item_$y'),
                onPressed: () => onYearChanged(y),
                child: Text(y.toString()),
              );
            }).toList(),
          ),
        ),

        // Organization Unit Filter
        _buildMultiSelectFilterChip(
          label: 'Organization Unit',
          keyPrefix: '${sectionPrefix}_org_unit',
          items: _allowedOrgUnits
              .map((o) => DropdownMenuItem(value: o.id, child: Text(o.name)))
              .toList(),
          selectedValues: selectedOrgUnits,
          onChanged: onOrgUnitsChanged,
          theme: theme,
        ),

        // Employees Filter
        _buildMultiSelectFilterChip(
          label: 'Employee',
          keyPrefix: '${sectionPrefix}_employee',
          items: filteredEmployees
              .map(
                (u) =>
                    DropdownMenuItem(value: u.email, child: Text(u.fullName)),
              )
              .toList(),
          selectedValues: selectedEmployees,
          onChanged: onEmployeesChanged,
          theme: theme,
        ),

        // Activity Groups Filter
        _buildMultiSelectFilterChip(
          label: 'Activity Group',
          keyPrefix: '${sectionPrefix}_activity_group',
          items: filteredGroups
              .map((g) => DropdownMenuItem(value: g.id, child: Text(g.name)))
              .toList(),
          selectedValues: selectedActivityGroups,
          onChanged: onActivityGroupsChanged,
          theme: theme,
        ),

        // Categories Filter
        _buildMultiSelectFilterChip(
          label: 'Category',
          keyPrefix: '${sectionPrefix}_category',
          items: filteredCategories
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
              .toList(),
          selectedValues: selectedCategories,
          onChanged: onCategoriesChanged,
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildMultiSelectFilterChip({
    required String label,
    required String keyPrefix,
    required List<DropdownMenuItem<String>> items,
    required List<String> selectedValues,
    required ValueChanged<List<String>> onChanged,
    required ThemeData theme,
  }) {
    final bool isAllSelected = selectedValues.isEmpty;
    final String displayLabel = isAllSelected
        ? (label == 'Category' ? 'All Categories' : 'All ${label}s')
        : '${selectedValues.length} Selected';

    return MenuAnchor(
      builder: (context, controller, child) {
        return Tooltip(
          message: 'Select $label',
          child: FilterChip(
            key: Key('filter_${keyPrefix}_dropdown'),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(displayLabel),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
            selected: !isAllSelected,
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
          key: Key('filter_${keyPrefix}_item_$sanitizedValue'),
          value: isChecked,
          onChanged: (checked) {
            if (checked == null) return;
            final newValues = List<String>.from(selectedValues);
            if (checked) {
              newValues.add(item.value!);
            } else {
              newValues.remove(item.value);
            }
            onChanged(newValues);
          },
          child: item.child,
        );
      }).toList(),
    );
  }

  Widget _buildTableContainer({
    required ThemeData theme,
    required String tableType, // 'employee', 'category', or 'activityGroup'
    required int selectedYear,
    required List<String> selectedOrgUnits,
    required List<String> selectedEmployees,
    required List<String> selectedActivityGroups,
    required List<String> selectedCategories,
    required List<UserModel> allUsers,
    required List<ActivityModel> allActivities,
    required List<CategoryModel> allCategories,
    required List<ActivityGroupModel> allGroups,
    required List<PlanningAllocationModel> allAllocations,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double fixedColWidth = 250.0;
        final double defaultScrollWidth = 12 * 80.0 + 100.0;
        final double availableScrollWidth =
            constraints.maxWidth - fixedColWidth - 1.0;
        double scale = 1.0;
        if (defaultScrollWidth < availableScrollWidth) {
          scale = availableScrollWidth / defaultScrollWidth;
        }

        final double monthWidth = 80.0 * scale;
        final double sumWidth = 100.0 * scale;
        final double totalTableWidth =
            fixedColWidth + 12 * monthWidth + sumWidth + 1.0;

        final activeOUIds = selectedOrgUnits.isEmpty
            ? _allowedOrgUnits.map((o) => o.id).toList()
            : selectedOrgUnits;

        // Filter org units based on selection
        final targetOUs = _allowedOrgUnits
            .where((o) => activeOUIds.contains(o.id))
            .toList();

        // Cache employee capacities
        final capacitiesCache = <String, List<UserCapacityModel>>{};
        for (final u in allUsers) {
          if (u.status == 'Active' && u.orgUnitId != null) {
            final caps =
                ref.watch(userCapacitiesStreamProvider(u.email)).value ?? [];
            capacitiesCache[u.email] = caps;
          }
        }

        final List<Widget> tableSections = [];
        final displayOUs = <OrgUnitModel>[];
        final Map<String, List<UserModel>> ouEmployeesMap = {};
        final Map<String, List<ActivityModel>> ouActivitiesMap = {};
        final Map<String, List<_RowEntity>> rowEntitiesMap = {};

        for (final ou in targetOUs) {
          final ouEmployees = allUsers
              .where(
                (u) =>
                    u.orgUnitId == ou.id &&
                    u.status == 'Active' &&
                    (selectedEmployees.isEmpty ||
                        selectedEmployees.contains(u.email)),
              )
              .toList();

          final ouActivities = allActivities.where((act) {
            final isAssociated =
                act.ownerOrgUnitId == ou.id ||
                act.sharedOrgUnitIds.contains(ou.id) ||
                act.appliedOrgUnitIds.contains(ou.id);
            final isActive = act.statusMap[ou.id] == 'Active';
            final isWithinValidity =
                act.type != 'Limited' ||
                ((act.validityStart == null ||
                        act.validityStart!.year <= selectedYear) &&
                    (act.validityEnd == null ||
                        act.validityEnd!.year >= selectedYear));
            final matchesCategory =
                selectedCategories.isEmpty ||
                (act.categoryId != null &&
                    selectedCategories.contains(act.categoryId));
            return isAssociated &&
                isActive &&
                isWithinValidity &&
                matchesCategory;
          }).toList();

          List<_RowEntity> rowEntities = [];
          if (tableType == 'employee') {
            if (ouEmployees.isNotEmpty) {
              rowEntities = ouEmployees
                  .map((e) => _RowEntity(id: e.email, name: e.fullName))
                  .toList();
            }
          } else if (tableType == 'category') {
            final ouCategories = allCategories
                .where(
                  (c) =>
                      c.statusMap[ou.id] == 'Active' &&
                      (selectedCategories.isEmpty ||
                          selectedCategories.contains(c.id)),
                )
                .toList();
            if (ouEmployees.isNotEmpty && ouCategories.isNotEmpty) {
              rowEntities = ouCategories
                  .map((c) => _RowEntity(id: c.id, name: c.name))
                  .toList();
            }
          } else {
            final visibleGroupIds = ouActivities
                .map((a) => a.activityGroupId)
                .toSet();
            final ouGroups = allGroups
                .where(
                  (g) =>
                      visibleGroupIds.contains(g.id) &&
                      g.statusMap[ou.id] == 'Active' &&
                      (selectedActivityGroups.isEmpty ||
                          selectedActivityGroups.contains(g.id)),
                )
                .toList();
            if (ouEmployees.isNotEmpty && ouGroups.isNotEmpty) {
              rowEntities = ouGroups
                  .map((g) => _RowEntity(id: g.id, name: g.name))
                  .toList();
            }
          }

          if (rowEntities.isNotEmpty) {
            displayOUs.add(ou);
            ouEmployeesMap[ou.id] = ouEmployees;
            ouActivitiesMap[ou.id] = ouActivities;
            rowEntitiesMap[ou.id] = rowEntities;
          }
        }

        // Grand Total accumulators
        final grandAvailableMonthly = List.generate(12, (_) => 0.0);
        final grandPlannedMonthly = List.generate(12, (_) => 0.0);

        for (int i = 0; i < displayOUs.length; i++) {
          final ou = displayOUs[i];
          final ouEmployees = ouEmployeesMap[ou.id]!;
          final ouActivities = ouActivitiesMap[ou.id]!;
          final rowEntities = rowEntitiesMap[ou.id]!;
          final isLastSection = (i == displayOUs.length - 1);

          final sectionWidget = _buildOrgUnitSection(
            theme: theme,
            ouName: ou.name,
            selectedYear: selectedYear,
            ouEmployees: ouEmployees,
            ouActivities: ouActivities,
            allAllocations: allAllocations,
            capacitiesCache: capacitiesCache,
            rowEntities: rowEntities,
            tableType: tableType,
            monthWidth: monthWidth,
            sumWidth: sumWidth,
            isLastSectionAndNoGrandTotal:
                isLastSection && (displayOUs.length <= 1),
          );
          tableSections.add(sectionWidget);

          // Accumulate grand totals
          for (int mIdx = 0; mIdx < 12; mIdx++) {
            // Available
            for (final emp in ouEmployees) {
              final caps = capacitiesCache[emp.email] ?? [];
              grandAvailableMonthly[mIdx] +=
                  CapacityCalculator.calculateMonthlyCapacity(
                    caps,
                    selectedYear,
                    mIdx + 1,
                  );
            }
            // Planned
            if (tableType == 'employee') {
              for (final emp in ouEmployees) {
                final empAllocs = allAllocations.where(
                  (a) =>
                      a.userEmail == emp.email &&
                      a.year == selectedYear &&
                      a.orgUnitId == emp.orgUnitId,
                );
                for (final alloc in empAllocs) {
                  if (ouActivities.any((act) => act.id == alloc.activityId)) {
                    grandPlannedMonthly[mIdx] += _getAllocationMonthValue(
                      alloc,
                      mIdx + 1,
                    );
                  }
                }
              }
            } else if (tableType == 'category') {
              for (final entity in rowEntities) {
                for (final emp in ouEmployees) {
                  final empAllocs = allAllocations.where(
                    (a) => a.userEmail == emp.email && a.year == selectedYear,
                  );
                  for (final alloc in empAllocs) {
                    if (ouActivities.any(
                      (act) =>
                          act.id == alloc.activityId &&
                          act.categoryId == entity.id,
                    )) {
                      grandPlannedMonthly[mIdx] += _getAllocationMonthValue(
                        alloc,
                        mIdx + 1,
                      );
                    }
                  }
                }
              }
            } else {
              for (final entity in rowEntities) {
                for (final emp in ouEmployees) {
                  final empAllocs = allAllocations.where(
                    (a) => a.userEmail == emp.email && a.year == selectedYear,
                  );
                  for (final alloc in empAllocs) {
                    if (ouActivities.any(
                      (act) =>
                          act.id == alloc.activityId &&
                          act.activityGroupId == entity.id,
                    )) {
                      grandPlannedMonthly[mIdx] += _getAllocationMonthValue(
                        alloc,
                        mIdx + 1,
                      );
                    }
                  }
                }
              }
            }
          }
        }

        if (tableSections.isEmpty) {
          return Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            child: Text(
              'No data matching the selected filters.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        final grandDeltaMonthly = List.generate(
          12,
          (i) => grandAvailableMonthly[i] - grandPlannedMonthly[i],
        );

        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              width: totalTableWidth,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    _buildTableHeader(theme, monthWidth, sumWidth, tableType),
                    ...tableSections,

                    // Grand Total Section (only if displayOUs.length > 1)
                    if (displayOUs.length > 1) ...[
                      // Group Header Row
                      Container(
                        width: fixedColWidth + monthWidth * 12 + sumWidth,
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainer,
                          border: Border(
                            top: BorderSide.none,
                            bottom: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Text(
                          'Total',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      // Available Capacity
                      _buildDataRow(
                        theme: theme,
                        title: 'Total Available Capacity',
                        values: grandAvailableMonthly,
                        backgroundColor: theme.colorScheme.tertiaryContainer,
                        textColor: theme.colorScheme.onTertiaryContainer,
                        isBold: true,
                        monthWidth: monthWidth,
                        sumWidth: sumWidth,
                        tooltipMessage: tableType == 'employee'
                            ? "Available Capacity is calculated from the employee's standard weekly working hours and any specific capacity overrides/contracts for this period."
                            : "Available Capacity is the sum of available capacity of all employees in the organization unit.",
                      ),
                      // Planned Capacity
                      _buildDataRow(
                        theme: theme,
                        title: 'Total Planned Capacity',
                        values: grandPlannedMonthly,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        textColor: theme.colorScheme.onPrimaryContainer,
                        isBold: true,
                        monthWidth: monthWidth,
                        sumWidth: sumWidth,
                        tooltipMessage: tableType == 'employee'
                            ? "Planned Capacity represents the sum of all time allocations assigned to the employee."
                            : "Planned Capacity represents the sum of all allocations assigned to the activities in this category/group.",
                      ),
                      // Delta
                      _buildDataRow(
                        theme: theme,
                        title: 'Total Delta',
                        values: grandDeltaMonthly,
                        backgroundColor: Colors.transparent,
                        isBold: true,
                        isDelta: true,
                        monthWidth: monthWidth,
                        sumWidth: sumWidth,
                        isLastRow: true,
                        tooltipMessage: tableType == 'employee'
                            ? "Delta = Available Capacity - Planned Capacity (total activity allocations for this employee)"
                            : "Delta = Available Capacity - Planned Capacity",
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(
    ThemeData theme,
    double monthWidth,
    double sumWidth,
    String tableType,
  ) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 250,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            ),
            child: Text(
              tableType == 'employee'
                  ? 'Employees'
                  : (tableType == 'category'
                        ? 'Categories'
                        : 'Activity Groups'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...months.map(
            (m) => Container(
              width: monthWidth,
              alignment: Alignment.center,
              padding: EdgeInsets.zero,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
              ),
              child: Text(
                m.substring(0, 3),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Container(
            width: sumWidth,
            alignment: Alignment.center,
            padding: EdgeInsets.zero,
            child: Text(
              'Sum',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrgUnitSection({
    required ThemeData theme,
    required String ouName,
    required int selectedYear,
    required List<UserModel> ouEmployees,
    required List<ActivityModel> ouActivities,
    required List<PlanningAllocationModel> allAllocations,
    required Map<String, List<UserCapacityModel>> capacitiesCache,
    required List<_RowEntity> rowEntities,
    required String tableType,
    required double monthWidth,
    required double sumWidth,
    required bool isLastSectionAndNoGrandTotal,
  }) {
    final availableMonthly = List.generate(12, (mIdx) {
      double sum = 0.0;
      for (final emp in ouEmployees) {
        final caps = capacitiesCache[emp.email] ?? [];
        sum += CapacityCalculator.calculateMonthlyCapacity(
          caps,
          selectedYear,
          mIdx + 1,
        );
      }
      return sum;
    });

    // Middle rows cell values (planned)
    final middleRowsPlannedValues = <String, List<double>>{};
    for (final entity in rowEntities) {
      middleRowsPlannedValues[entity.id] = List.generate(12, (mIdx) {
        double val = 0.0;
        if (tableType == 'employee') {
          // Employee table: Sum allocations for this employee for active activities in this org unit
          final empAllocs = allAllocations.where(
            (a) =>
                a.userEmail == entity.id &&
                a.year == selectedYear &&
                a.orgUnitId ==
                    ouEmployees
                        .firstWhere((u) => u.email == entity.id)
                        .orgUnitId,
          );
          for (final alloc in empAllocs) {
            final existsInActivities = ouActivities.any(
              (act) => act.id == alloc.activityId,
            );
            if (existsInActivities) {
              val += _getAllocationMonthValue(alloc, mIdx + 1);
            }
          }
        } else if (tableType == 'category') {
          // Categories table: Sum allocations for all activities belonging to this category, for all employees in this org unit
          for (final emp in ouEmployees) {
            final empAllocs = allAllocations.where(
              (a) => a.userEmail == emp.email && a.year == selectedYear,
            );
            for (final alloc in empAllocs) {
              final activityMatches = ouActivities.where(
                (act) =>
                    act.id == alloc.activityId && act.categoryId == entity.id,
              );
              if (activityMatches.isNotEmpty) {
                val += _getAllocationMonthValue(alloc, mIdx + 1);
              }
            }
          }
        } else {
          // Activity Groups table: Sum allocations for all activities in this group for all employees in this org unit
          for (final emp in ouEmployees) {
            final empAllocs = allAllocations.where(
              (a) => a.userEmail == emp.email && a.year == selectedYear,
            );
            for (final alloc in empAllocs) {
              final activityMatches = ouActivities.where(
                (act) =>
                    act.id == alloc.activityId &&
                    act.activityGroupId == entity.id,
              );
              if (activityMatches.isNotEmpty) {
                val += _getAllocationMonthValue(alloc, mIdx + 1);
              }
            }
          }
        }
        return val;
      });
    }

    // Planned Capacity Month Values
    final plannedMonthly = List.generate(12, (mIdx) {
      double sum = 0.0;
      for (final entity in rowEntities) {
        sum += middleRowsPlannedValues[entity.id]![mIdx];
      }
      return sum;
    });

    // Delta Month Values
    final deltaMonthly = List.generate(12, (mIdx) {
      return availableMonthly[mIdx] - plannedMonthly[mIdx];
    });

    // Display values for middle rows
    final middleRowsValues = <String, List<double>>{};
    for (final entity in rowEntities) {
      middleRowsValues[entity.id] = List.generate(12, (mIdx) {
        if (tableType == 'employee') {
          if (_empRowDisplayMode == EmployeeRowDisplayMode.available) {
            final caps = capacitiesCache[entity.id] ?? [];
            return CapacityCalculator.calculateMonthlyCapacity(
              caps,
              selectedYear,
              mIdx + 1,
            );
          } else if (_empRowDisplayMode == EmployeeRowDisplayMode.delta) {
            final caps = capacitiesCache[entity.id] ?? [];
            final avail = CapacityCalculator.calculateMonthlyCapacity(
              caps,
              selectedYear,
              mIdx + 1,
            );
            final planned = middleRowsPlannedValues[entity.id]![mIdx];
            return avail - planned;
          } else {
            return middleRowsPlannedValues[entity.id]![mIdx];
          }
        } else {
          return middleRowsPlannedValues[entity.id]![mIdx];
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Group Header Row (Org Unit name spanning all columns)
        Container(
          width: 250 + monthWidth * 12 + sumWidth,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.4),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
          ),
          child: Text(
            ouName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),

        // 2. Available Capacity Row
        _buildDataRow(
          theme: theme,
          title: 'Available Capacity',
          values: availableMonthly,
          backgroundColor: theme.colorScheme.tertiaryContainer,
          textColor: theme.colorScheme.onTertiaryContainer,
          isBold: true,
          monthWidth: monthWidth,
          sumWidth: sumWidth,
          tooltipMessage: tableType == 'employee'
              ? "Available Capacity is calculated from the employee's standard weekly working hours and any specific capacity overrides/contracts for this period."
              : "Available Capacity is the sum of available capacity of all employees in the organization unit.",
        ),

        // 3. Row for each middle entity (Category, Activity Group or Employee)
        ...rowEntities.map((entity) {
          final vals = middleRowsValues[entity.id]!;
          final isEmpDelta = tableType == 'employee' &&
              _empRowDisplayMode == EmployeeRowDisplayMode.delta;
          return _buildDataRow(
            theme: theme,
            title: entity.name,
            values: vals,
            isBold: false,
            isDelta: isEmpDelta,
            monthWidth: monthWidth,
            sumWidth: sumWidth,
          );
        }),

        // 4. Planned Capacity Row
        _buildDataRow(
          theme: theme,
          title: 'Planned Capacity',
          values: plannedMonthly,
          backgroundColor: theme.colorScheme.primaryContainer,
          textColor: theme.colorScheme.onPrimaryContainer,
          isBold: true,
          monthWidth: monthWidth,
          sumWidth: sumWidth,
          tooltipMessage: tableType == 'employee'
              ? "Planned Capacity represents the sum of all time allocations assigned to the employee."
              : "Planned Capacity represents the sum of all allocations assigned to the activities in this category/group.",
        ),

        // 5. Delta Row
        _buildDataRow(
          theme: theme,
          title: 'Delta',
          values: deltaMonthly,
          backgroundColor: Colors.transparent,
          isBold: true,
          isDelta: true,
          monthWidth: monthWidth,
          sumWidth: sumWidth,
          isLastRow: isLastSectionAndNoGrandTotal,
          tooltipMessage: tableType == 'employee'
              ? "Delta = Available Capacity - Planned Capacity (total activity allocations for this employee)"
              : "Delta = Available Capacity - Planned Capacity",
        ),
      ],
    );
  }

  Widget _buildDataRow({
    required ThemeData theme,
    required String title,
    required List<double> values,
    Color? backgroundColor,
    Color? textColor,
    required bool isBold,
    bool isDelta = false,
    required double monthWidth,
    required double sumWidth,
    bool isLastRow = false,
    String? tooltipMessage,
  }) {
    final double rowSum = values.fold(0.0, (sum, val) => sum + val);

    final isDark = theme.brightness == Brightness.dark;
    final errorColor = isDark
        ? const Color(0xFFE57373)
        : const Color(0xFFD32F2F);
    final successColor = isDark
        ? const Color(0xFF81C784)
        : const Color(0xFF2E7D32);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        border: Border(
          bottom: isLastRow
              ? BorderSide.none
              : BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Name cell
          Container(
            width: 250,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            ),
            child: tooltipMessage != null
                ? Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                            color: textColor ?? theme.colorScheme.onSurface,
                          ),
                        ),
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: SizedBox(width: 4),
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Tooltip(
                            message: tooltipMessage,
                            margin: EdgeInsets.zero,
                            positionDelegate: (TooltipPositionContext context) {
                              return Offset(
                                context.target.dx + (context.targetSize.width / 2) + 8,
                                context.target.dy - (context.tooltipSize.height / 2),
                              );
                            },
                            child: Icon(
                              Icons.info_outline,
                              size: 14,
                              color: (textColor ?? theme.colorScheme.onSurface)
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                      color: textColor ?? theme.colorScheme.onSurface,
                    ),
                  ),
          ),
          // Months cells
          ...List.generate(12, (index) {
            final val = values[index];
            final displayVal = val == 0
                ? '0'
                : val.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
            final Color cellTextColor = isDelta
                ? (val < 0
                      ? errorColor
                      : (val > 0
                            ? successColor
                            : theme.colorScheme.onSurfaceVariant))
                : (textColor ?? theme.colorScheme.onSurfaceVariant);

            return Container(
              width: monthWidth,
              alignment: Alignment.center,
              padding: EdgeInsets.zero,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
              ),
              child: Text(
                displayVal,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: cellTextColor,
                ),
              ),
            );
          }),
          // Sum cell
          Container(
            width: sumWidth,
            alignment: Alignment.center,
            padding: EdgeInsets.zero,
            child: Text(
              rowSum == 0
                  ? '0'
                  : rowSum.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDelta
                    ? (rowSum < 0
                          ? errorColor
                          : (rowSum > 0
                                ? successColor
                                : theme.colorScheme.onSurface))
                    : (textColor ?? theme.colorScheme.onSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowEntity {
  final String id;
  final String name;
  const _RowEntity({required this.id, required this.name});
}
