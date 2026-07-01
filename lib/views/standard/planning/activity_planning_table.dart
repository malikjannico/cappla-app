import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/providers/providers.dart';
import '../../../core/utils/csv_export_helper.dart';
import 'cell_selection.dart';
import 'hover_cell.dart';

class ActivityPlanningTable extends StatefulWidget {
  final ThemeData theme;
  final ActivityModel activity;
  final PlanningDemandModel demand;
  final List<UserModel> employees;
  final List<PlanningAllocationModel> allocations;
  final bool isEditing;
  final Map<String, Map<int, double>> localDemandEdits;
  final Map<String, Map<int, double>> localAllocationEdits;
  final int selectedYear;
  final String orgUnitId;
  final Map<String, TextEditingController> controllersCache;
  final String? activeTableId;
  final ValueChanged<String?> onTableTap;
  final Map<String, FocusNode> focusNodesCache;
  final void Function(double) onDemandChanged;
  final void Function(int, double) onAllocationChanged;

  const ActivityPlanningTable({
    super.key,
    required this.theme,
    required this.activity,
    required this.demand,
    required this.employees,
    required this.allocations,
    required this.isEditing,
    required this.localDemandEdits,
    required this.localAllocationEdits,
    required this.selectedYear,
    required this.orgUnitId,
    required this.controllersCache,
    required this.activeTableId,
    required this.onTableTap,
    required this.focusNodesCache,
    required this.onDemandChanged,
    required this.onAllocationChanged,
  });

  @override
  State<ActivityPlanningTable> createState() => ActivityPlanningTableState();
}

class ActivityPlanningTableState extends State<ActivityPlanningTable> {
  final Map<String, MenuController> _menuControllersCache = {};

  MenuController _getOrCreateMenuController(String key) {
    return _menuControllersCache.putIfAbsent(key, () => MenuController());
  }

