import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../models/user_model.dart';
import '../../../core/utils/capacity_calculator.dart';
import '../../../core/utils/csv_export_helper.dart';
import '../../../core/theme/theme_extensions.dart';
import 'cell_selection.dart';
import 'hover_cell.dart';
import 'assign_dialog.dart';

class EmployeeColMapping {
  final UserModel employee;
  final int month; // 1 to 12, or 13 for Sum
  final bool isSum;
  EmployeeColMapping({
    required this.employee,
    required this.month,
    required this.isSum,
  });
}

enum EmployeeRowType {
  names,
  header,
  availableCapacity,
  groupHeader,
  activity,
  plannedCapacity,
  delta,
}

class EmployeeRowMapping {
  final EmployeeRowType type;
  final ActivityGroupModel? group;
  final ActivityModel? activity;
  EmployeeRowMapping({required this.type, this.group, this.activity});
}

class EmployeePlanningTable extends ConsumerStatefulWidget {
  final ThemeData theme;
  final List<UserModel> selectedEmployees;
  final List<ActivityModel> activities;
  final List<ActivityGroupModel> groups;
  final List<CategoryModel> categories;
  final List<PlanningAllocationModel> allocations;
  final Map<String, List<UserCapacityModel>> capacities;
  final String orgUnitId;
  final bool isEditing;
  final Map<String, Map<int, double>> localAllocationEdits;
  final int selectedYear;
  final Map<String, bool> employeeExpanded;
  final Map<String, TextEditingController> controllersCache;
  final String? activeTableId;
  final ValueChanged<String?> onTableTap;
  final Map<String, FocusNode> focusNodesCache;
  final void Function(String, bool) onExpandedChanged;
  final List<LockModel> activeLocks;
  final String currentUserId;
  final bool showNamesRow;

  const EmployeePlanningTable({
    super.key,
    required this.theme,
    required this.selectedEmployees,
    required this.activities,
    required this.groups,
    required this.categories,
    required this.allocations,
    required this.capacities,
    required this.orgUnitId,
    required this.isEditing,
    required this.localAllocationEdits,
    required this.selectedYear,
    required this.employeeExpanded,
    required this.controllersCache,
    required this.activeTableId,
    required this.onTableTap,
    required this.focusNodesCache,
    required this.onExpandedChanged,
    required this.activeLocks,
    required this.currentUserId,
    this.showNamesRow = true,
  });

  @override
  ConsumerState<EmployeePlanningTable> createState() =>
      EmployeePlanningTableState();
}

class EmployeePlanningTableState extends ConsumerState<EmployeePlanningTable> {
  CellRange? _selectedRange;
  CellPosition? _selectionStart;
  bool _isDraggingSelection = false;
  CellRange? _dragFillRange;
  CellPosition? _dragFillStart;
  bool _isDraggingFill = false;
  final FocusNode _tableFocusNode = FocusNode();
  CellEditMode _cellEditMode = CellEditMode.none;
  bool _ignoreSelectionThisPointer = false;

  final List<EmployeeColMapping> colMappings = [];
  final List<EmployeeRowMapping> rowMappings = [];

  final List<GlobalKey> rowKeys = [];
  final List<GlobalKey> colKeys = [];

  late final ScrollController _headerScrollController;
  late final ScrollController _middleScrollController;
  late final ScrollController _footerScrollController;
  late final ScrollController _verticalScrollController;
  bool _isSyncingScroll = false;

  bool _isResourceLocked(String empEmail, String activityId) {
    for (final lock in widget.activeLocks) {
      if (lock.userId == widget.currentUserId) continue; // Our own lock
      if (lock.isExpired) continue;
      if (lock.lockType == 'activity') {
        if (lock.activityId == activityId) {
          return true;
        }
      } else if (lock.lockType == 'employee') {
        if (lock.activityIds.contains(activityId) &&
            lock.employeeEmails.contains(empEmail)) {
          return true;
        }
      }
    }
    return false;
  }

  LockModel? _getActivityLock(String activityId) {
    for (final lock in widget.activeLocks) {
      if (lock.userId == widget.currentUserId) continue;
      if (lock.isExpired) continue;
      if (lock.lockType == 'activity' && lock.activityId == activityId) {
        return lock;
      }
      if (lock.lockType == 'employee' &&
          lock.activityIds.contains(activityId)) {
        final lockEmps = lock.employeeEmails.toSet();
        final visibleEmps = widget.selectedEmployees
            .map((e) => e.email)
            .toSet();
        if (lockEmps.intersection(visibleEmps).isNotEmpty) {
          return lock;
        }
      }
    }
    return null;
  }

  void _syncKeys() {
    if (rowMappings.isEmpty) return;
    if (rowKeys.length < rowMappings.length) {
      rowKeys.addAll(
        List.generate(rowMappings.length - rowKeys.length, (_) => GlobalKey()),
      );
    } else if (rowKeys.length > rowMappings.length) {
      rowKeys.removeRange(rowMappings.length, rowKeys.length);
    }

    final targetColCount = 1 + colMappings.length;
    if (colKeys.length < targetColCount) {
      colKeys.addAll(
        List.generate(targetColCount - colKeys.length, (_) => GlobalKey()),
      );
    } else if (colKeys.length > targetColCount) {
      colKeys.removeRange(targetColCount, colKeys.length);
    }
  }

  @override
  void initState() {
    super.initState();
    _headerScrollController = ScrollController();
    _middleScrollController = ScrollController();
    _footerScrollController = ScrollController();
    _verticalScrollController = ScrollController();

    _middleScrollController.addListener(_syncScroll);
    _headerScrollController.addListener(_syncHeaderScroll);
    _footerScrollController.addListener(_syncFooterScroll);

    _buildMappings();
    _syncKeys();
  }

