// File: lib/views/standard/dashboards_view.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/router_paths.dart';
import '../../core/providers/providers.dart';
import '../../core/utils/capacity_calculator.dart';
import '../../models/org_unit_model.dart';
import '../../models/user_model.dart';
import 'm3_segmented_button.dart';

class DashboardsView extends ConsumerStatefulWidget {
  const DashboardsView({super.key});

  @override
  ConsumerState<DashboardsView> createState() => _DashboardsViewState();
}

class _DashboardsViewState extends ConsumerState<DashboardsView> {
  int _selectedYear = DateTime.now().year;
  List<String> _selectedOrgUnits = [];
  List<String> _selectedEmployees = [];
  List<String> _selectedActivityGroups = [];
  List<String> _selectedCategories = [];

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
      _allowedOrgUnits = allOrgs
          .where((org) => org.id == userOrgId && org.status == 'Active')
          .toList();
    } else {
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

  List<int> _getComparisonYears(int current, List<int> available) {
    final result = <int>[current];
    final others = available.where((y) => y != current).toList()..sort();
    // Sort by proximity to selected year
    others.sort((a, b) => (a - current).abs().compareTo((b - current).abs()));
    for (int i = 0; i < others.length && result.length < 3; i++) {
      result.add(others[i]);
    }
    return result..sort();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final queryYears = List.generate(6, (i) => _selectedYear - 2 + i);
    final String yearsCsv = queryYears.join(',');

    // Watch global streams
    final allOrgs = ref.watch(orgUnitsStreamProvider).value ?? [];
    final allUsers = ref.watch(allUsersStreamProvider).value ?? [];
    final allActivities = ref.watch(activitiesStreamProvider).value ?? [];
    final allCategories = ref.watch(categoriesStreamProvider).value ?? [];
    final allGroups = ref.watch(activityGroupsStreamProvider).value ?? [];
    final allAllocations =
        ref.watch(allPlanningAllocationsStreamProvider(yearsCsv)).value ?? [];
    final allDemands = ref.watch(allPlanningDemandsStreamProvider(yearsCsv)).value ?? [];

    _initializeAllowedOrgUnits(currentUser, allOrgs);

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

    // 1. Establish filters values
    final activeOUIds = _selectedOrgUnits.isEmpty
        ? _allowedOrgUnits.map((o) => o.id).toList()
        : _selectedOrgUnits;

    final filteredEmployees = allUsers
        .where(
          (u) =>
              u.status == 'Active' &&
              u.orgUnitId != null &&
              activeOUIds.contains(u.orgUnitId!),
        )
        .toList();

    final filteredCategories = allCategories
        .where((c) => activeOUIds.any((ouId) => c.statusMap[ouId] == 'Active'))
        .toList();

    final filteredGroups = allGroups
        .where((g) => activeOUIds.any((ouId) => g.statusMap[ouId] == 'Active'))
        .toList();

    // Determine years list dynamically based on demands/allocations + default window
    final currentYearValue = DateTime.now().year;
    final defaultYears = List.generate(6, (i) => currentYearValue - 2 + i);
    final Set<int> yearsSet = {...defaultYears};
    for (final d in allDemands) {
      yearsSet.add(d.year);
    }
    for (final a in allAllocations) {
      yearsSet.add(a.year);
    }
    final sortedYears = yearsSet.toList()..sort();

    // Selected Filters values sets
    final targetEMPs = _selectedEmployees.isEmpty
        ? filteredEmployees.map((u) => u.email).toSet()
        : _selectedEmployees.toSet();

    final targetAGs = _selectedActivityGroups.isEmpty
        ? filteredGroups.map((g) => g.id).toSet()
        : _selectedActivityGroups.toSet();

    final targetCATs = _selectedCategories.isEmpty
        ? filteredCategories.map((c) => c.id).toSet()
        : _selectedCategories.toSet();

    // Cache employee capacities
    final capacitiesCache = <String, List<UserCapacityModel>>{};
    for (final email in targetEMPs) {
      capacitiesCache[email] =
          ref.watch(userCapacitiesStreamProvider(email)).value ?? [];
    }

    // Filter allocations in memory for the selected year
    final activeAllocations = allAllocations.where((alloc) {
      if (alloc.year != _selectedYear) return false;
      if (!targetEMPs.contains(alloc.userEmail.trim().toLowerCase())) {
        return false;
      }
      if (!activeOUIds.contains(alloc.orgUnitId)) return false;

      final actMatches = allActivities.where((a) => a.id == alloc.activityId);
      if (actMatches.isEmpty) return false;
      final act = actMatches.first;

      if (!targetAGs.contains(act.activityGroupId)) return false;
      if (act.categoryId != null && !targetCATs.contains(act.categoryId)) {
        return false;
      }

      final isActActive = act.statusMap[alloc.orgUnitId] == 'Active';
      if (!isActActive) return false;

      final isWithinValidity =
          act.type != 'Limited' ||
          ((act.validityStart == null ||
                  act.validityStart!.year <= _selectedYear) &&
              (act.validityEnd == null ||
                  act.validityEnd!.year >= _selectedYear));
      if (!isWithinValidity) return false;

      return true;
    }).toList();

    // Monthly Available Capacity Sum
    final monthlyAvailable = List.generate(12, (mIdx) {
      double sum = 0.0;
      for (final email in targetEMPs) {
        final caps = capacitiesCache[email] ?? [];
        sum += CapacityCalculator.calculateMonthlyCapacity(
          caps,
          _selectedYear,
          mIdx + 1,
        );
      }
      return sum;
    });

    // Monthly Planned Capacity Sum
    final monthlyPlanned = List.generate(12, (mIdx) {
      double sum = 0.0;
      for (final alloc in activeAllocations) {
        sum += _getAllocationMonthValue(alloc, mIdx + 1);
      }
      return sum;
    });

    // KPI Totals
    final double totalAvailable = monthlyAvailable.fold(
      0.0,
      (sum, val) => sum + val,
    );
    final double totalPlanned = monthlyPlanned.fold(
      0.0,
      (sum, val) => sum + val,
    );
    final double utilizationRate = totalAvailable == 0.0
        ? 0.0
        : (totalPlanned / totalAvailable) * 100.0;
    final double totalDelta = totalAvailable - totalPlanned;

    // Category Allocation Chart values
    final categoryHours = <String, double>{};
    for (final alloc in activeAllocations) {
      final actMatches = allActivities.where((a) => a.id == alloc.activityId);
      if (actMatches.isNotEmpty) {
        final act = actMatches.first;
        if (act.categoryId != null) {
          final catMatches = allCategories.where((c) => c.id == act.categoryId);
          final catName = catMatches.isNotEmpty
              ? catMatches.first.name
              : 'Uncategorized';
          categoryHours[catName] = (categoryHours[catName] ?? 0.0) + alloc.sum;
        } else {
          categoryHours['Uncategorized'] =
              (categoryHours['Uncategorized'] ?? 0.0) + alloc.sum;
        }
      }
    }

    // Comparison Chart values: Activity Groups across multiple Years
    final comparisonYears = _getComparisonYears(_selectedYear, sortedYears);
    final groupYearlyHours = <String, Map<int, double>>{};

    // Initialize all visible activity groups with 0 for comparison years
    for (final g in filteredGroups) {
      if (targetAGs.contains(g.id)) {
        groupYearlyHours[g.name] = {for (final y in comparisonYears) y: 0.0};
      }
    }

    for (final alloc in allAllocations) {
      if (comparisonYears.contains(alloc.year) &&
          targetEMPs.contains(alloc.userEmail.trim().toLowerCase()) &&
          activeOUIds.contains(alloc.orgUnitId)) {
        final actMatches = allActivities.where((a) => a.id == alloc.activityId);
        if (actMatches.isNotEmpty) {
          final act = actMatches.first;
          final groupMatches = filteredGroups.where(
            (g) => g.id == act.activityGroupId,
          );
          final groupName = groupMatches.isNotEmpty
              ? groupMatches.first.name
              : 'Unknown Group';
          if (groupYearlyHours.containsKey(groupName)) {
            groupYearlyHours[groupName]![alloc.year] =
                (groupYearlyHours[groupName]![alloc.year] ?? 0.0) + alloc.sum;
          }
        }
      }
    }

    // Responsive sizing layouts
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title & Segmented Navigation Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dashboard',
                  key: const Key('dashboard_title_header'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                M3SegmentedButton<String>(
                  segmentedButtonKey: const Key('dashboard_view_segmented_button'),
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
                  selected: const {'dashboard'},
                  onSelectionChanged: (val) {
                    if (val.first == 'reports') {
                      context.go(RouterPaths.reports);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Filters Section
            _buildFiltersRow(
              theme: theme,
              selectedYear: _selectedYear,
              selectedOrgUnits: _selectedOrgUnits,
              selectedEmployees: _selectedEmployees,
              selectedActivityGroups: _selectedActivityGroups,
              selectedCategories: _selectedCategories,
              allUsers: allUsers,
              allActivities: allActivities,
              allCategories: allCategories,
              allGroups: allGroups,
              availableYears: sortedYears,
              onYearChanged: (y) => setState(() => _selectedYear = y),
              onOrgUnitsChanged: (val) => setState(() {
                _selectedOrgUnits = val;
                _selectedEmployees.clear();
                _selectedActivityGroups.clear();
                _selectedCategories.clear();
              }),
              onEmployeesChanged: (val) =>
                  setState(() => _selectedEmployees = val),
              onActivityGroupsChanged: (val) =>
                  setState(() => _selectedActivityGroups = val),
              onCategoriesChanged: (val) =>
                  setState(() => _selectedCategories = val),
            ),
            const SizedBox(height: 24),

            // KPI Cards Row
            _buildKpisRow(
              theme: theme,
              isWide: isWide,
              totalAvailable: totalAvailable,
              totalPlanned: totalPlanned,
              utilizationRate: utilizationRate,
              totalDelta: totalDelta,
            ),
            const SizedBox(height: 24),

            // Grid containing Custom Charts
            if (isWide) ...[
              _buildChartCard(
                title: 'Planned vs. Available Capacity Monthly Trend',
                height: 350,
                child: LineTrendChart(
                  availableHours: monthlyAvailable,
                  plannedHours: monthlyPlanned,
                  theme: theme,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildChartCard(
                      title: 'Planned Capacity by Activity Group & Year',
                      height: 350,
                      child: BarComparisonChart(
                        yearlyHours: groupYearlyHours,
                        years: comparisonYears,
                        theme: theme,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: _buildChartCard(
                      title: 'Allocation by Category',
                      height: 350,
                      child: DonutAllocationChart(
                        categoryHours: categoryHours,
                        theme: theme,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              _buildChartCard(
                title: 'Planned vs. Available Capacity Monthly Trend',
                height: 300,
                child: LineTrendChart(
                  availableHours: monthlyAvailable,
                  plannedHours: monthlyPlanned,
                  theme: theme,
                ),
              ),
              const SizedBox(height: 24),
              _buildChartCard(
                title: 'Planned Capacity by Activity Group & Year',
                height: 300,
                child: BarComparisonChart(
                  yearlyHours: groupYearlyHours,
                  years: comparisonYears,
                  theme: theme,
                ),
              ),
              const SizedBox(height: 24),
              _buildChartCard(
                title: 'Allocation by Category',
                height: 300,
                child: DonutAllocationChart(
                  categoryHours: categoryHours,
                  theme: theme,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersRow({
    required ThemeData theme,
    required int selectedYear,
    required List<String> selectedOrgUnits,
    required List<String> selectedEmployees,
    required List<String> selectedActivityGroups,
    required List<String> selectedCategories,
    required List<UserModel> allUsers,
    required List<ActivityModel> allActivities,
    required List<CategoryModel> allCategories,
    required List<ActivityGroupModel> allGroups,
    required List<int> availableYears,
    required ValueChanged<int> onYearChanged,
    required ValueChanged<List<String>> onOrgUnitsChanged,
    required ValueChanged<List<String>> onEmployeesChanged,
    required ValueChanged<List<String>> onActivityGroupsChanged,
    required ValueChanged<List<String>> onCategoriesChanged,
  }) {
    final activeOUIds = selectedOrgUnits.isEmpty
        ? _allowedOrgUnits.map((o) => o.id).toList()
        : selectedOrgUnits;

    final filteredEmployees = allUsers
        .where(
          (u) =>
              u.status == 'Active' &&
              u.orgUnitId != null &&
              activeOUIds.contains(u.orgUnitId!),
        )
        .toList();

    final filteredCategories = allCategories
        .where((c) => activeOUIds.any((ouId) => c.statusMap[ouId] == 'Active'))
        .toList();

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
                key: const Key('filter_dash_year_dropdown'),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedYear.toString(),
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
            menuChildren: availableYears.map((y) {
              return MenuItemButton(
                key: Key('filter_dash_year_item_$y'),
                onPressed: () => onYearChanged(y),
                child: Text(y.toString()),
              );
            }).toList(),
          ),
        ),

        // Organization Unit Filter
        _buildMultiSelectFilterChip(
          label: 'Organization Unit',
          keyPrefix: 'dash_org_unit',
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
          keyPrefix: 'dash_employee',
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
          keyPrefix: 'dash_activity_group',
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
          keyPrefix: 'dash_category',
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
                Text(
                  displayLabel,
                  style: TextStyle(
                    color: !isAllSelected ? Colors.white : null,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: !isAllSelected ? Colors.white : null,
                ),
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

  Widget _buildKpisRow({
    required ThemeData theme,
    required bool isWide,
    required double totalAvailable,
    required double totalPlanned,
    required double utilizationRate,
    required double totalDelta,
  }) {
    final kpis = [
      _KpiData(
        title: 'Available Capacity',
        value:
            '${totalAvailable.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} hrs',
        color: theme.colorScheme.primary,
        icon: Icons.calendar_today,
      ),
      _KpiData(
        title: 'Planned Capacity',
        value:
            '${totalPlanned.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} hrs',
        color: theme.colorScheme.primary,
        icon: Icons.assignment,
      ),
      _KpiData(
        title: 'Utilization Rate',
        value: '${utilizationRate.toStringAsFixed(1)}%',
        color: theme.colorScheme.primary,
        icon: Icons.trending_up,
      ),
      _KpiData(
        title: 'Capacity Delta',
        value:
            '${totalDelta.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} hrs',
        color: totalDelta < 0
            ? theme.colorScheme.error
            : const Color(0xFF2E7D32),
        icon: Icons.difference,
      ),
    ];

    if (isWide) {
      return Row(
        children: List.generate(kpis.length, (index) {
          final kpi = kpis[index];
          final isLast = index == kpis.length - 1;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0.0 : 12.0),
              child: _buildKpiCard(theme, kpi),
            ),
          );
        }),
      );
    } else {
      return Column(
        children: kpis
            .map(
              (kpi) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildKpiCard(theme, kpi),
              ),
            )
            .toList(),
      );
    }
  }

  Widget _buildKpiCard(ThemeData theme, _KpiData kpi) {
    return Container(
      height: 90,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            kpi.title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            kpi.value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: kpi.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required double height,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(height: height - 64, child: child),
        ],
      ),
    );
  }
}

class _KpiData {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  const _KpiData({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });
}

// =========================================================================
// CUSTOM LINE TREND CHART
// =========================================================================
class LineTrendChart extends StatelessWidget {
  final List<double> availableHours;
  final List<double> plannedHours;
  final ThemeData theme;

  const LineTrendChart({
    super.key,
    required this.availableHours,
    required this.plannedHours,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Available Capacity', theme.colorScheme.tertiary),
            const SizedBox(width: 24),
            _buildLegendItem('Planned Capacity', theme.colorScheme.primary),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _LineChartPainter(
              availableHours: availableHours,
              plannedHours: plannedHours,
              theme: theme,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> availableHours;
  final List<double> plannedHours;
  final ThemeData theme;

  _LineChartPainter({
    required this.availableHours,
    required this.plannedHours,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double maxVal = math.max(
      availableHours.fold(0.0, math.max),
      plannedHours.fold(0.0, math.max),
    );
    final double maxAxisVal = maxVal == 0.0 ? 100.0 : (maxVal * 1.15);

    final double paddingLeft = 50.0;
    final double paddingBottom = 30.0;
    final double paddingTop = 10.0;
    final double paddingRight = 10.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    final Paint gridPaint = Paint()
      ..color = theme.colorScheme.outlineVariant.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;

    // Draw grid lines & Y-axis labels
    final int yGridCount = 4;
    for (int i = 0; i <= yGridCount; i++) {
      final double ratio = i / yGridCount;
      final double y = paddingTop + chartHeight * (1 - ratio);
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(size.width - paddingRight, y),
        gridPaint,
      );

      final double labelVal = maxAxisVal * ratio;
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: labelVal.toStringAsFixed(0),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(paddingLeft - tp.width - 8, y - tp.height / 2));
    }

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final double xStep = chartWidth / 11;

    // Draw X-axis labels
    for (int i = 0; i < 12; i++) {
      final double x = paddingLeft + i * xStep;
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: months[i],
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(x - tp.width / 2, size.height - paddingBottom + 8),
      );
    }

    // Draw Available Capacity Line
    _drawLine(
      canvas,
      availableHours,
      theme.colorScheme.tertiary,
      xStep,
      paddingLeft,
      paddingTop,
      chartHeight,
      maxAxisVal,
    );

    // Draw Planned Capacity Line
    _drawLine(
      canvas,
      plannedHours,
      theme.colorScheme.primary,
      xStep,
      paddingLeft,
      paddingTop,
      chartHeight,
      maxAxisVal,
    );
  }

  void _drawLine(
    Canvas canvas,
    List<double> values,
    Color color,
    double xStep,
    double paddingLeft,
    double paddingTop,
    double chartHeight,
    double maxAxisVal,
  ) {
    final Path path = Path();
    final Paint linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Paint dotOuterPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 12; i++) {
      final double x = paddingLeft + i * xStep;
      final double valRatio = values[i] / maxAxisVal;
      final double y = paddingTop + chartHeight * (1 - valRatio);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);

    // Draw dots
    for (int i = 0; i < 12; i++) {
      final double x = paddingLeft + i * xStep;
      final double valRatio = values[i] / maxAxisVal;
      final double y = paddingTop + chartHeight * (1 - valRatio);

      canvas.drawCircle(Offset(x, y), 5, dotOuterPaint);
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =========================================================================
// CUSTOM DONUT ALLOCATION CHART
// =========================================================================
class DonutAllocationChart extends StatelessWidget {
  final Map<String, double> categoryHours;
  final ThemeData theme;

  const DonutAllocationChart({
    super.key,
    required this.categoryHours,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out zero entries
    final nonZeroEntries = categoryHours.entries
        .where((e) => e.value > 0.0)
        .toList();
    final double total = nonZeroEntries.fold(0.0, (sum, e) => sum + e.value);

    final chartColors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.error,
      const Color(0xFF34825E), // Success green
      const Color(0xFF725C00), // Warning Amber
      const Color(0xFF8C5B27), // Orange/Brown
    ];

    if (total == 0) {
      return const Center(child: Text('No planned capacity allocations.'));
    }

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _DonutChartPainter(
              entries: nonZeroEntries,
              total: total,
              colors: chartColors,
              theme: theme,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Simple scrollable legend
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: nonZeroEntries.length,
            itemBuilder: (context, index) {
              final e = nonZeroEntries[index];
              final double percentage = (e.value / total) * 100;
              final Color color = chartColors[index % chartColors.length];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${e.key} (${percentage.toStringAsFixed(1)}%)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> entries;
  final double total;
  final List<Color> colors;
  final ThemeData theme;

  _DonutChartPainter({
    required this.entries,
    required this.total,
    required this.colors,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = math.min(size.width, size.height) / 2 - 10;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2;

    for (int i = 0; i < entries.length; i++) {
      final double sweepAngle = (entries[i].value / total) * 2 * math.pi;
      final Color color = colors[i % colors.length];

      final Paint slicePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.45;

      canvas.drawArc(rect, startAngle, sweepAngle, false, slicePaint);
      startAngle += sweepAngle;
    }

    // Inner Text showing Total Planned
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: 'Total\n${total.toStringAsFixed(0)}h',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          height: 1.2,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =========================================================================
// CUSTOM GROUPED BAR CHART
// =========================================================================
class BarComparisonChart extends StatelessWidget {
  final Map<String, Map<int, double>> yearlyHours;
  final List<int> years;
  final ThemeData theme;

  const BarComparisonChart({
    super.key,
    required this.yearlyHours,
    required this.years,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out groups with 0 hours across all years
    final nonZeroGroups = yearlyHours.entries.where((e) {
      return e.value.values.any((hours) => hours > 0.0);
    }).toList();

    final yearColors = [
      theme.colorScheme.primaryContainer,
      theme.colorScheme.primary,
      theme.colorScheme.tertiary,
    ];

    if (nonZeroGroups.isEmpty) {
      return const Center(
        child: Text('No allocations recorded for visible activity groups.'),
      );
    }

    return Column(
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(years.length, (idx) {
            final y = years[idx];
            final color = yearColors[idx % yearColors.length];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  Container(width: 12, height: 12, color: color),
                  const SizedBox(width: 6),
                  Text(
                    y.toString(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _GroupedBarChartPainter(
              groups: nonZeroGroups,
              years: years,
              colors: yearColors,
              theme: theme,
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupedBarChartPainter extends CustomPainter {
  final List<MapEntry<String, Map<int, double>>> groups;
  final List<int> years;
  final List<Color> colors;
  final ThemeData theme;

  _GroupedBarChartPainter({
    required this.groups,
    required this.years,
    required this.colors,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Determine max value
    double maxVal = 0.0;
    for (final g in groups) {
      for (final val in g.value.values) {
        if (val > maxVal) maxVal = val;
      }
    }
    final double maxAxisVal = maxVal == 0.0 ? 100.0 : (maxVal * 1.15);

    final double paddingLeft = 50.0;
    final double paddingBottom = 40.0;
    final double paddingTop = 10.0;
    final double paddingRight = 10.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    final Paint gridPaint = Paint()
      ..color = theme.colorScheme.outlineVariant.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;

    // Draw grid lines & Y-axis labels
    final int yGridCount = 4;
    for (int i = 0; i <= yGridCount; i++) {
      final double ratio = i / yGridCount;
      final double y = paddingTop + chartHeight * (1 - ratio);
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(size.width - paddingRight, y),
        gridPaint,
      );

      final double labelVal = maxAxisVal * ratio;
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: labelVal.toStringAsFixed(0),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(paddingLeft - tp.width - 8, y - tp.height / 2));
    }

    final double groupWidth = chartWidth / groups.length;
    final double groupPaddingRatio = 0.2; // 20% padding around group
    final double innerPadding = 2.0;

    final double usableGroupWidth = groupWidth * (1 - groupPaddingRatio);
    final double barWidth =
        (usableGroupWidth - (years.length - 1) * innerPadding) / years.length;

    // Draw Groups and Bars
    for (int i = 0; i < groups.length; i++) {
      final group = groups[i];
      final double groupStartX =
          paddingLeft + i * groupWidth + (groupWidth * groupPaddingRatio / 2);

      // Draw Group Labels
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: group.key,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      // Wrap or clip text if too wide
      final double labelX = groupStartX + (usableGroupWidth - tp.width) / 2;
      tp.paint(canvas, Offset(labelX, size.height - paddingBottom + 6));

      // Draw bars for each year side-by-side
      for (int yIdx = 0; yIdx < years.length; yIdx++) {
        final year = years[yIdx];
        final double val = group.value[year] ?? 0.0;
        final double valRatio = val / maxAxisVal;
        final double barHeight = chartHeight * valRatio;

        final double barX = groupStartX + yIdx * (barWidth + innerPadding);
        final double barY = paddingTop + chartHeight - barHeight;

        final Paint barPaint = Paint()
          ..color = colors[yIdx % colors.length]
          ..style = PaintingStyle.fill;

        if (barHeight > 0) {
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              Rect.fromLTWH(barX, barY, barWidth, barHeight),
              topLeft: const Radius.circular(2),
              topRight: const Radius.circular(2),
            ),
            barPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