  String? _getCharacterFromKey(LogicalKeyboardKey key, String? character) {
    if (character != null && character.isNotEmpty) {
      return character;
    }
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) return '0';
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) return '1';
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) return '2';
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) return '3';
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) return '4';
    if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) return '5';
    if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) return '6';
    if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) return '7';
    if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) return '8';
    if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) return '9';
    if (key == LogicalKeyboardKey.period || key == LogicalKeyboardKey.numpadDecimal) return '.';
    if (key == LogicalKeyboardKey.comma) return ',';
    if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) return '-';
    return null;
  }

  CellRange? _selectedRange;
  CellPosition? _selectionStart;
  bool _isDraggingSelection = false;
  CellRange? _dragFillRange;
  CellPosition? _dragFillStart;
  bool _isDraggingFill = false;
  final FocusNode _tableFocusNode = FocusNode();
  CellEditMode _cellEditMode = CellEditMode.none;

  final List<GlobalKey> rowKeys = [];
  final List<GlobalKey> colKeys = [];

  void _syncKeys() {
    final totalRowsCount = 1 + 1 + widget.employees.length + 1 + 1;
    if (rowKeys.length < totalRowsCount) {
      rowKeys.addAll(
        List.generate(totalRowsCount - rowKeys.length, (_) => GlobalKey()),
      );
    } else if (rowKeys.length > totalRowsCount) {
      rowKeys.removeRange(totalRowsCount, rowKeys.length);
    }

    if (colKeys.length < 14) {
      colKeys.addAll(List.generate(14 - colKeys.length, (_) => GlobalKey()));
    } else if (colKeys.length > 14) {
      colKeys.removeRange(14, colKeys.length);
    }
  }

  @override
  void initState() {
    super.initState();
    _syncKeys();
  }

  @override
  void didUpdateWidget(covariant ActivityPlanningTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTableId != widget.activity.id) {
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
    final char = _getCharacterFromKey(key, character);
    if (char == null || char.isEmpty) return false;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      return false;
    }
    final RegExp numRegExp = RegExp(r'^[0-9\.\,\-]$');
    return numRegExp.hasMatch(char);
  }

  void _navigateSelection(LogicalKeyboardKey key) {
    if (_selectedRange == null) return;

    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final start = _selectionStart ?? _selectedRange!.start;
    final end = _selectedRange!.end;
    final current = isShiftPressed ? end : start;
    int r = current.row;
    int c = current.col;

    if (key == LogicalKeyboardKey.arrowUp) {
      r = r - 1;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      r = r + 1;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      c = c - 1;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      c = c + 1;
    }

    if (widget.isEditing) {
      final maxRow = 1 + widget.employees.length;
      r = r.clamp(1, maxRow);
      c = c.clamp(1, 12);
    } else {
      final maxRow = 2 + widget.employees.length + 1;
      r = r.clamp(0, maxRow);
      c = c.clamp(0, 13);
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

      final rowKey = _getRowKeyForPosition(r);
      if (rowKey != null) {
        final focusKey = '${rowKey}_${c - 1}';
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

      final rowKey = _getRowKeyForPosition(r);
      if (rowKey != null) {
        final focusKey = '${rowKey}_${c - 1}';
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

  String? _getRowKeyForPosition(int r) {
    if (r == 1) {
      return 'demand_${widget.activity.id}';
    } else if (r >= 2 && r < 2 + widget.employees.length) {
      final emp = widget.employees[r - 2];
      return '${emp.email}_${widget.activity.id}';
    }
    return null;
  }

  @override
  void dispose() {
    _tableFocusNode.dispose();
    super.dispose();
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

  double _getCellValue(int r, int c) {
    if (c < 1 || c > 12) return 0.0;

    if (r == 1) {
      if (widget.isEditing) {
        return widget.localDemandEdits[widget.activity.id]?[c] ?? 0.0;
      }
      return _getDemandValue(widget.demand, c);
    } else if (r >= 2 && r < 2 + widget.employees.length) {
      final emp = widget.employees[r - 2];
      final allocKey = '${emp.email}_${widget.activity.id}';
      if (widget.isEditing) {
        return widget.localAllocationEdits[allocKey]?[c] ?? 0.0;
      }
      final alloc = widget.allocations.firstWhere(
        (a) =>
            a.activityId == widget.activity.id &&
            a.userEmail.trim().toLowerCase() == emp.email.trim().toLowerCase(),
        orElse: () => PlanningAllocationModel(
          id: '',
          userEmail: emp.email,
          activityId: widget.activity.id,
          year: widget.selectedYear,
          orgUnitId: widget.orgUnitId,
        ),
      );
      return _getAllocationValue(alloc, c);
    }
    return 0.0;
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

    final row0Box = rowKeys[0].currentContext?.findRenderObject() as RenderBox?;
    if (row0Box != null) {
      final position = row0Box.localToGlobal(Offset.zero);
      final left = position.dx;
      final right = position.dx + 180.0;
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
        final right0 = position.dx + 180.0;
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

  void _copySelectedCells() async {
    if (_selectedRange == null) return;
    final buffer = StringBuffer();
    for (int r = _selectedRange!.minRow; r <= _selectedRange!.maxRow; r++) {
      final rowValues = <String>[];
      for (int c = _selectedRange!.minCol; c <= _selectedRange!.maxCol; c++) {
        if (c == 0) {
          if (r == 0) {
            rowValues.add('Employees');
          } else if (r == 1) {
            rowValues.add('Demand');
          } else if (r >= 2 && r < 2 + widget.employees.length) {
            rowValues.add(widget.employees[r - 2].fullName);
          } else if (r == 2 + widget.employees.length) {
            rowValues.add('Planned Capacity');
          } else if (r == 2 + widget.employees.length + 1) {
            rowValues.add('Delta');
          }
        } else if (c >= 1 && c <= 12) {
          if (r == 0) {
            rowValues.add(months[c - 1].substring(0, 3));
          } else {
            double val = _getCellValue(r, c);
            rowValues.add(
              val == 0
                  ? '0'
                  : val.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
            );
          }
        } else if (c == 13) {
          if (r == 0) {
            rowValues.add('Sum');
          } else {
            double rowSum = 0.0;
            if (r == 1 || (r >= 2 && r < 2 + widget.employees.length)) {
              for (int m = 1; m <= 12; m++) {
                rowSum += _getCellValue(r, m);
              }
            } else if (r == 2 + widget.employees.length) {
              for (
                int rowIdx = 2;
                rowIdx < 2 + widget.employees.length;
                rowIdx++
              ) {
                for (int m = 1; m <= 12; m++) {
                  rowSum += _getCellValue(rowIdx, m);
                }
              }
            } else if (r == 2 + widget.employees.length + 1) {
              double demSum = 0.0;
              double allocSum = 0.0;
              for (int m = 1; m <= 12; m++) {
                demSum += _getCellValue(1, m);
              }
              for (
                int rowIdx = 2;
                rowIdx < 2 + widget.employees.length;
                rowIdx++
              ) {
                for (int m = 1; m <= 12; m++) {
                  allocSum += _getCellValue(rowIdx, m);
                }
              }
              rowSum = demSum - allocSum;
            }
            rowValues.add(
              rowSum == 0
                  ? '0'
                  : rowSum.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
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
    final headers = ['Entity/Month', ...months, 'Sum'];
    String csvEscape(String value) {
      if (value.contains(',') ||
          value.contains('"') ||
          value.contains('\n') ||
          value.contains('\r')) {
        return '"${value.replaceAll('"', '""')}"';
      }
      return value;
    }

    buffer.writeln(headers.map(csvEscape).join(','));

    final totalRows = 1 + widget.employees.length + 1 + 1;
    for (int r = 1; r <= totalRows; r++) {
      final rowValues = <String>[];

      String label = '';
      if (r == 1) {
        label = 'Demand';
      } else if (r >= 2 && r < 2 + widget.employees.length) {
        label = widget.employees[r - 2].fullName;
      } else if (r == 2 + widget.employees.length) {
        label = 'Planned Capacity';
      } else if (r == 2 + widget.employees.length + 1) {
        label = 'Delta';
      }
      rowValues.add(label);

      for (int c = 1; c <= 12; c++) {
        double val = 0.0;
        if (r == 1 || (r >= 2 && r < 2 + widget.employees.length)) {
          val = _getCellValue(r, c);
        } else if (r == 2 + widget.employees.length) {
          for (int empIdx = 2; empIdx < 2 + widget.employees.length; empIdx++) {
            val += _getCellValue(empIdx, c);
          }
        } else if (r == 2 + widget.employees.length + 1) {
          double demandVal = _getCellValue(1, c);
          double plannedVal = 0.0;
          for (int empIdx = 2; empIdx < 2 + widget.employees.length; empIdx++) {
            plannedVal += _getCellValue(empIdx, c);
          }
          val = demandVal - plannedVal;
        }
        rowValues.add(
          val == 0
              ? '0'
              : val.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
        );
      }

      double rowSum = 0.0;
      if (r == 1 || (r >= 2 && r < 2 + widget.employees.length)) {
        for (int m = 1; m <= 12; m++) {
          rowSum += _getCellValue(r, m);
        }
      } else if (r == 2 + widget.employees.length) {
        for (int empIdx = 2; empIdx < 2 + widget.employees.length; empIdx++) {
          for (int m = 1; m <= 12; m++) {
            rowSum += _getCellValue(empIdx, m);
          }
        }
      } else if (r == 2 + widget.employees.length + 1) {
        double demSum = 0.0;
        double allocSum = 0.0;
        for (int m = 1; m <= 12; m++) {
          demSum += _getCellValue(1, m);
        }
        for (int empIdx = 2; empIdx < 2 + widget.employees.length; empIdx++) {
          for (int m = 1; m <= 12; m++) {
            allocSum += _getCellValue(empIdx, m);
          }
        }
        rowSum = demSum - allocSum;
      }
      rowValues.add(
        rowSum == 0
            ? '0'
            : rowSum.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
      );

      buffer.writeln(rowValues.map(csvEscape).join(','));
    }

    final fileName =
        'activity_planning_${widget.activity.name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}_${widget.selectedYear}.csv';
    saveCsvFile(buffer.toString(), fileName);
  }

  void _pasteSelectedCells() async {
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
          for (
            int c = _selectedRange!.minCol;
            c <= _selectedRange!.maxCol;
            c++
          ) {
            if (c < 1 || c > 12) continue;
            if (r == 1) {
              widget.localDemandEdits.putIfAbsent(
                widget.activity.id,
                () => {},
              )[c] = constrainedVal;
              final controllerKey = 'demand_${widget.activity.id}_${c - 1}';
              final controller = widget.controllersCache[controllerKey];
              if (controller != null) {
                controller.text = constrainedVal == 0
                    ? '0'
                    : constrainedVal
                          .toStringAsFixed(1)
                          .replaceAll(RegExp(r'\.0$'), '');
              }
              updated = true;
            } else if (r >= 2 && r < 2 + widget.employees.length) {
              final emp = widget.employees[r - 2];
              final allocKey = '${emp.email}_${widget.activity.id}';
              widget.localAllocationEdits.putIfAbsent(allocKey, () => {})[c] =
                  constrainedVal;
              final controllerKey = '${allocKey}_${c - 1}';
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
        }
        if (updated) {
          setState(() {});
        }
      }
    } else {
      bool updated = false;
      for (int i = 0; i < parsedGrid.length; i++) {
        final r = _selectedRange!.minRow + i;
        if (r >= 2 + widget.employees.length) break;

        for (int j = 0; j < parsedGrid[i].length; j++) {
          final c = _selectedRange!.minCol + j;
          if (c < 1 || c > 12) continue;

          final val = double.tryParse(parsedGrid[i][j]) ?? 0.0;
          final constrainedVal = val.clamp(0.0, 9999.0);

          if (r == 1) {
            widget.localDemandEdits.putIfAbsent(
              widget.activity.id,
              () => {},
            )[c] = constrainedVal;
            final controllerKey = 'demand_${widget.activity.id}_${c - 1}';
            final controller = widget.controllersCache[controllerKey];
            if (controller != null) {
              controller.text = constrainedVal == 0
                  ? '0'
                  : constrainedVal
                        .toStringAsFixed(1)
                        .replaceAll(RegExp(r'\.0$'), '');
            }
            updated = true;
          } else if (r >= 2 && r < 2 + widget.employees.length) {
            final emp = widget.employees[r - 2];
            final allocKey = '${emp.email}_${widget.activity.id}';
            widget.localAllocationEdits.putIfAbsent(allocKey, () => {})[c] =
                constrainedVal;
            final controllerKey = '${allocKey}_${c - 1}';
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
      }
      if (updated) {
        setState(() {});
      }
    }
  }

  void _performDragFill() {
    if (_dragFillRange == null || _selectedRange == null) return;
    final sourceRow = _dragFillStart!.row;
    final sourceCol = _dragFillStart!.col;
    if (sourceCol < 1 || sourceCol > 12) return;

    double fillValue = 0.0;
    if (sourceRow == 1) {
      fillValue =
          widget.localDemandEdits[widget.activity.id]?[sourceCol] ?? 0.0;
    } else if (sourceRow >= 2 && sourceRow < 2 + widget.employees.length) {
      final emp = widget.employees[sourceRow - 2];
      final allocKey = '${emp.email}_${widget.activity.id}';
      fillValue = widget.localAllocationEdits[allocKey]?[sourceCol] ?? 0.0;
    }

    bool updated = false;
    for (int r = _dragFillRange!.minRow; r <= _dragFillRange!.maxRow; r++) {
      if (r >= 2 + widget.employees.length) break;
      for (int c = _dragFillRange!.minCol; c <= _dragFillRange!.maxCol; c++) {
        if (c < 1 || c > 12) continue;

        if (r == 1) {
          widget.localDemandEdits.putIfAbsent(widget.activity.id, () => {})[c] =
              fillValue;
          final controllerKey = 'demand_${widget.activity.id}_${c - 1}';
          final controller = widget.controllersCache[controllerKey];
          if (controller != null) {
            controller.text = fillValue == 0
                ? '0'
                : fillValue.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
          }
          updated = true;
        } else {
          final emp = widget.employees[r - 2];
          final allocKey = '${emp.email}_${widget.activity.id}';
          widget.localAllocationEdits.putIfAbsent(allocKey, () => {})[c] =
              fillValue;
          final controllerKey = '${allocKey}_${c - 1}';
          final controller = widget.controllersCache[controllerKey];
          if (controller != null) {
            controller.text = fillValue == 0
                ? '0'
                : fillValue.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
          }
          updated = true;
        }
      }
    }
    if (updated) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncKeys();
    final theme = widget.theme;
    final allocByEmail = {
      for (final a in widget.allocations) a.userEmail.trim().toLowerCase(): a,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final availableWidth =
            totalWidth -
            180.0 -
            1.0; // Subtract employee col width (180) and borders
        final cellWidth = availableWidth / 13;

        final monthHeaderCells = List.generate(12, (index) {
          return _buildInteractiveCell(
            r: 0,
            c: index + 1,
            width: cellWidth,
            child: Center(
              child: Text(
                months[index].substring(0, 3),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            rowKey: 'header',
            height: 48,
          );
        });

        return Focus(
          focusNode: _tableFocusNode,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              final isShortcut =
                  (HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed);
              if (isShortcut && event.logicalKey == LogicalKeyboardKey.keyC) {
                _copySelectedCells();
                return KeyEventResult.handled;
              }
              if (widget.isEditing &&
                  isShortcut &&
                  event.logicalKey == LogicalKeyboardKey.keyV) {
                _pasteSelectedCells();
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
                  final character = _getCharacterFromKey(key, event.character);
                  if (character != null && _isCharacterKey(key, character)) {
                    _startTypingFromType(
                      _selectedRange!.start.row,
                      _selectedRange!.start.col,
                      character,
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
              // Header Row
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: Container(
                  key: rowKeys[0],
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: theme.colorScheme.primary, width: 2.0),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildInteractiveCell(
                        r: 0,
                        c: 0,
                        width: 180,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Employees',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        rowKey: 'header',
                        height: 48,
                      ),
                      ...monthHeaderCells,
                      _buildInteractiveCell(
                        r: 0,
                        c: 13,
                        width: cellWidth,
                        child: Center(
                          child: Text(
                            'Sum',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        rowKey: 'header',
                        height: 48,
                      ),
                    ],
                  ),
                ),
              ),

              // Demand Row (Neutral Background with tertiary highlight)
              _buildActivityRow(
                theme: theme,
                activityId: widget.activity.id,
                rowIndex: 1,
                title: 'Demand',
                cellWidth: cellWidth,
                isEditable: widget.isEditing,
                values: List.generate(12, (index) {
                  final monthIdx = index + 1;
                  return widget.isEditing
                      ? (widget.localDemandEdits[widget
                                .activity
                                .id]?[monthIdx] ??
                            0.0)
                      : _getDemandValue(widget.demand, monthIdx);
                }),
                onChanged: (index, val) {
                  widget.localDemandEdits.putIfAbsent(
                    widget.activity.id,
                    () => {},
                  )[index + 1] = val;
                  widget.onDemandChanged(val);
                  setState(() {});
                },
                rowKey: 'demand_${widget.activity.id}',
                backgroundColor: theme.colorScheme.tertiary,
                textColor: theme.colorScheme.onTertiary,
                isBold: true,
              ),

              // Employee Rows (Transparent background)
              ...List.generate(widget.employees.length, (idx) {
                final emp = widget.employees[idx];
                final allocKey = '${emp.email}_${widget.activity.id}';
                final alloc =
                    allocByEmail[emp.email.trim().toLowerCase()] ??
                    PlanningAllocationModel(
                      id: '${emp.email}_${widget.activity.id}_${widget.selectedYear}',
                      userEmail: emp.email,
                      activityId: widget.activity.id,
                      year: widget.selectedYear,
                      orgUnitId: widget.demand.orgUnitId,
                    );

                return _buildActivityRow(
                  theme: theme,
                  activityId: widget.activity.id,
                  rowIndex: 2 + idx,
                  title: emp.fullName,
                  cellWidth: cellWidth,
                  isEditable: widget.isEditing,
                  values: List.generate(12, (index) {
                    final monthIdx = index + 1;
                    return widget.isEditing
                        ? (widget.localAllocationEdits[allocKey]?[monthIdx] ??
                              0.0)
                        : _getAllocationValue(alloc, monthIdx);
                  }),
                  onChanged: (index, val) {
                    widget.localAllocationEdits.putIfAbsent(
                      allocKey,
                      () => {},
                    )[index + 1] = val;
                    widget.onAllocationChanged(index, val);
                    setState(() {});
                  },
                  rowKey: allocKey,
                  backgroundColor: Colors.transparent,
                  textColor: theme.colorScheme.primary,
                  isBold: false,
                );
              }),

              // Sum (Planned Capacity) Row (Neutral Background with tertiary highlight)
              _buildActivityRow(
                theme: theme,
                activityId: widget.activity.id,
                rowIndex: 2 + widget.employees.length,
                title: 'Planned Capacity',
                cellWidth: cellWidth,
                isEditable: false,
                values: List.generate(12, (index) {
                  final monthIdx = index + 1;
                  double sum = 0.0;
                  for (final emp in widget.employees) {
                    final allocKey = '${emp.email}_${widget.activity.id}';
                    if (widget.isEditing) {
                      sum +=
                          widget.localAllocationEdits[allocKey]?[monthIdx] ??
                          0.0;
                    } else {
                      final alloc =
                          allocByEmail[emp.email.trim().toLowerCase()] ??
                          PlanningAllocationModel(
                            id: '',
                            userEmail: emp.email,
                            activityId: widget.activity.id,
                            year: widget.selectedYear,
                            orgUnitId: widget.demand.orgUnitId,
                          );
                      sum += _getAllocationValue(alloc, monthIdx);
                    }
                  }
                  return sum;
                }),
                onChanged: (_, _) {},
                rowKey: 'sum_${widget.activity.id}',
                backgroundColor: theme.colorScheme.primary,
                textColor: theme.colorScheme.onPrimary,
                isBold: true,
              ),

              // Delta Row (Transparent background)
              _buildActivityRow(
                theme: theme,
                activityId: widget.activity.id,
                rowIndex: 2 + widget.employees.length + 1,
                title: 'Delta',
                tooltipMessage:
                    'Delta = Demand - Planned Capacity (sum of employee allocations for this activity)',
                cellWidth: cellWidth,
                isEditable: false,
                values: List.generate(12, (index) {
                  final monthIdx = index + 1;
                  final dVal = widget.isEditing
                      ? (widget.localDemandEdits[widget
                                .activity
                                .id]?[monthIdx] ??
                            0.0)
                      : _getDemandValue(widget.demand, monthIdx);
                  double sVal = 0.0;
                  for (final emp in widget.employees) {
                    final allocKey = '${emp.email}_${widget.activity.id}';
                    if (widget.isEditing) {
                      sVal +=
                          widget.localAllocationEdits[allocKey]?[monthIdx] ??
                          0.0;
                    } else {
                      final alloc =
                          allocByEmail[emp.email.trim().toLowerCase()] ??
                          PlanningAllocationModel(
                            id: '',
                            userEmail: emp.email,
                            activityId: widget.activity.id,
                            year: widget.selectedYear,
                            orgUnitId: widget.demand.orgUnitId,
                          );
                      sVal += _getAllocationValue(alloc, monthIdx);
                    }
                  }
                  return dVal - sVal;
                }),
                onChanged: (_, _) {},
                rowKey: 'delta_${widget.activity.id}',
                backgroundColor: Colors.transparent,
                textColor: theme.colorScheme.primary,
                isBold: true,
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isCellEditable(int r, int c) {
    if (!widget.isEditing) return false;
    if ((r == 1 || (r >= 2 && r < 2 + widget.employees.length)) &&
        (c >= 1 && c <= 12)) {
      return true;
    }
    return false;
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
    FocusNode? focusNode,
  }) {
    final theme = widget.theme;
    final activityId = widget.activity.id;
    final isSelected =
        _selectedRange != null &&
        _selectedRange!.contains(r, c) &&
        (!widget.isEditing || _isCellEditable(r, c));
    final isDragFill =
        _dragFillRange != null &&
        _dragFillRange!.contains(r, c) &&
        (!widget.isEditing || _isCellEditable(r, c));

    final isHeaderCell = rowKey == 'header';
    final baseColor = isHeaderCell ? Colors.white : (backgroundColor ?? Colors.transparent);
    final displayColor = isSelected
        ? (backgroundColor != null
              ? Color.alphaBlend(
                  theme.colorScheme.primary.withValues(alpha: 0.12),
                  backgroundColor,
                )
              : theme.colorScheme.primaryContainer.withValues(alpha: 0.12))
        : (isDragFill
              ? (backgroundColor != null
                    ? Color.alphaBlend(
                        theme.colorScheme.secondary.withValues(alpha: 0.12),
                        backgroundColor,
                      )
                    : theme.colorScheme.secondaryContainer.withValues(alpha: 0.2))
              : baseColor);

    BoxDecoration cellDeco = BoxDecoration(
      color: displayColor,
      border: Border(
        bottom: isHeaderCell
            ? BorderSide.none
            : BorderSide(color: theme.colorScheme.primary, width: 0.5),
      ),
    );

    if (isDragFill) {
      final borderSide = BorderSide(
        color: theme.colorScheme.secondary,
        width: 1.5,
      );
      final gridBorderSide = BorderSide(
        color: theme.colorScheme.primary,
        width: 0.5,
      );
      cellDeco = cellDeco.copyWith(
        border: Border(
          top: r == _dragFillRange!.minRow ? borderSide : BorderSide.none,
          bottom: r == _dragFillRange!.maxRow ? borderSide : gridBorderSide,
          left: c == _dragFillRange!.minCol ? borderSide : BorderSide.none,
          right: c == _dragFillRange!.maxCol ? borderSide : BorderSide.none,
        ),
      );
    } else if (isSelected) {
      final borderSide = BorderSide(
        color: theme.colorScheme.primary,
        width: 1.5,
      );
      final gridBorderSide = BorderSide(
        color: theme.colorScheme.primary,
        width: 0.5,
      );
      cellDeco = cellDeco.copyWith(
        border: Border(
          top: r == _selectedRange!.minRow ? borderSide : BorderSide.none,
          bottom: r == _selectedRange!.maxRow ? borderSide : gridBorderSide,
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

    if (isBottomRight &&
        widget.isEditing &&
        isCellEditable &&
        c >= 1 &&
        c <= 12) {
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
                setState(() {
                  _isDraggingFill = true;
                  _dragFillStart = CellPosition(r, c);
                  _dragFillRange = CellRange(_dragFillStart!, _dragFillStart!);
                });
              },
              onPointerMove: (event) {
                if (_isDraggingFill && _dragFillStart != null) {
                  final currentCell = _getCellAtGlobalPosition(event.position);
                  if (currentCell != null) {
                    setState(() {
                      final rowDiff = (currentCell.row - _dragFillStart!.row).abs();
                      final colDiff = (currentCell.col - _dragFillStart!.col).abs();
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
              onPointerUp: (event) {
                if (_isDraggingFill) {
                  setState(() {
                    _performDragFill();
                    _isDraggingFill = false;
                    _dragFillRange = null;
                    _dragFillStart = null;
                  });
                }
              },
              onPointerCancel: (event) {
                setState(() {
                  _isDraggingFill = false;
                  _dragFillRange = null;
                  _dragFillStart = null;
                });
              },
              child: MouseRegion(
                key: const Key('drag_fill_handle'),
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
        ],
      );
    }

    final menuKey = '${rowKey}_$c';
    final MenuController controller = _getOrCreateMenuController(menuKey);
    final isRightHalf = c >= 7;

    Widget interactiveChild = cellChild;
    GestureTapDownCallback? onSecondaryTapDown;

    if (c >= 1 && c <= 12) {
      final menuItems = [
        MenuItemButton(
          key: Key('context_menu_copy_${activityId}_${r}_$c'),
          onPressed: _selectedRange != null ? () => _copySelectedCells() : null,
          leadingIcon: const Icon(Icons.copy, size: 18),
          child: const Text('Copy'),
        ),
        MenuItemButton(
          key: Key('context_menu_paste_${activityId}_${r}_$c'),
          onPressed:
              widget.isEditing && isCellEditable && _selectedRange != null
              ? () => _pasteSelectedCells()
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
        controller.open();
      };
    }

    return HoverCell(
      key: (r == 0) ? colKeys[c] : Key('cell_${activityId}_${r}_$c'),
      width: width,
      height: height,
      decoration: cellDeco,
      onTap: () {
        // Consume tap gesture to prevent body's GestureDetector from clearing selection
      },
      onPointerDown: (event) {
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

          widget.onTableTap(widget.activity.id);
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
              final clampedRow = currentCell.row.clamp(
                1,
                1 + widget.employees.length,
              ); // Demand to last employee row
              final clampedCol = currentCell.col.clamp(1, 12);
              currentCell = CellPosition(clampedRow, clampedCol);
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
  }

  Widget _buildActivityRow({
    required ThemeData theme,
    required String activityId,
    required int rowIndex,
    required String title,
    required double cellWidth,
    required bool isEditable,
    required List<double> values,
    required void Function(int, double) onChanged,
    required String rowKey,
    Color? backgroundColor,
    Color? textColor,
    bool isBold = false,
    String? tooltipMessage,
  }) {
    double rowSum = values.fold(0.0, (sum, val) => sum + val);
    final int r = rowIndex;
    final isDark = theme.brightness == Brightness.dark;

    Widget labelWidget;
    if (tooltipMessage != null) {
      labelWidget = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: title,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: textColor,
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
                  color:
                      textColor ??
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
          color: textColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final col0Child = Padding(
      padding: const EdgeInsets.only(left: 12.0),
      child: Align(alignment: Alignment.centerLeft, child: labelWidget),
    );

    return Container(
      key: rowKeys[rowIndex],
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
      ),
      child: Row(
        children: [
          _buildInteractiveCell(
            r: r,
            c: 0,
            width: 180,
            child: col0Child,
            rowKey: rowKey,
            backgroundColor: backgroundColor,
            textColor: textColor,
            isBold: isBold,
          ),
          ...List.generate(12, (index) {
            final double val = values[index];
            final displayVal = val == 0
                ? '0'
                : val.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');

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
                _selectedRange != null &&
                _selectedRange!.start.row == r &&
                _selectedRange!.start.col == (index + 1) &&
                (_cellEditMode == CellEditMode.typingFromType ||
                    _cellEditMode == CellEditMode.typingFromDouble);

            final isDelta = rowKey.startsWith('delta_');
            final errorColor = isDark
                ? const Color(0xFFE57373)
                : const Color(0xFFD32F2F);
            final successColor = isDark
                ? const Color(0xFF81C784)
                : const Color(0xFF2E7D32);

            final cellColor = isDelta
                ? (val < 0 ? errorColor : successColor)
                : (textColor ?? theme.colorScheme.onSurfaceVariant);

            final cellStyle = TextStyle(
              color: cellColor,
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
                        textAlignVertical: TextAlignVertical.center,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        style: cellStyle,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          isDense: true,
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
                  : Center(child: Text(displayVal, style: cellStyle)),
            );

            return _buildInteractiveCell(
              r: r,
              c: index + 1,
              width: cellWidth,
              child: cellChild,
              rowKey: rowKey,
              isCellEditable: isEditable,
              backgroundColor: backgroundColor,
              textColor: textColor,
              isBold: isBold,
              focusNode: isEditable ? cellFocusNode : null,
            );
          }),
          _buildInteractiveCell(
            r: r,
            c: 13,
            width: cellWidth,
            child: Center(
              child: Text(
                rowSum == 0
                    ? '0'
                    : rowSum.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rowKey.startsWith('delta_')
                      ? (rowSum < 0
                            ? (isDark ? const Color(0xFFE57373) : const Color(0xFFD32F2F))
                            : (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32)))
                      : textColor,
                  fontSize: 14,
                ),
              ),
            ),
            rowKey: rowKey,
            backgroundColor: backgroundColor,
            textColor: textColor,
            isBold: true,
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// WIDGET: EMPLOYEE PLANNING TABLE (2D Scroll, Excel capabilities)
// =========================================================================