  @override
  void didUpdateWidget(covariant EmployeePlanningTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTableId != 'employee') {
      _selectedRange = null;
      _dragFillRange = null;
      _cellEditMode = CellEditMode.none;
      _isDraggingSelection = false;
      _isDraggingFill = false;
    }
    if (oldWidget.isEditing != widget.isEditing) {
      _selectedRange = null;
      _dragFillRange = null;
      _cellEditMode = CellEditMode.none;
      _isDraggingSelection = false;
      _isDraggingFill = false;
    }
  }

  bool _isCharacterKey(LogicalKeyboardKey key, String? character) {
    if (character == null || character.isEmpty) return false;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      return false;
    }
    final RegExp numRegExp = RegExp(r'^[0-9\.\,\-]$');
    return numRegExp.hasMatch(character);
  }

  void _navigateSelection(LogicalKeyboardKey key) {
    if (_selectedRange == null) return;

    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final start = _selectionStart ?? _selectedRange!.start;
    final end = _selectedRange!.end;
    final current = isShiftPressed ? end : start;
    int r = current.row;
    int c = current.col;

    if (widget.isEditing) {
      int firstAct = rowMappings.indexWhere(
        (rm) => rm.type == EmployeeRowType.activity,
      );
      int lastAct = rowMappings.lastIndexWhere(
        (rm) => rm.type == EmployeeRowType.activity,
      );
      if (firstAct == -1) return;

      if (key == LogicalKeyboardKey.arrowUp) {
        int targetR = r - 1;
        while (targetR >= firstAct &&
            rowMappings[targetR].type != EmployeeRowType.activity) {
          targetR--;
        }
        if (targetR >= firstAct) r = targetR;
      } else if (key == LogicalKeyboardKey.arrowDown) {
        int targetR = r + 1;
        while (targetR <= lastAct &&
            rowMappings[targetR].type != EmployeeRowType.activity) {
          targetR++;
        }
        if (targetR <= lastAct) r = targetR;
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        int targetC = c - 1;
        while (targetC >= 1 && colMappings[targetC - 1].isSum) {
          targetC--;
        }
        if (targetC >= 1) c = targetC;
      } else if (key == LogicalKeyboardKey.arrowRight) {
        int targetC = c + 1;
        while (targetC <= colMappings.length &&
            colMappings[targetC - 1].isSum) {
          targetC++;
        }
        if (targetC <= colMappings.length) c = targetC;
      }

      r = r.clamp(firstAct, lastAct);
      c = c.clamp(1, colMappings.length);
    } else {
      if (key == LogicalKeyboardKey.arrowUp) {
        r = r - 1;
      } else if (key == LogicalKeyboardKey.arrowDown) {
        r = r + 1;
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        c = c - 1;
      } else if (key == LogicalKeyboardKey.arrowRight) {
        c = c + 1;
      }

      r = r.clamp(0, rowMappings.length - 1);
      c = c.clamp(0, colMappings.length);
    }

    setState(() {
      if (isShiftPressed) {
        _selectedRange = CellRange(_selectionStart!, CellPosition(r, c));
      } else {
        _selectionStart = CellPosition(r, c);
        _selectedRange = CellRange(_selectionStart!, _selectionStart!);
      }
      _cellEditMode = CellEditMode.selected;
    });

    _tableFocusNode.requestFocus();
  }

  void _startTypingFromType(int r, int c, String character) {
    setState(() {
      _cellEditMode = CellEditMode.typingFromType;
      _selectionStart = CellPosition(r, c);
      _selectedRange = CellRange(_selectionStart!, _selectionStart!);

      final rowKey = _getRowKeyForPosition(r, c);
      if (rowKey != null) {
        final colMapping = colMappings[c - 1];
        final monthIdx = colMapping.month - 1;
        final focusKey = '${rowKey}_$monthIdx';
        final ctrl = _getOrCreateController(focusKey, character);
        ctrl.text = character;

        final node = widget.focusNodesCache[focusKey];
        if (node != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (node.canRequestFocus) {
              node.requestFocus();
            }
          });
          Future.delayed(Duration.zero, () {
            ctrl.selection = TextSelection.fromPosition(
              TextPosition(offset: character.length),
            );
          });
        }
      }
    });
  }

  void _startTypingFromDouble(int r, int c) {
    setState(() {
      _cellEditMode = CellEditMode.typingFromDouble;
      _selectionStart = CellPosition(r, c);
      _selectedRange = CellRange(_selectionStart!, _selectionStart!);

      final rowKey = _getRowKeyForPosition(r, c);
      if (rowKey != null) {
        final colMapping = colMappings[c - 1];
        final monthIdx = colMapping.month - 1;
        final focusKey = '${rowKey}_$monthIdx';
        final node = widget.focusNodesCache[focusKey];
        if (node != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (node.canRequestFocus) {
              node.requestFocus();
            }
          });
          Future.delayed(Duration.zero, () {
            final ctrl = widget.controllersCache[focusKey];
            if (ctrl != null) {
              ctrl.selection = TextSelection(
                baseOffset: 0,
                extentOffset: ctrl.text.length,
              );
            }
          });
        }
      }
    });
  }

  String? _getRowKeyForPosition(int r, int c) {
    if (r < 0 || r >= rowMappings.length) return null;
    final rowMapping = rowMappings[r];
    if (rowMapping.type == EmployeeRowType.activity) {
      if (c <= 0 || c > colMappings.length) return null;
      final colMapping = colMappings[c - 1];
      final emp = colMapping.employee;
      final act = rowMapping.activity!;
      return '${emp.email}_${act.id}';
    }
    return null;
  }

  @override
  void dispose() {
    _headerScrollController.removeListener(_syncHeaderScroll);
    _middleScrollController.removeListener(_syncScroll);
    _footerScrollController.removeListener(_syncFooterScroll);
    _headerScrollController.dispose();
    _middleScrollController.dispose();
    _footerScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _syncScroll() {
    if (_isSyncingScroll) return;
    _isSyncingScroll = true;
    final offset = _middleScrollController.offset;
    if (_headerScrollController.hasClients &&
        _headerScrollController.offset != offset) {
      _headerScrollController.jumpTo(offset);
    }
    if (_footerScrollController.hasClients &&
        _footerScrollController.offset != offset) {
      _footerScrollController.jumpTo(offset);
    }
    _isSyncingScroll = false;
  }

  void _syncHeaderScroll() {
    if (_isSyncingScroll) return;
    _isSyncingScroll = true;
    final offset = _headerScrollController.offset;
    if (_middleScrollController.hasClients &&
        _middleScrollController.offset != offset) {
      _middleScrollController.jumpTo(offset);
    }
    if (_footerScrollController.hasClients &&
        _footerScrollController.offset != offset) {
      _footerScrollController.jumpTo(offset);
    }
    _isSyncingScroll = false;
  }

  void _syncFooterScroll() {
    if (_isSyncingScroll) return;
    _isSyncingScroll = true;
    final offset = _footerScrollController.offset;
    if (_middleScrollController.hasClients &&
        _middleScrollController.offset != offset) {
      _middleScrollController.jumpTo(offset);
    }
    if (_headerScrollController.hasClients &&
        _headerScrollController.offset != offset) {
      _headerScrollController.jumpTo(offset);
    }
    _isSyncingScroll = false;
  }

  void _buildMappings() {
    final bool multiEmp = widget.selectedEmployees.length > 1;

    // Build Col Mappings
    colMappings.clear();
    for (final emp in widget.selectedEmployees) {
      final isExpanded =
          !multiEmp || (widget.employeeExpanded[emp.email] ?? false);
      if (isExpanded) {
        for (int m = 1; m <= 12; m++) {
          colMappings.add(
            EmployeeColMapping(employee: emp, month: m, isSum: false),
          );
        }
      }
      colMappings.add(
        EmployeeColMapping(employee: emp, month: 13, isSum: true),
      );
    }

    // Build Row Mappings
    rowMappings.clear();
    rowMappings.add(EmployeeRowMapping(type: EmployeeRowType.names));
    rowMappings.add(EmployeeRowMapping(type: EmployeeRowType.header));
    rowMappings.add(
      EmployeeRowMapping(type: EmployeeRowType.availableCapacity),
    );

    for (final group in widget.groups) {
      final groupActivities = widget.activities
          .where((act) => act.activityGroupId == group.id)
          .toList();
      if (groupActivities.isEmpty) continue;
      rowMappings.add(
        EmployeeRowMapping(type: EmployeeRowType.groupHeader, group: group),
      );
      for (final act in groupActivities) {
        rowMappings.add(
          EmployeeRowMapping(type: EmployeeRowType.activity, activity: act),
        );
      }
    }

    rowMappings.add(EmployeeRowMapping(type: EmployeeRowType.plannedCapacity));
    rowMappings.add(EmployeeRowMapping(type: EmployeeRowType.delta));
    _syncKeys();
  }

  EmployeeColMapping? _getColMapping(int c) {
    if (c <= 0 || c > colMappings.length) return null;
    return colMappings[c - 1];
  }

  TextEditingController _getOrCreateController(
    String key,
    String initialText, {
    bool isEditing = false,
  }) {
    if (!widget.controllersCache.containsKey(key)) {
      widget.controllersCache[key] = TextEditingController(text: initialText);
    } else {
      final ctrl = widget.controllersCache[key]!;
      if (!isEditing) {
        if (ctrl.text != initialText) {
          ctrl.text = initialText;
        }
      }
    }
    return widget.controllersCache[key]!;
  }

  double _getAllocationValue(
    UserModel emp,
    ActivityModel act,
    int month, [
    Map<String, PlanningAllocationModel>? allocMap,
  ]) {
    final allocKey = '${emp.email}_${act.id}';
    if (widget.isEditing) {
      return widget.localAllocationEdits[allocKey]?[month] ?? 0.0;
    }
    PlanningAllocationModel alloc;
    if (allocMap != null) {
      alloc =
          allocMap['${emp.email.trim().toLowerCase()}_${act.id}'] ??
          PlanningAllocationModel(
            id: '',
            userEmail: emp.email,
            activityId: act.id,
            year: widget.selectedYear,
            orgUnitId: widget.orgUnitId,
          );
    } else {
      alloc = widget.allocations.firstWhere(
        (a) =>
            a.activityId == act.id &&
            a.userEmail.trim().toLowerCase() == emp.email.trim().toLowerCase(),
        orElse: () => PlanningAllocationModel(
          id: '',
          userEmail: emp.email,
          activityId: act.id,
          year: widget.selectedYear,
          orgUnitId: widget.orgUnitId,
        ),
      );
    }
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

  double _getCellValue(
    int r,
    EmployeeColMapping colMapping, [
    Map<String, PlanningAllocationModel>? allocMap,
  ]) {
    final rowMapping = rowMappings[r];
    final emp = colMapping.employee;
    final month = colMapping.month;

    switch (rowMapping.type) {
      case EmployeeRowType.names:
      case EmployeeRowType.header:
        return 0.0;
      case EmployeeRowType.availableCapacity:
        if (colMapping.isSum) {
          double sum = 0.0;
          for (int m = 1; m <= 12; m++) {
            sum += CapacityCalculator.calculateMonthlyCapacity(
              widget.capacities[emp.email] ?? [],
              widget.selectedYear,
              m,
            );
          }
          return sum;
        }
        return CapacityCalculator.calculateMonthlyCapacity(
          widget.capacities[emp.email] ?? [],
          widget.selectedYear,
          month,
        );
      case EmployeeRowType.groupHeader:
        final groupActivities = widget.activities
            .where((act) => act.activityGroupId == rowMapping.group?.id)
            .toList();
        if (colMapping.isSum) {
          double sum = 0.0;
          for (final act in groupActivities) {
            for (int m = 1; m <= 12; m++) {
              sum += _getAllocationValue(emp, act, m, allocMap);
            }
          }
          return sum;
        }
        double sum = 0.0;
        for (final act in groupActivities) {
          sum += _getAllocationValue(emp, act, month, allocMap);
        }
        return sum;
      case EmployeeRowType.activity:
        final act = rowMapping.activity!;
        if (colMapping.isSum) {
          double sum = 0.0;
          for (int m = 1; m <= 12; m++) {
            sum += _getAllocationValue(emp, act, m, allocMap);
          }
          return sum;
        }
        return _getAllocationValue(emp, act, month, allocMap);
      case EmployeeRowType.plannedCapacity:
        if (colMapping.isSum) {
          double sum = 0.0;
          for (final act in widget.activities) {
            for (int m = 1; m <= 12; m++) {
              sum += _getAllocationValue(emp, act, m, allocMap);
            }
          }
          return sum;
        }
        double sum = 0.0;
        for (final act in widget.activities) {
          sum += _getAllocationValue(emp, act, month, allocMap);
        }
        return sum;
      case EmployeeRowType.delta:
        final avail = _getCellValue(
          2,
          colMapping,
          allocMap,
        ); // row 2 is Available Capacity
        final plannedRowIndex = rowMappings.indexWhere(
          (rm) => rm.type == EmployeeRowType.plannedCapacity,
        );
        final planned = plannedRowIndex != -1
            ? _getCellValue(plannedRowIndex, colMapping, allocMap)
            : 0.0;
        return avail - planned;
    }
  }

  CellPosition? _getCellAtGlobalPosition(Offset globalPos) {
    int? targetRow;
    int? targetCol;

    int closestRow = 0;
    double minRowDistance = double.infinity;
    for (int r = 0; r < rowKeys.length; r++) {
      final key = rowKeys[r];
      final RenderBox? box =
          key.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final position = box.localToGlobal(Offset.zero);
        final top = position.dy;
        final bottom = position.dy + box.size.height;
        if (globalPos.dy >= top && globalPos.dy <= bottom) {
          targetRow = r;
          break;
        }
        final distance = (globalPos.dy - (top + bottom) / 2).abs();
        if (distance < minRowDistance) {
          minRowDistance = distance;
          closestRow = r;
        }
      }
    }
    if (targetRow == null && minRowDistance != double.infinity) {
      targetRow = closestRow;
    }

    final row0Box = rowKeys[1].currentContext?.findRenderObject() as RenderBox?;
    if (row0Box != null) {
      final position = row0Box.localToGlobal(Offset.zero);
      final left = position.dx;
      final right = position.dx + 300.0;
      if (globalPos.dx >= left && globalPos.dx <= right) {
        targetCol = 0;
      }
    }

    if (targetCol == null) {
      int closestCol = 1;
      double minColDistance = double.infinity;
      for (int c = 1; c < colKeys.length; c++) {
        final key = colKeys[c];
        final RenderBox? box =
            key.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          final position = box.localToGlobal(Offset.zero);
          final left = position.dx;
          final right = position.dx + box.size.width;
          if (globalPos.dx >= left && globalPos.dx <= right) {
            targetCol = c;
            break;
          }
          final distance = (globalPos.dx - (left + right) / 2).abs();
          if (distance < minColDistance) {
            minColDistance = distance;
            closestCol = c;
          }
        }
      }
      if (targetCol == null &&
          minColDistance != double.infinity &&
          row0Box != null) {
        final position = row0Box.localToGlobal(Offset.zero);
        final left0 = position.dx;
        final right0 = position.dx + 300.0;
        final distToCol0 = (globalPos.dx - (left0 + right0) / 2).abs();
        if (distToCol0 < minColDistance) {
          targetCol = 0;
        } else {
          targetCol = closestCol;
        }
      }
    }

    if (targetRow != null && targetCol != null) {
      return CellPosition(targetRow, targetCol);
    }
    return null;
  }

  void _copyEmployeeSelectedCells() async {
    if (_selectedRange == null) return;
    final buffer = StringBuffer();
    for (int r = _selectedRange!.minRow; r <= _selectedRange!.maxRow; r++) {
      final rowValues = <String>[];
      final rowMapping = rowMappings[r];

      for (int c = _selectedRange!.minCol; c <= _selectedRange!.maxCol; c++) {
        if (c == 0) {
          switch (rowMapping.type) {
            case EmployeeRowType.names:
              rowValues.add('');
              break;
            case EmployeeRowType.header:
              rowValues.add('Activities');
              break;
            case EmployeeRowType.availableCapacity:
              rowValues.add('Available Capacity');
              break;
            case EmployeeRowType.groupHeader:
              rowValues.add(rowMapping.group?.name ?? '');
              break;
            case EmployeeRowType.activity:
              rowValues.add(rowMapping.activity?.name ?? '');
              break;
            case EmployeeRowType.plannedCapacity:
              rowValues.add('Planned Capacity');
              break;
            case EmployeeRowType.delta:
              rowValues.add('Delta');
              break;
          }
        } else {
          final colMapping = _getColMapping(c);
          if (colMapping == null) continue;
          if (rowMapping.type == EmployeeRowType.names) {
            rowValues.add(colMapping.employee.fullName);
          } else if (rowMapping.type == EmployeeRowType.header) {
            rowValues.add(
              colMapping.isSum
                  ? 'Sum'
                  : months[colMapping.month - 1].substring(0, 3),
            );
          } else {
            double val = _getCellValue(r, colMapping);
            rowValues.add(
              val == 0
                  ? '0'
                  : val.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
            );
          }
        }
      }
      buffer.writeln(rowValues.join('\t'));
    }

    if (buffer.isNotEmpty) {
      final text = buffer.toString().substring(0, buffer.length - 1);
      Clipboard.setData(ClipboardData(text: text)).catchError((_) {});
    }
  }

  void exportToCsv() {
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

    for (int r = 0; r < rowMappings.length; r++) {
      final rowValues = <String>[];
      final rowMapping = rowMappings[r];

      switch (rowMapping.type) {
        case EmployeeRowType.names:
          rowValues.add('Employees');
          break;
        case EmployeeRowType.header:
          rowValues.add('Activities');
          break;
        case EmployeeRowType.availableCapacity:
          rowValues.add('Available Capacity');
          break;
        case EmployeeRowType.groupHeader:
          rowValues.add(rowMapping.group?.name ?? '');
          break;
        case EmployeeRowType.activity:
          rowValues.add(rowMapping.activity?.name ?? '');
          break;
        case EmployeeRowType.plannedCapacity:
          rowValues.add('Planned Capacity');
          break;
        case EmployeeRowType.delta:
          rowValues.add('Delta');
          break;
      }

      for (int c = 1; c <= colMappings.length; c++) {
        final colMapping = colMappings[c - 1];
        if (rowMapping.type == EmployeeRowType.names) {
          rowValues.add(colMapping.employee.fullName);
        } else if (rowMapping.type == EmployeeRowType.header) {
          if (colMapping.isSum) {
            rowValues.add('Sum');
          } else {
            rowValues.add(months[colMapping.month - 1]);
          }
        } else {
          final val = _getCellValue(r, colMapping);
          rowValues.add(
            val == 0
                ? '0'
                : val.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
          );
        }
      }

      buffer.writeln(rowValues.map(csvEscape).join(','));
    }

    final fileName = 'employee_planning_${widget.selectedYear}.csv';
    saveCsvFile(buffer.toString(), fileName);
  }

  void _pasteEmployeeSelectedCells() async {
    if (!widget.isEditing || _selectedRange == null) return;

    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text;
    if (text == null || text.isEmpty) return;

    final rows = text
        .split('\n')
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toList();
    if (rows.isEmpty) return;

    final parsedGrid = rows.map((r) => r.split('\t')).toList();
    final isSingleValue = parsedGrid.length == 1 && parsedGrid[0].length == 1;

    if (isSingleValue) {
      final valStr = parsedGrid[0][0];
      final val = double.tryParse(valStr);
      if (val != null) {
        final constrainedVal = val.clamp(0.0, 9999.0);
        bool updated = false;
        for (int r = _selectedRange!.minRow; r <= _selectedRange!.maxRow; r++) {
          final rowMapping = rowMappings[r];
          if (rowMapping.type != EmployeeRowType.activity) continue;
          final actId = rowMapping.activity!.id;

          for (
            int c = _selectedRange!.minCol;
            c <= _selectedRange!.maxCol;
            c++
          ) {
            final colMapping = _getColMapping(c);
            if (colMapping == null || colMapping.isSum) continue;

            final isAssigned = rowMapping.activity!.assignedUserEmails
                .map((e) => e.trim().toLowerCase())
                .toSet()
                .contains(colMapping.employee.email.trim().toLowerCase());
            if (!isAssigned) continue;

            final allocKey = '${colMapping.employee.email}_$actId';
            widget.localAllocationEdits.putIfAbsent(
              allocKey,
              () => {for (int m = 1; m <= 12; m++) m: 0.0},
            )[colMapping.month] = constrainedVal;

            final controllerKey = '${allocKey}_${colMapping.month - 1}';
            final controller = widget.controllersCache[controllerKey];
            if (controller != null) {
              controller.text = constrainedVal == 0
                  ? '0'
                  : constrainedVal
                        .toStringAsFixed(1)
                        .replaceAll(RegExp(r'\.0$'), '');
            }
            updated = true;
          }
        }
        if (updated) {
          setState(() {});
        }
      }
    } else {
      bool updated = false;
      for (int i = 0; i < parsedGrid.length; i++) {
        final r = _selectedRange!.minRow + i;
        if (r >= rowMappings.length) break;
        final rowMapping = rowMappings[r];
        if (rowMapping.type != EmployeeRowType.activity) continue;
        final actId = rowMapping.activity!.id;

        for (int j = 0; j < parsedGrid[i].length; j++) {
          final c = _selectedRange!.minCol + j;
          if (c == 0) continue; // Skip label col pasting
          final colMapping = _getColMapping(c);
          if (colMapping == null || colMapping.isSum) continue;

          final isAssigned = rowMapping.activity!.assignedUserEmails
              .map((e) => e.trim().toLowerCase())
              .toSet()
              .contains(colMapping.employee.email.trim().toLowerCase());
          if (!isAssigned) continue;

          final val = double.tryParse(parsedGrid[i][j]) ?? 0.0;
          final constrainedVal = val.clamp(0.0, 9999.0);

          final allocKey = '${colMapping.employee.email}_$actId';
          widget.localAllocationEdits.putIfAbsent(
            allocKey,
            () => {for (int m = 1; m <= 12; m++) m: 0.0},
          )[colMapping.month] = constrainedVal;

          final controllerKey = '${allocKey}_${colMapping.month - 1}';
          final controller = widget.controllersCache[controllerKey];
          if (controller != null) {
            controller.text = constrainedVal == 0
                ? '0'
                : constrainedVal
                      .toStringAsFixed(1)
                      .replaceAll(RegExp(r'\.0$'), '');
          }
          updated = true;
        }
      }
      if (updated) {
        setState(() {});
      }
    }
  }

  void _performEmployeeDragFill() {
    if (_dragFillRange == null || _selectedRange == null) return;
    final sourceRow = _dragFillStart!.row;
    final sourceCol = _dragFillStart!.col;
    final sourceMapping = _getColMapping(sourceCol);
    final sourceRowMapping = rowMappings[sourceRow];
    if (sourceRowMapping.type != EmployeeRowType.activity ||
        sourceMapping == null ||
        sourceMapping.isSum) {
      return;
    }

    final actId = sourceRowMapping.activity!.id;
    final allocKey = '${sourceMapping.employee.email}_$actId';
    final double fillValue =
        widget.localAllocationEdits[allocKey]?[sourceMapping.month] ?? 0.0;

    bool updated = false;
    for (int r = _dragFillRange!.minRow; r <= _dragFillRange!.maxRow; r++) {
      final targetRowMapping = rowMappings[r];
      if (targetRowMapping.type != EmployeeRowType.activity) continue;
      final targetActId = targetRowMapping.activity!.id;

      for (int c = _dragFillRange!.minCol; c <= _dragFillRange!.maxCol; c++) {
        final targetColMapping = _getColMapping(c);
        if (targetColMapping == null || targetColMapping.isSum) continue;

        final isAssigned = targetRowMapping.activity!.assignedUserEmails
            .map((e) => e.trim().toLowerCase())
            .toSet()
            .contains(targetColMapping.employee.email.trim().toLowerCase());
        if (!isAssigned) continue;

        final targetAllocKey =
            '${targetColMapping.employee.email}_$targetActId';
        widget.localAllocationEdits.putIfAbsent(
          targetAllocKey,
          () => {for (int m = 1; m <= 12; m++) m: 0.0},
        )[targetColMapping.month] = fillValue;

        final controllerKey = '${targetAllocKey}_${targetColMapping.month - 1}';
        final controller = widget.controllersCache[controllerKey];
        if (controller != null) {
          controller.text = fillValue == 0
              ? '0'
              : fillValue.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
        }
        updated = true;
      }
    }
    if (updated) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final allocMap = {
      for (final a in widget.allocations)
        '${a.userEmail.trim().toLowerCase()}_${a.activityId}': a,
    };
    final bool multiEmp = widget.selectedEmployees.length > 1;
    const double fixedColWidth = 300.0;

    // Recalculate mappings as expanded state might change
    _buildMappings();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate total default width of scrollable columns
        double totalDefaultScrollWidth = 0.0;
        for (final emp in widget.selectedEmployees) {
          final isExpanded =
              !multiEmp || (widget.employeeExpanded[emp.email] ?? false);
          totalDefaultScrollWidth +=
              (isExpanded ? (12 * 60.0 + 60.0) : 60.0) + 0.5;
        }

        final double availableScrollWidth =
            constraints.maxWidth - fixedColWidth - 1.0;
        double scale = 1.0;
        if (totalDefaultScrollWidth < availableScrollWidth) {
          scale = availableScrollWidth / totalDefaultScrollWidth;
        }

        final double monthCellWidth = 60.0 * scale;
        final double sumCellWidth = 60.0 * scale;

        final List<Widget> fixedColCells = [];
        final List<List<Widget>> scrollColRows = [];

        // 1. Names Row
        // Top spacer for the fixed column
        fixedColCells.add(
          widget.showNamesRow
              ? Container(
                  key: rowKeys[0],
                  height: 32,
                  decoration: const BoxDecoration(color: Colors.transparent),
                )
              : SizedBox.shrink(key: rowKeys[0]),
        );

        // Names row for the scrollable column
        final List<Widget> scrollNamesCells = [];
        for (final emp in widget.selectedEmployees) {
          final isExpanded =
              !multiEmp || (widget.employeeExpanded[emp.email] ?? false);
          final double width =
              (isExpanded
                  ? (12 * monthCellWidth + sumCellWidth)
                  : sumCellWidth) +
              0.5;

          scrollNamesCells.add(
            widget.showNamesRow
                ? Container(
                    width: width,
                    height: 32,
                    decoration: const BoxDecoration(color: Colors.transparent),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.centerLeft,
                    child: isExpanded
                        ? Row(
                            children: [
                              Text(
                                emp.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              if (multiEmp) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 16,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.keyboard_double_arrow_left),
                                  onPressed: () {
                                    widget.onExpandedChanged(emp.email, false);
                                  },
                                ),
                              ],
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              if (multiEmp) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 16,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.keyboard_double_arrow_left),
                                  onPressed: () {
                                    widget.onExpandedChanged(emp.email, false);
                                  },
                                ),
                              ],
                            ],
                          )
                        : Center(
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              iconSize: 16,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.keyboard_double_arrow_right),
                              onPressed: () {
                                widget.onExpandedChanged(emp.email, true);
                              },
                            ),
                          ),
                  )
                : const SizedBox.shrink(),
          );
        }
        scrollColRows.add(scrollNamesCells);

        // 2. Header Row (Months)
        final activitiesHeaderChild = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: const Text(
              'Activities',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );

        fixedColCells.add(
          _buildInteractiveCell(
            r: 1,
            c: 0,
            width: fixedColWidth,
            height: 48,
            child: activitiesHeaderChild,
            rowKey: 'header_activities',
            backgroundColor: Colors.white,
          ),
        );

        final List<Widget> scrollHeaderCells = [];
        int colIdx = 1;
        for (int i = 0; i < widget.selectedEmployees.length; i++) {
          final emp = widget.selectedEmployees[i];
          final bool isLast = i == widget.selectedEmployees.length - 1;
          final isExpanded =
              !multiEmp || (widget.employeeExpanded[emp.email] ?? false);

          final List<Widget> headerRowChildren = [];
          if (isExpanded) {
            for (int index = 0; index < 12; index++) {
              headerRowChildren.add(
                _buildInteractiveCell(
                  r: 1,
                  c: colIdx,
                  width: monthCellWidth,
                  height: 48,
                  child: Center(
                    child: Text(
                      months[index].substring(0, 3),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  rowKey: 'header_${emp.email}_$index',
                  backgroundColor: Colors.white,
                ),
              );
              colIdx++;
            }
          }
          headerRowChildren.add(
            _buildInteractiveCell(
              r: 1,
              c: colIdx,
              width: sumCellWidth,
              height: 48,
              child: const Center(
                child: Text(
                  'Sum',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              rowKey: 'header_${emp.email}_sum',
              backgroundColor: Colors.white,
            ),
          );
          colIdx++;

          scrollHeaderCells.add(
            ClipRRect(
              borderRadius: isLast
                  ? const BorderRadius.only(topRight: Radius.circular(12))
                  : BorderRadius.zero,
              child: Row(children: headerRowChildren),
            ),
          );
        }
        scrollColRows.add(scrollHeaderCells);

        // 3. Available Capacity Row
        fixedColCells.add(
          _buildFixedCell(
            theme: theme,
            title: 'Available Capacity',
            rowIndex: 2,
            tooltipMessage:
                "Available Capacity is calculated from the employee's standard weekly working hours and any specific capacity overrides/contracts for this period.",
            backgroundColor: theme.colorScheme.tertiary,
            textColor: theme.colorScheme.onTertiary,
            isBold: true,
          ),
        );

        final List<Widget> scrollCapacityCells = [];
        int colIndexCounter = 1;
        for (final emp in widget.selectedEmployees) {
          final isExpanded =
              !multiEmp || (widget.employeeExpanded[emp.email] ?? false);
          final empCaps = widget.capacities[emp.email] ?? [];

          final monthlyCapValues = List.generate(12, (index) {
            return CapacityCalculator.calculateMonthlyCapacity(
              empCaps,
              widget.selectedYear,
              index + 1,
            );
          });

          final cellGroupWidget = _buildScrollCellGroup(
            theme: theme,
            isExpanded: isExpanded,
            values: monthlyCapValues,
            cellWidth: monthCellWidth,
            sumWidth: sumCellWidth,
            isEditable: false,
            onChanged: (_, _) {},
            rowKey: 'cap_${emp.email}',
            backgroundColor: theme.colorScheme.tertiary,
            textColor: theme.colorScheme.onTertiary,
            isBold: true,
            rowIndex: 2,
            startColIndex: colIndexCounter,
          );
          scrollCapacityCells.add(cellGroupWidget);
          colIndexCounter += isExpanded ? 13 : 1;
        }
        scrollColRows.add(scrollCapacityCells);

        // Group Activities rows
        int rowIdx = 3;
        for (final group in widget.groups) {
          final groupActivities = widget.activities
              .where((act) => act.activityGroupId == group.id)
              .toList();
          if (groupActivities.isEmpty) continue;

          // Activity Group Header Row
          fixedColCells.add(
            _buildFixedCell(
              theme: theme,
              title: group.name,
              rowIndex: rowIdx,
              backgroundColor: const Color(0xFFCCE8F6),
              textColor: theme.colorScheme.primary,
              isBold: true,
              hasBorderHighlight: true,
            ),
          );

          final List<Widget> scrollGroupSumCells = [];
          colIndexCounter = 1;
          for (final emp in widget.selectedEmployees) {
            final isExpanded =
                !multiEmp || (widget.employeeExpanded[emp.email] ?? false);

            final groupSumValues = List.generate(12, (index) {
              final monthIdx = index + 1;
              double sum = 0.0;
              for (final act in groupActivities) {
                final allocKey = '${emp.email}_${act.id}';
                if (widget.isEditing) {
                  sum +=
                      widget.localAllocationEdits[allocKey]?[monthIdx] ?? 0.0;
                } else {
                  sum += _getAllocationValue(emp, act, monthIdx, allocMap);
                }
              }
              return sum;
            });

            scrollGroupSumCells.add(
              _buildScrollCellGroup(
                theme: theme,
                isExpanded: isExpanded,
                values: groupSumValues,
                cellWidth: monthCellWidth,
                sumWidth: sumCellWidth,
                isEditable: false,
                onChanged: (_, _) {},
                hasBorderHighlight: true,
                rowKey: 'group_sum_${group.id}_${emp.email}',
                backgroundColor: const Color(0xFFCCE8F6),
                textColor: theme.colorScheme.primary,
                isBold: true,
                rowIndex: rowIdx,
                startColIndex: colIndexCounter,
              ),
            );
            colIndexCounter += isExpanded ? 13 : 1;
          }
          scrollColRows.add(scrollGroupSumCells);
          rowIdx++;

          // Child Activity Rows
          for (final act in groupActivities) {
            fixedColCells.add(
              _buildFixedCell(
                theme: theme,
                title: act.name,
                rowIndex: rowIdx,
                activity: act,
                backgroundColor: Colors.transparent,
                textColor: theme.colorScheme.primary,
                isBold: false,
              ),
            );

            final List<Widget> scrollActivityCells = [];
            colIndexCounter = 1;
            for (final emp in widget.selectedEmployees) {
              final isExpanded =
                  !multiEmp || (widget.employeeExpanded[emp.email] ?? false);
              final allocKey = '${emp.email}_${act.id}';

              final assignedEmails = act.assignedUserEmails
                  .map((e) => e.trim().toLowerCase())
                  .toSet();
              final isAssigned = assignedEmails.contains(
                emp.email.trim().toLowerCase(),
              );

              final actValues = List.generate(12, (index) {
                final monthIdx = index + 1;
                if (widget.isEditing) {
                  return widget.localAllocationEdits[allocKey]?[monthIdx] ??
                      0.0;
                } else {
                  return _getAllocationValue(emp, act, monthIdx, allocMap);
                }
              });

              final isLocked = _isResourceLocked(emp.email, act.id);
              scrollActivityCells.add(
                _buildScrollCellGroup(
                  theme: theme,
                  isExpanded: isExpanded,
                  values: actValues,
                  cellWidth: monthCellWidth,
                  sumWidth: sumCellWidth,
                  isEditable: widget.isEditing && isAssigned && !isLocked,
                  isGreyedOut: !isAssigned || isLocked,
                  onChanged: (index, val) {
                    widget.localAllocationEdits.putIfAbsent(
                      allocKey,
                      () => {},
                    )[index + 1] = val;
                    setState(() {});
                  },
                  rowKey: allocKey,
                  backgroundColor: Colors.transparent,
                  textColor: theme.colorScheme.primary,
                  isBold: false,
                  rowIndex: rowIdx,
                  startColIndex: colIndexCounter,
                ),
              );
              colIndexCounter += isExpanded ? 13 : 1;
            }
            scrollColRows.add(scrollActivityCells);
            rowIdx++;
          }
        }

        // Planned Capacity Row
        fixedColCells.add(
          _buildFixedCell(
            theme: theme,
            title: 'Planned Capacity',
            rowIndex: rowIdx,
            backgroundColor: theme.colorScheme.primary,
            textColor: theme.colorScheme.onPrimary,
            isBold: true,
          ),
        );

        final List<Widget> scrollSumCells = [];
        colIndexCounter = 1;
        for (final emp in widget.selectedEmployees) {
          final isExpanded =
              !multiEmp || (widget.employeeExpanded[emp.email] ?? false);

          final totalSumValues = List.generate(12, (index) {
            final monthIdx = index + 1;
            double sum = 0.0;
            for (final act in widget.activities) {
              final allocKey = '${emp.email}_${act.id}';
              if (widget.isEditing) {
                sum += widget.localAllocationEdits[allocKey]?[monthIdx] ?? 0.0;
              } else {
                sum += _getAllocationValue(emp, act, monthIdx, allocMap);
              }
            }
            return sum;
          });

          scrollSumCells.add(
            _buildScrollCellGroup(
              theme: theme,
              isExpanded: isExpanded,
              values: totalSumValues,
              cellWidth: monthCellWidth,
              sumWidth: sumCellWidth,
              isEditable: false,
              onChanged: (_, _) {},
              rowKey: 'total_sum_${emp.email}',
              backgroundColor: theme.colorScheme.primary,
              textColor: theme.colorScheme.onPrimary,
              isBold: true,
              rowIndex: rowIdx,
              startColIndex: colIndexCounter,
            ),
          );
          colIndexCounter += isExpanded ? 13 : 1;
        }
        scrollColRows.add(scrollSumCells);
        rowIdx++;

        // Delta Row
        fixedColCells.add(
          _buildFixedCell(
            theme: theme,
            title: 'Delta',
            rowIndex: rowIdx,
            tooltipMessage:
                'Delta = Available Capacity - Planned Capacity (total activity allocations for this employee)',
            backgroundColor: Colors.transparent,
            textColor: theme.colorScheme.onSurface,
            isBold: true,
          ),
        );

        final List<Widget> scrollDeltaCells = [];
        colIndexCounter = 1;
        for (final emp in widget.selectedEmployees) {
          final isExpanded =
              !multiEmp || (widget.employeeExpanded[emp.email] ?? false);
          final empCaps = widget.capacities[emp.email] ?? [];

          final deltaValues = List.generate(12, (index) {
            final monthIdx = index + 1;
            final valCap = CapacityCalculator.calculateMonthlyCapacity(
              empCaps,
              widget.selectedYear,
              monthIdx,
            );
            double sumVal = 0.0;
            for (final act in widget.activities) {
              final allocKey = '${emp.email}_${act.id}';
              if (widget.isEditing) {
                sumVal +=
                    widget.localAllocationEdits[allocKey]?[monthIdx] ?? 0.0;
              } else {
                sumVal += _getAllocationValue(emp, act, monthIdx, allocMap);
              }
            }
            return valCap - sumVal;
          });

          scrollDeltaCells.add(
            _buildScrollCellGroup(
              theme: theme,
              isExpanded: isExpanded,
              values: deltaValues,
              cellWidth: monthCellWidth,
              sumWidth: sumCellWidth,
              isEditable: false,
              onChanged: (_, _) {},
              rowKey: 'delta_${emp.email}',
              backgroundColor: Colors.transparent,
              textColor: theme.colorScheme.onSurface,
              isBold: true,
              rowIndex: rowIdx,
              startColIndex: colIndexCounter,
            ),
          );
          colIndexCounter += isExpanded ? 13 : 1;
        }
        scrollColRows.add(scrollDeltaCells);

        return Focus(
          focusNode: _tableFocusNode,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              final isShortcut =
                  (HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed);
              if (isShortcut && event.logicalKey == LogicalKeyboardKey.keyC) {
                _copyEmployeeSelectedCells();
                return KeyEventResult.handled;
              }
              if (widget.isEditing &&
                  isShortcut &&
                  event.logicalKey == LogicalKeyboardKey.keyV) {
                _pasteEmployeeSelectedCells();
                return KeyEventResult.handled;
              }

              if (_selectedRange != null) {
                final key = event.logicalKey;

                // 1. Arrow Key Navigation (when in selected or typing mode)
                if (key == LogicalKeyboardKey.arrowUp ||
                    key == LogicalKeyboardKey.arrowDown) {
                  if (_cellEditMode == CellEditMode.selected ||
                      _cellEditMode == CellEditMode.typingFromType ||
                      _cellEditMode == CellEditMode.typingFromDouble) {
                    _navigateSelection(key);
                    return KeyEventResult.handled;
                  }
                } else if (key == LogicalKeyboardKey.arrowLeft ||
                    key == LogicalKeyboardKey.arrowRight) {
                  if (_cellEditMode == CellEditMode.selected) {
                    _navigateSelection(key);
                    return KeyEventResult.handled;
                  }
                }

                // 2. Typing to Enter Typing Mode (when in selected mode and editing is enabled)
                if (widget.isEditing &&
                    _cellEditMode == CellEditMode.selected) {
                  final character = event.character;
                  if (_isCharacterKey(key, character)) {
                    _startTypingFromType(
                      _selectedRange!.start.row,
                      _selectedRange!.start.col,
                      character!,
                    );
                    return KeyEventResult.handled;
                  } else if (key == LogicalKeyboardKey.backspace ||
                      key == LogicalKeyboardKey.delete) {
                    _startTypingFromType(
                      _selectedRange!.start.row,
                      _selectedRange!.start.col,
                      '',
                    );
                    return KeyEventResult.handled;
                  }
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Area (Frozen: Names, Months Header, Available Capacity)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: fixedColWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: fixedColCells.sublist(0, 3),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _headerScrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(3, (rowIndex) {
                          return Row(children: scrollColRows[rowIndex]);
                        }),
                      ),
                    ),
                  ),
                ],
              ),
              // 2. Scrollable Body (Activity Groups and Activities)
              Flexible(
                child: Listener(
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent) {
                      final double dy = pointerSignal.scrollDelta.dy;
                      if (dy != 0 && _verticalScrollController.hasClients) {
                        final newOffset = (_verticalScrollController.offset + dy).clamp(
                          _verticalScrollController.position.minScrollExtent,
                          _verticalScrollController.position.maxScrollExtent,
                        );
                        _verticalScrollController.jumpTo(newOffset);
                      }
                    }
                  },
                  child: SingleChildScrollView(
                    controller: _verticalScrollController,
                    scrollDirection: Axis.vertical,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: fixedColWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: fixedColCells.sublist(
                              3,
                              fixedColCells.length - 2,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Listener(
                            onPointerSignal: (pointerSignal) {
                              if (pointerSignal is PointerScrollEvent) {
                                final double dy = pointerSignal.scrollDelta.dy;
                                if (dy != 0 &&
                                    _verticalScrollController.hasClients) {
                                  final newOffset =
                                      (_verticalScrollController.offset + dy)
                                          .clamp(
                                            _verticalScrollController
                                                .position
                                                .minScrollExtent,
                                            _verticalScrollController
                                                .position
                                                .maxScrollExtent,
                                          );
                                  _verticalScrollController.jumpTo(newOffset);
                                }
                              }
                            },
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              controller: _middleScrollController,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(
                                  scrollColRows.length - 5,
                                  (rowIndex) {
                                    return Row(
                                      children: scrollColRows[rowIndex + 3],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 3. Footer Area (Frozen: Planned Capacity, Delta)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: fixedColWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: fixedColCells.sublist(fixedColCells.length - 2),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _footerScrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(2, (rowIndex) {
                          return Row(
                            children:
                                scrollColRows[scrollColRows.length -
                                    2 +
                                    rowIndex],
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFixedCell({
    required ThemeData theme,
    required String title,
    required int rowIndex,
    Color? backgroundColor,
    Color? textColor,
    bool isBold = false,
    bool hasBorderHighlight = false,
    String? tooltipMessage,
    ActivityModel? activity,
  }) {
    final bool isWhiteBackground = backgroundColor == null ||
        backgroundColor == Colors.transparent ||
        backgroundColor == Colors.white;
    final resolvedTextColor = textColor ??
        (isWhiteBackground
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface);

    Widget labelWidget;
    if (activity != null) {
      final category = widget.categories.firstWhere(
        (c) => c.id == activity.categoryId,
        orElse: () => CategoryModel(
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
        ),
      );

      final lock = _getActivityLock(activity.id);
      labelWidget = Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          if (lock != null) ...[
            Tooltip(
              message: 'Locked by ${lock.userFullName}',
              child: Icon(Icons.lock, size: 14, color: theme.colorScheme.error),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Tooltip(
                    message: title,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: isBold
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: lock != null
                            ? resolvedTextColor.withValues(alpha: 0.5)
                            : resolvedTextColor,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (activity.categoryId != null &&
                    activity.categoryId!.isNotEmpty &&
                    category.name.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      category.name,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              _ignoreSelectionThisPointer = true;
            },
            child: IconButton(
              onPressed: lock == null
                  ? () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AssignDialog(
                            activity: activity,
                            allEmployees: widget.selectedEmployees,
                            orgUnitId: widget.orgUnitId,
                          );
                        },
                      );
                    }
                  : null,
              icon: Icon(
                Icons.more_vert,
                size: 18,
                color: lock != null
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                    : null,
              ),
              tooltip: lock != null
                  ? 'Locked by ${lock.userFullName}'
                  : 'Assign Employees',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      );
    } else if (tooltipMessage != null) {
      labelWidget = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: title,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: resolvedTextColor,
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
                  color: resolvedTextColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      labelWidget = Text(
        title,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: resolvedTextColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final col0Child = Padding(
      padding: EdgeInsets.only(
        left: 12.0,
        right: activity != null ? 4.0 : 12.0,
      ),
      child: Align(alignment: Alignment.centerLeft, child: labelWidget),
    );

    return _buildInteractiveCell(
      r: rowIndex,
      c: 0,
      width: 300.0,
      height: 48,
      child: col0Child,
      rowKey: 'fixed_$rowIndex',
      backgroundColor: backgroundColor,
      textColor: resolvedTextColor,
      isBold: isBold,
      hasBorderHighlight: hasBorderHighlight,
    );
  }

  int get _firstActivityRowIndex =>
      rowMappings.indexWhere((rm) => rm.type == EmployeeRowType.activity);
  int get _lastActivityRowIndex =>
      rowMappings.lastIndexWhere((rm) => rm.type == EmployeeRowType.activity);

  bool _isCellEditable(int r, int c) {
    if (!widget.isEditing) return false;
    if (r < 0 || r >= rowMappings.length) return false;
    final rowMapping = rowMappings[r];
    if (rowMapping.type != EmployeeRowType.activity) return false;
    if (c < 1 || c > colMappings.length) return false;
    final colMapping = colMappings[c - 1];
    if (colMapping.isSum) return false;

    final act = rowMapping.activity!;
    final emp = colMapping.employee;
    if (_isResourceLocked(emp.email, act.id)) return false;
    final assignedEmails = act.assignedUserEmails
        .map((e) => e.trim().toLowerCase())
        .toSet();
    return assignedEmails.contains(emp.email.trim().toLowerCase());
  }

  Widget _buildInteractiveCell({
    required int r,
    required int c,
    required double width,
    required Widget child,
    required String rowKey,
    bool isCellEditable = false,
    Color? backgroundColor,
    Color? textColor,
    bool isBold = false,
    double height = 48,
    bool isGreyedOut = false,
    bool hasBorderHighlight = false,
    FocusNode? focusNode,
  }) {
    final theme = widget.theme;
    final isSelected =
        _selectedRange != null &&
        _selectedRange!.contains(r, c) &&
        (!widget.isEditing || _isCellEditable(r, c));
    final isDragFill =
        _dragFillRange != null &&
        _dragFillRange!.contains(r, c) &&
        (!widget.isEditing || _isCellEditable(r, c));

    final isHeader = rowKey.startsWith('header');
    final baseColor = isGreyedOut
        ? (Colors.grey[200] ?? const Color(0xFFEEEEEE))
        : (isHeader ? Colors.white : (backgroundColor ?? Colors.transparent));

    final displayColor = isSelected
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.12),
            baseColor,
          )
        : (isDragFill
              ? Color.alphaBlend(
                  theme.colorScheme.secondary.withValues(alpha: 0.12),
                  baseColor,
                )
              : baseColor);

    final BorderSide bottomBorder = isHeader
        ? BorderSide(color: theme.colorScheme.primary, width: 2.0)
        : BorderSide(
            color: theme.colorScheme.primary,
            width: hasBorderHighlight ? 1.5 : 0.5,
          );

    BoxDecoration cellDeco = BoxDecoration(
      color: displayColor,
      border: Border(
        bottom: bottomBorder,
      ),
    );

    if (isDragFill) {
      final borderSide = BorderSide(
        color: theme.colorScheme.secondary,
        width: 1.5,
      );
      cellDeco = cellDeco.copyWith(
        border: Border(
          top: r == _dragFillRange!.minRow ? borderSide : BorderSide.none,
          bottom: r == _dragFillRange!.maxRow ? borderSide : bottomBorder,
          left: c == _dragFillRange!.minCol ? borderSide : BorderSide.none,
          right: c == _dragFillRange!.maxCol ? borderSide : BorderSide.none,
        ),
      );
    } else if (isSelected) {
      final borderSide = BorderSide(
        color: theme.colorScheme.primary,
        width: 1.5,
      );
      cellDeco = cellDeco.copyWith(
        border: Border(
          top: r == _selectedRange!.minRow ? borderSide : BorderSide.none,
          bottom: r == _selectedRange!.maxRow ? borderSide : bottomBorder,
          left: c == _selectedRange!.minCol ? borderSide : BorderSide.none,
          right: c == _selectedRange!.maxCol ? borderSide : BorderSide.none,
        ),
      );
    }

    Widget cellChild = child;

    final isBottomRight =
        _selectedRange != null &&
        r == _selectedRange!.maxRow &&
        c == _selectedRange!.maxCol;

    if (isBottomRight && widget.isEditing && isCellEditable && c >= 1) {
      cellChild = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: cellChild),
          Positioned(
            bottom: 0,
            right: 0,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                _isDraggingFill = true;
                _dragFillStart = CellPosition(r, c);
                _dragFillRange = CellRange(_dragFillStart!, _dragFillStart!);
              },
              onPointerUp: (event) {
                if (_isDraggingFill && _dragFillRange != null && _dragFillRange!.start == _dragFillRange!.end) {
                  setState(() {
                    _isDraggingFill = false;
                    _dragFillRange = null;
                    _dragFillStart = null;
                  });
                }
              },
              child: GestureDetector(
                key: Key('employee_drag_fill_handle_${r}_$c'),
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  setState(() {
                    _isDraggingFill = true;
                    _dragFillStart = CellPosition(r, c);
                    _dragFillRange = CellRange(
                      _dragFillStart!,
                      _dragFillStart!,
                    );
                  });
                },
                onPanUpdate: (details) {
                  if (_isDraggingFill && _dragFillStart != null) {
                    final currentCell = _getCellAtGlobalPosition(
                      details.globalPosition,
                    );
                    if (currentCell != null) {
                      setState(() {
                        final rowDiff = (currentCell.row - _dragFillStart!.row)
                            .abs();
                        final colDiff = (currentCell.col - _dragFillStart!.col)
                            .abs();
                        if (rowDiff >= colDiff) {
                          _dragFillRange = CellRange(
                            _dragFillStart!,
                            CellPosition(currentCell.row, _dragFillStart!.col),
                          );
                        } else {
                          _dragFillRange = CellRange(
                            _dragFillStart!,
                            CellPosition(_dragFillStart!.row, currentCell.col),
                          );
                        }
                      });
                    }
                  }
                },
                onPanEnd: (details) {
                  setState(() {
                    _performEmployeeDragFill();
                    _isDraggingFill = false;
                    _dragFillRange = null;
                    _dragFillStart = null;
                  });
                },
                onPanCancel: () {
                  setState(() {
                    _isDraggingFill = false;
                    _dragFillRange = null;
                    _dragFillStart = null;
                  });
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.precise,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final MenuController? controller = widget.isEditing
        ? MenuController()
        : null;
    final isRightHalf = c >= (colMappings.length / 2);

    Widget interactiveChild = cellChild;
    GestureTapDownCallback? onSecondaryTapDown;

    if (widget.isEditing) {
      final menuItems = [
        MenuItemButton(
          key: Key('employee_context_menu_copy_${r}_$c'),
          onPressed: _selectedRange != null
              ? () => _copyEmployeeSelectedCells()
              : null,
          leadingIcon: const Icon(Icons.copy, size: 18),
          child: const Text('Copy'),
        ),
        MenuItemButton(
          key: Key('employee_context_menu_paste_${r}_$c'),
          onPressed: isCellEditable && _selectedRange != null
              ? () => _pasteEmployeeSelectedCells()
              : null,
          leadingIcon: const Icon(Icons.paste, size: 18),
          child: const Text('Paste'),
        ),
      ];

      interactiveChild = Directionality(
        textDirection: isRightHalf ? TextDirection.rtl : TextDirection.ltr,
        child: MenuAnchor(
          controller: controller,
          alignmentOffset: const Offset(0, 0),
          menuChildren: menuItems.map((item) {
            return Directionality(
              textDirection: TextDirection.ltr,
              child: item,
            );
          }).toList(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: cellChild,
          ),
        ),
      );

      onSecondaryTapDown = (details) {
        final currentCell = _getCellAtGlobalPosition(details.globalPosition);
        if (currentCell != null) {
          if (_selectedRange == null ||
              !_selectedRange!.contains(currentCell.row, currentCell.col)) {
            setState(() {
              _selectionStart = currentCell;
              _selectedRange = CellRange(_selectionStart!, _selectionStart!);
            });
          }
        }
        controller?.open();
      };
    }

    Widget resultCell = HoverCell(
      key: c == 0
          ? rowKeys[r]
          : (r == 1 ? colKeys[c] : Key('employee_cell_${r}_$c')),
      width: width,
      height: height,
      decoration: cellDeco,
      onTap: () {
        // Consume tap gesture to prevent body's GestureDetector from clearing selection
      },
      onPointerDown: (event) {
        if (_ignoreSelectionThisPointer) {
          _ignoreSelectionThisPointer = false;
          return;
        }
        if (event.buttons != 1) return;
        if (_isDraggingFill) return;
        if (widget.isEditing && !isCellEditable) return;

        final isCurrentEditing =
            _selectedRange != null &&
            _selectedRange!.start.row == r &&
            _selectedRange!.start.col == c &&
            (_cellEditMode == CellEditMode.typingFromType ||
                _cellEditMode == CellEditMode.typingFromDouble);

        if (!isCurrentEditing) {
          _tableFocusNode.requestFocus();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_tableFocusNode.canRequestFocus) {
              _tableFocusNode.requestFocus();
            }
          });

          widget.onTableTap('employee');
        }

        setState(() {
          _selectionStart = CellPosition(r, c);
          _isDraggingSelection = true;
          _dragFillRange = null;
          if (!isCurrentEditing) {
            _selectedRange = CellRange(_selectionStart!, _selectionStart!);
            _cellEditMode = CellEditMode.selected;
          }
        });
      },
      onPointerMove: (event) {
        if (_isDraggingSelection && _selectionStart != null) {
          var currentCell = _getCellAtGlobalPosition(event.position);
          if (currentCell != null && currentCell != _selectedRange?.end) {
            if (widget.isEditing) {
              final firstAct = _firstActivityRowIndex;
              final lastAct = _lastActivityRowIndex;
              if (firstAct != -1 && lastAct != -1) {
                final clampedRow = currentCell.row.clamp(firstAct, lastAct);
                final clampedCol = currentCell.col.clamp(1, colMappings.length);
                currentCell = CellPosition(clampedRow, clampedCol);
              }
            }
            setState(() {
              _selectedRange = CellRange(_selectionStart!, currentCell!);
            });
          }
        }
      },
      onPointerUp: (event) {
        if (_isDraggingSelection) {
          setState(() {
            _isDraggingSelection = false;
          });
        }
      },
      onDoubleTap: (widget.isEditing && isCellEditable)
          ? () => _startTypingFromDouble(r, c)
          : null,
      onSecondaryTapDown: onSecondaryTapDown,
      child: interactiveChild,
    );

    if (r == 1 && c == 0) {
      resultCell = KeyedSubtree(
        key: const Key('fixed_1'),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(12)),
          child: resultCell,
        ),
      );
    }

    return resultCell;
  }

  Widget _buildScrollCellGroup({
    required ThemeData theme,
    required bool isExpanded,
    required List<double> values,
    required double cellWidth,
    required double sumWidth,
    required bool isEditable,
    required void Function(int, double) onChanged,
    required String rowKey,
    bool isGreyedOut = false,
    bool hasBorderHighlight = false,
    Color? backgroundColor,
    Color? textColor,
    bool isBold = false,
    required int rowIndex,
    required int startColIndex,
  }) {
    double rowSum = values.fold(0.0, (sum, val) => sum + val);

    final isDelta = rowKey.startsWith('delta_');

    final bool isWhiteBackground = backgroundColor == null ||
        backgroundColor == Colors.transparent ||
        backgroundColor == Colors.white;
    final resolvedTextColor = textColor ??
        (isWhiteBackground
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isExpanded) ...[
          ...List.generate(12, (index) {
            final val = values[index];
            final displayVal = val == 0
                ? '0'
                : val.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
            final colIdx = startColIndex + index;

            final focusKey = '${rowKey}_$index';
            final cellFocusNode = widget.focusNodesCache.putIfAbsent(
              focusKey,
              () => FocusNode(),
            );
            cellFocusNode.onKeyEvent = (node, event) {
              if (event is KeyDownEvent) {
                final key = event.logicalKey;
                if (key == LogicalKeyboardKey.enter) {
                  if (_cellEditMode == CellEditMode.typingFromType ||
                      _cellEditMode == CellEditMode.typingFromDouble) {
                    final ctrl = widget.controllersCache[focusKey];
                    if (ctrl != null) {
                      final parsed = double.tryParse(ctrl.text) ?? 0.0;
                      onChanged(index, parsed);
                    }
                    setState(() {
                      _cellEditMode = CellEditMode.selected;
                    });
                    _tableFocusNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                }
                if (key == LogicalKeyboardKey.arrowUp ||
                    key == LogicalKeyboardKey.arrowDown) {
                  if (_cellEditMode == CellEditMode.typingFromType ||
                      _cellEditMode == CellEditMode.typingFromDouble) {
                    _navigateSelection(key);
                    return KeyEventResult.handled;
                  }
                } else if (key == LogicalKeyboardKey.arrowLeft ||
                    key == LogicalKeyboardKey.arrowRight) {
                  if (_cellEditMode == CellEditMode.selected) {
                    _navigateSelection(key);
                    return KeyEventResult.handled;
                  } else {
                    return KeyEventResult.skipRemainingHandlers;
                  }
                }
              }
              return KeyEventResult.ignored;
            };

            final isCellEditing =
                isEditable &&
                !isGreyedOut &&
                _selectedRange != null &&
                _selectedRange!.start.row == rowIndex &&
                _selectedRange!.start.col == colIdx &&
                (_cellEditMode == CellEditMode.typingFromType ||
                    _cellEditMode == CellEditMode.typingFromDouble);

            final isDark = theme.brightness == Brightness.dark;
            final errorColor = isDark
                ? const Color(0xFFE57373)
                : const Color(0xFFD32F2F);
            final successColor = isDark
                ? const Color(0xFF81C784)
                : const Color(0xFF2E7D32);

            final Color activeTextColor = isDelta
                ? (val < 0
                      ? errorColor
                      : successColor)
                : resolvedTextColor;

            final cellStyle = TextStyle(
              color: isGreyedOut ? Colors.grey[400] : activeTextColor,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            );

            final cellChild = Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
              child: isCellEditing
                  ? Center(
                      child: TextField(
                        key: Key('edit_${rowKey}_${index + 1}'),
                        controller: _getOrCreateController(
                          focusKey,
                          displayVal,
                          isEditing: isCellEditing,
                        ),
                        focusNode: cellFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        style: cellStyle,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onTap: () {
                          if (_cellEditMode != CellEditMode.typingFromDouble) {
                            final ctrl = widget.controllersCache[focusKey];
                            if (ctrl != null) {
                              ctrl.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: ctrl.text.length,
                              );
                            }
                          }
                        },
                        onChanged: (text) {
                          final parsed = double.tryParse(text) ?? 0.0;
                          onChanged(index, parsed);
                        },
                        onSubmitted: (text) {
                          final parsed = double.tryParse(text) ?? 0.0;
                          onChanged(index, parsed);
                          setState(() {
                            _cellEditMode = CellEditMode.selected;
                          });
                          _tableFocusNode.requestFocus();
                        },
                      ),
                    )
                  : Center(
                      child: Text(
                        isGreyedOut ? '' : displayVal,
                        style: cellStyle,
                      ),
                    ),
            );

            return _buildInteractiveCell(
              r: rowIndex,
              c: colIdx,
              width: cellWidth,
              child: cellChild,
              rowKey: rowKey,
              isCellEditable: isEditable && !isGreyedOut,
              isGreyedOut: isGreyedOut,
              backgroundColor: backgroundColor,
              textColor: resolvedTextColor,
              isBold: isBold,
              hasBorderHighlight: hasBorderHighlight,
              focusNode: (isEditable && !isGreyedOut) ? cellFocusNode : null,
            );
          }),
        ],
        _buildInteractiveCell(
          r: rowIndex,
          c: startColIndex + (isExpanded ? 12 : 0),
          width: sumWidth,
          child: Center(
            child: Text(
              isGreyedOut
                  ? ''
                  : (rowSum == 0
                        ? '0'
                        : rowSum
                              .toStringAsFixed(1)
                              .replaceAll(RegExp(r'\.0$'), '')),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isGreyedOut
                    ? Colors.grey[400]
                    : (isDelta
                          ? (rowSum < 0
                                ? theme.colorScheme.error
                                : (theme
                                          .extension<AppColorsExtension>()
                                          ?.success ??
                                      const Color(0xFF146947)))
                          : resolvedTextColor),
                fontSize: 14,
              ),
            ),
          ),
          rowKey: rowKey,
          isCellEditable: false,
          isGreyedOut: isGreyedOut,
          backgroundColor: backgroundColor,
          textColor: resolvedTextColor,
          isBold: true,
          hasBorderHighlight: hasBorderHighlight,
        ),
      ],
    );
  }
}

// =========================================================================
// EXCEL SUPPORT CLASSES
// =========================================================================
