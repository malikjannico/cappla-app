// ignore_for_file: unused_element_parameter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cappla/core/theme/theme_extensions.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:uuid/uuid.dart';
import '../../core/providers/providers.dart';
import '../../core/router/router_paths.dart';
import '../../models/org_unit_model.dart';

enum CellEditMode { none, selected, typingFromType, typingFromDouble }

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
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

  late TextEditingController _nameController;
  late TextEditingController _titleController;
  OrgUnitModel? _orgUnit;
  String? _lastLoc;

  bool _isCapacityEditing = false;
  int _currentPage = 1;
  int? _selectedYearFilter;
  bool _tappedInteractive = false;
  List<UserCapacityModel> _editableCapacities = [];
  final List<String> _deletedCapacityIds = [];
  final Map<String, TextEditingController> _capacityControllers = {};
  final Map<String, FocusNode> _capacityFocusNodes = {};
  String? _capacityError;
  DateTime? _lastPeriodCellClickTime;
  int? _lastPeriodCellClickIndex;

  // Excel Grid State fields
  late final FocusNode _tableFocusNode;
  _CellRange? _selectedRange;
  _CellPosition? _selectionStart;
  bool _isDraggingSelection = false;

  _CellRange? _dragFillRange;
  _CellPosition? _dragFillStart;
  bool _isDraggingFill = false;
  CellEditMode _cellEditMode = CellEditMode.none;

  List<UserCapacityModel> _currentCapacities = [];
  final Map<int, GlobalKey> _rowKeys = {};
  final Map<int, GlobalKey> _colKeys = {};
  final GlobalKey _headerRowKey = GlobalKey();

  static const List<String> _columnDays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  void initState() {
    super.initState();
    _tableFocusNode = FocusNode();
    final user = ref.read(currentUserProvider);
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _titleController = TextEditingController(text: user?.title ?? '');
    _loadOrgUnit();
  }

  Future<void> _loadOrgUnit() async {
    final user = ref.read(currentUserProvider);
    final orgUnitId = user?.orgUnitId;
    if (orgUnitId != null) {
      try {
        final org = await ref
            .read(databaseServiceProvider)
            .getOrgUnit(orgUnitId);
        if (mounted) {
          setState(() {
            _orgUnit = org;
          });
        }
      } catch (_) {}
    } else {
      if (mounted) {
        setState(() {
          _orgUnit = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _tableFocusNode.dispose();
    _nameController.dispose();
    _titleController.dispose();
    for (final controller in _capacityControllers.values) {
      controller.dispose();
    }
    for (final node in _capacityFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  String _formatTimePeriod(DateTime? start, DateTime? end) {
    if (start == null || end == null) return 'Standard';
    return '${DateFormat('MMMM d yyyy', 'en_US').format(start)} to ${DateFormat('MMMM d yyyy', 'en_US').format(end)}';
  }

  String _formatDoubleValue(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }


  void _initCapacityControllers() {
    _capacityControllers.clear();
    for (final node in _capacityFocusNodes.values) {
      node.dispose();
    }
    _capacityFocusNodes.clear();
    for (final cap in _editableCapacities) {
      _capacityControllers['${cap.id}_monday'] = TextEditingController(
        text: _formatDoubleValue(cap.monday),
      );
      _capacityControllers['${cap.id}_tuesday'] = TextEditingController(
        text: _formatDoubleValue(cap.tuesday),
      );
      _capacityControllers['${cap.id}_wednesday'] = TextEditingController(
        text: _formatDoubleValue(cap.wednesday),
      );
      _capacityControllers['${cap.id}_thursday'] = TextEditingController(
        text: _formatDoubleValue(cap.thursday),
      );
      _capacityControllers['${cap.id}_friday'] = TextEditingController(
        text: _formatDoubleValue(cap.friday),
      );
      _capacityControllers['${cap.id}_saturday'] = TextEditingController(
        text: _formatDoubleValue(cap.saturday),
      );
      _capacityControllers['${cap.id}_sunday'] = TextEditingController(
        text: _formatDoubleValue(cap.sunday),
      );
    }
  }

  double _getDayValue(UserCapacityModel cap, String dayName) {
    switch (dayName) {
      case 'monday':
        return cap.monday;
      case 'tuesday':
        return cap.tuesday;
      case 'wednesday':
        return cap.wednesday;
      case 'thursday':
        return cap.thursday;
      case 'friday':
        return cap.friday;
      case 'saturday':
        return cap.saturday;
      case 'sunday':
        return cap.sunday;
      default:
        return 0.0;
    }
  }

  UserCapacityModel _setDayValue(
    UserCapacityModel cap,
    String dayName,
    double val,
  ) {
    switch (dayName) {
      case 'monday':
        return cap.copyWith(monday: val);
      case 'tuesday':
        return cap.copyWith(tuesday: val);
      case 'wednesday':
        return cap.copyWith(wednesday: val);
      case 'thursday':
        return cap.copyWith(thursday: val);
      case 'friday':
        return cap.copyWith(friday: val);
      case 'saturday':
        return cap.copyWith(saturday: val);
      case 'sunday':
        return cap.copyWith(sunday: val);
      default:
        return cap;
    }
  }

  bool _isCellEditable(int r, int c) {
    if (!_isCapacityEditing) return false;
    if (r <= 0 || r > _currentCapacities.length) return false;
    if (c < 1 || c > 7) return false;
    return true;
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

    if (_isCapacityEditing) {
      final maxRow = _currentCapacities.length;
      r = r.clamp(1, maxRow);
      c = c.clamp(1, 7);
    } else {
      final maxRow = _currentCapacities.length;
      r = r.clamp(0, maxRow);
      c = c.clamp(0, 8);
    }

    setState(() {
      if (isShiftPressed) {
        _selectedRange = _CellRange(_selectionStart!, _CellPosition(r, c));
      } else {
        _selectionStart = _CellPosition(r, c);
        _selectedRange = _CellRange(_selectionStart!, _selectionStart!);
      }
      _cellEditMode = CellEditMode.selected;
    });

    _tableFocusNode.requestFocus();
  }

  TextEditingController _getOrCreateController(
    String key,
    String initialText, {
    bool isEditing = false,
  }) {
    if (!_capacityControllers.containsKey(key)) {
      _capacityControllers[key] = TextEditingController(text: initialText);
    } else {
      final ctrl = _capacityControllers[key]!;
      if (!isEditing) {
        if (ctrl.text != initialText) {
          ctrl.text = initialText;
        }
      }
    }
    return _capacityControllers[key]!;
  }

  FocusNode _getOrCreateFocusNode(String key) {
    if (!_capacityFocusNodes.containsKey(key)) {
      _capacityFocusNodes[key] = FocusNode();
    }
    return _capacityFocusNodes[key]!;
  }

  void _startTypingFromType(int r, int c, String character) {
    setState(() {
      _cellEditMode = CellEditMode.typingFromType;
      _selectionStart = _CellPosition(r, c);
      _selectedRange = _CellRange(_selectionStart!, _selectionStart!);

      final cap = _currentCapacities[r - 1];
      final dayName = _columnDays[c - 1];
      final focusKey = '${cap.id}_$dayName';
      final ctrl = _getOrCreateController(focusKey, character);
      ctrl.text = character;

      final node = _getOrCreateFocusNode(focusKey);
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
    });
  }

  void _startTypingFromDouble(int r, int c) {
    setState(() {
      _cellEditMode = CellEditMode.typingFromDouble;
      _selectionStart = _CellPosition(r, c);
      _selectedRange = _CellRange(_selectionStart!, _selectionStart!);

      final cap = _currentCapacities[r - 1];
      final dayName = _columnDays[c - 1];
      final focusKey = '${cap.id}_$dayName';
      final node = _getOrCreateFocusNode(focusKey);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (node.canRequestFocus) {
          node.requestFocus();
        }
      });
      Future.delayed(Duration.zero, () {
        final ctrl = _capacityControllers[focusKey];
        if (ctrl != null) {
          ctrl.selection = TextSelection(
            baseOffset: 0,
            extentOffset: ctrl.text.length,
          );
        }
      });
    });
  }

  _CellPosition? _getCellAtGlobalPosition(Offset globalPos) {
    int? targetRow;
    int? targetCol;

    int closestRow = 0;
    double minRowDistance = double.infinity;

    final headerBox =
        _headerRowKey.currentContext?.findRenderObject() as RenderBox?;
    if (headerBox != null) {
      final position = headerBox.localToGlobal(Offset.zero);
      final top = position.dy;
      final bottom = position.dy + headerBox.size.height;
      if (globalPos.dy >= top && globalPos.dy <= bottom) {
        targetRow = 0;
      } else {
        final distance = (globalPos.dy - (top + bottom) / 2).abs();
        if (distance < minRowDistance) {
          minRowDistance = distance;
          closestRow = 0;
        }
      }
    }

    if (targetRow == null) {
      for (int r = 0; r < _currentCapacities.length; r++) {
        final key = _rowKeys[r];
        final RenderBox? box =
            key?.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          final position = box.localToGlobal(Offset.zero);
          final top = position.dy;
          final bottom = position.dy + box.size.height;
          if (globalPos.dy >= top && globalPos.dy <= bottom) {
            targetRow = r + 1;
            break;
          }
          final distance = (globalPos.dy - (top + bottom) / 2).abs();
          if (distance < minRowDistance) {
            minRowDistance = distance;
            closestRow = r + 1;
          }
        }
      }
    }

    if (targetRow == null && minRowDistance != double.infinity) {
      targetRow = closestRow;
    }

    int closestCol = 0;
    double minColDistance = double.infinity;
    for (int c = 0; c < 9; c++) {
      final key = _colKeys[c];
      final RenderBox? box =
          key?.currentContext?.findRenderObject() as RenderBox?;
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
    if (targetCol == null && minColDistance != double.infinity) {
      targetCol = closestCol;
    }

    if (targetRow != null && targetCol != null) {
      return _CellPosition(targetRow, targetCol);
    }
    return null;
  }

  void _copySelectedCells() async {
    if (_selectedRange == null) return;

    final buffer = StringBuffer();
    for (int r = _selectedRange!.minRow; r <= _selectedRange!.maxRow; r++) {
      if (r == 0) {
        final rowValues = <String>[];
        for (int c = _selectedRange!.minCol; c <= _selectedRange!.maxCol; c++) {
          if (c == 0) {
            rowValues.add('Period');
          } else if (c >= 1 && c <= 7) {
            rowValues.add(_columnDays[c - 1]);
          } else if (c == 8) {
            rowValues.add('Sum');
          }
        }
        buffer.writeln(rowValues.join('\t'));
        continue;
      }
      if (r - 1 >= _currentCapacities.length) continue;
      final cap = _currentCapacities[r - 1];
      final rowValues = <String>[];
      for (int c = _selectedRange!.minCol; c <= _selectedRange!.maxCol; c++) {
        if (c == 0) {
          rowValues.add(
            cap.type == CapacityType.standard
                ? 'Standard'
                : _formatTimePeriod(cap.startDate, cap.endDate),
          );
        } else if (c >= 1 && c <= 7) {
          final dayName = _columnDays[c - 1];
          final val = _getDayValue(cap, dayName);
          rowValues.add(_formatDoubleValue(val));
        } else if (c == 8) {
          rowValues.add(_formatDoubleValue(cap.sum));
        }
      }
      buffer.writeln(rowValues.join('\t'));
    }

    if (buffer.isNotEmpty) {
      final text = buffer.toString().substring(0, buffer.length - 1);
      Clipboard.setData(ClipboardData(text: text)).catchError((_) {});
    }
  }

  void _pasteSelectedCells() async {
    if (!_isCapacityEditing || _selectedRange == null) return;

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
        final constrainedVal = val.clamp(0.0, 24.0);
        bool updated = false;
        for (int r = _selectedRange!.minRow; r <= _selectedRange!.maxRow; r++) {
          if (r == 0) continue; // Skip header row
          if (r - 1 >= _currentCapacities.length) break;
          final displayedCap = _currentCapacities[r - 1];
          final editIdx = _editableCapacities.indexWhere((c) => c.id == displayedCap.id);
          if (editIdx == -1) continue;
          var cap = _editableCapacities[editIdx];
          for (
            int c = _selectedRange!.minCol;
            c <= _selectedRange!.maxCol;
            c++
          ) {
            if (c == 0 || c >= 8) continue; // Skip Period and Sum
            final dayName = _columnDays[c - 1];
            cap = _setDayValue(cap, dayName, constrainedVal);
            final controllerKey = '${cap.id}_$dayName';
            if (_capacityControllers.containsKey(controllerKey)) {
              _capacityControllers[controllerKey]!.text = _formatDoubleValue(
                constrainedVal,
              );
            }
            updated = true;
          }
          _editableCapacities[editIdx] = cap;
        }
        if (updated) {
          setState(() {});
        }
      }
      return;
    }

    final startRow = _selectedRange!.minRow;
    final startCol = _selectedRange!.minCol;

    bool updated = false;
    for (int i = 0; i < rows.length; i++) {
      final rowText = rows[i].trim();
      if (rowText.isEmpty) continue;

      final targetRow = startRow + i;
      if (targetRow == 0) continue; // Skip header row
      if (targetRow - 1 >= _currentCapacities.length) break;
      final displayedCap = _currentCapacities[targetRow - 1];
      final editIdx = _editableCapacities.indexWhere((c) => c.id == displayedCap.id);
      if (editIdx == -1) continue;

      final cells = rowText.split('\t');
      var cap = _editableCapacities[editIdx];

      for (int j = 0; j < cells.length; j++) {
        final targetCol = startCol + j;
        if (targetCol > 8) break;

        // Column 0 is Period (read-only)
        if (targetCol == 0) continue;

        // Columns 1..7 are Mon..Sun
        if (targetCol >= 1 && targetCol <= 7) {
          final val = double.tryParse(cells[j]);
          if (val != null) {
            final constrainedVal = val.clamp(0.0, 24.0);
            final dayName = _columnDays[targetCol - 1];
            cap = _setDayValue(cap, dayName, constrainedVal);

            final controllerKey = '${cap.id}_$dayName';
            if (_capacityControllers.containsKey(controllerKey)) {
              _capacityControllers[controllerKey]!.text = _formatDoubleValue(
                constrainedVal,
              );
            }
            updated = true;
          }
        }
      }
      _editableCapacities[editIdx] = cap;
    }

    if (updated) {
      setState(() {});
    }
  }

  void _performDragFill() {
    if (!_isCapacityEditing ||
        _selectedRange == null ||
        _dragFillRange == null ||
        _dragFillStart == null) {
      return;
    }

    final sourceRow = _dragFillStart!.row;
    final sourceCol = _dragFillStart!.col;

    bool updated = false;
    for (int r = _dragFillRange!.minRow; r <= _dragFillRange!.maxRow; r++) {
      if (r == 0) continue; // Skip header row
      if (r - 1 >= _currentCapacities.length) break;
      final displayedCap = _currentCapacities[r - 1];
      final targetIdx = _editableCapacities.indexWhere((c) => c.id == displayedCap.id);
      if (targetIdx == -1) continue;
      var cap = _editableCapacities[targetIdx];

      for (int c = _dragFillRange!.minCol; c <= _dragFillRange!.maxCol; c++) {
        if (c == 0 || c >= 8) continue; // Skip Period and Sum

        int srcR = sourceRow;
        int srcC = sourceCol;

        if (_dragFillRange!.minRow == _dragFillRange!.maxRow) {
          srcR = r;
          srcC = sourceCol;
        } else {
          srcR = sourceRow;
          srcC = c;
        }

        if (srcR == 0) continue; // Skip header row as source
        if (srcC == 0 || srcC >= 8) continue; // Skip Period and Sum for source
        if (srcR - 1 >= _currentCapacities.length) continue;

        final sourceDisplayedCap = _currentCapacities[srcR - 1];
        final srcIdx = _editableCapacities.indexWhere((c) => c.id == sourceDisplayedCap.id);
        if (srcIdx == -1) continue;
        final sourceCap = _editableCapacities[srcIdx];

        final dayName = _columnDays[srcC - 1];
        final sourceVal = _getDayValue(sourceCap, dayName);

        final targetDayName = _columnDays[c - 1];
        cap = _setDayValue(cap, targetDayName, sourceVal);

        final controllerKey = '${cap.id}_$targetDayName';
        if (_capacityControllers.containsKey(controllerKey)) {
          _capacityControllers[controllerKey]!.text = _formatDoubleValue(
            sourceVal,
          );
        }
        updated = true;
      }
      _editableCapacities[targetIdx] = cap;
    }

    if (updated) {
      setState(() {});
    }
  }

  Future<bool> _saveCapacityEdits(String userEmail) async {
    final specificRows = _editableCapacities
        .where((c) => c.type == CapacityType.specific)
        .toList();
    for (int i = 0; i < specificRows.length; i++) {
      final s1 = specificRows[i].startDate;
      final e1 = specificRows[i].endDate;
      if (s1 == null || e1 == null) {
        setState(() {
          _capacityError =
              'All specific capacity periods must have start and end dates.';
        });
        return false;
      }
      if (e1.isBefore(s1)) {
        setState(() {
          _capacityError = 'End date cannot be before start date.';
        });
        return false;
      }
      for (int j = i + 1; j < specificRows.length; j++) {
        final s2 = specificRows[j].startDate;
        final e2 = specificRows[j].endDate;
        if (s2 == null || e2 == null) continue;

        final normS1 = DateTime(s1.year, s1.month, s1.day);
        final normE1 = DateTime(e1.year, e1.month, e1.day);
        final normS2 = DateTime(s2.year, s2.month, s2.day);
        final normE2 = DateTime(e2.year, e2.month, e2.day);

        if (!normS1.isAfter(normE2) && !normS2.isAfter(normE1)) {
          setState(() {
            _capacityError =
                'Overlap detected between specific capacity periods.';
          });
          return false;
        }
      }
    }

    try {
      final db = ref.read(databaseServiceProvider);

      for (final id in _deletedCapacityIds) {
        await db.deleteUserCapacity(id);
      }
      _deletedCapacityIds.clear();

      for (final cap in _editableCapacities) {
        final updatedCap = cap.copyWith(
          lastModifiedBy: userEmail,
          lastModifiedAt: DateTime.now(),
        );
        await db.saveUserCapacity(updatedCap);
      }
      return true;
    } catch (e) {
      setState(() {
        _capacityError = 'Error saving capacities: $e';
      });
      return false;
    }
  }

  void _showTimePeriodModal(
    BuildContext context,
    String userEmail, {
    int? editIndex,
  }) {
    final isEditingRow = editIndex != null;
    final initialCap = isEditingRow ? _currentCapacities[editIndex] : null;

    DateTime? validityStart = initialCap?.startDate ?? DateTime.now();
    DateTime? validityEnd =
        initialCap?.endDate ?? DateTime.now().add(const Duration(days: 30));

    final startDateController = TextEditingController(
      text: validityStart.toLocal().toString().split(' ')[0],
    );
    final endDateController = TextEditingController(
      text: validityEnd.toLocal().toString().split(' ')[0],
    );

    String? modalError;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: const Text('Select a Time Period'),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      key: const Key('capacity_modal_start_date_input'),
                      controller: startDateController,
                      readOnly: false,
                      decoration: InputDecoration(
                        labelText: 'Start Date',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: validityStart ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setModalState(() {
                                validityStart = picked;
                                startDateController.text = picked
                                    .toLocal()
                                    .toString()
                                    .split(' ')[0];
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('capacity_modal_end_date_input'),
                      controller: endDateController,
                      readOnly: false,
                      decoration: InputDecoration(
                        labelText: 'End Date',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  validityEnd ??
                                  DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setModalState(() {
                                validityEnd = picked;
                                endDateController.text = picked
                                    .toLocal()
                                    .toString()
                                    .split(' ')[0];
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    if (modalError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        modalError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  key: const Key('capacity_modal_cancel_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('capacity_modal_save_button'),
                  onPressed: () async {
                    if (startDateController.text.isNotEmpty) {
                      final parsed = DateTime.tryParse(
                        startDateController.text,
                      );
                      if (parsed != null) {
                        validityStart = parsed;
                      }
                    }
                    if (endDateController.text.isNotEmpty) {
                      final parsed = DateTime.tryParse(endDateController.text);
                      if (parsed != null) {
                        validityEnd = parsed;
                      }
                    }
                    if (validityStart == null || validityEnd == null) {
                      setModalState(() {
                        modalError = 'Please select both start and end dates.';
                      });
                      return;
                    }
                    if (validityEnd!.isBefore(validityStart!)) {
                      setModalState(() {
                        modalError = 'End date cannot be before start date.';
                      });
                      return;
                    }

                    final s1 = DateTime(
                      validityStart!.year,
                      validityStart!.month,
                      validityStart!.day,
                    );
                    final e1 = DateTime(
                      validityEnd!.year,
                      validityEnd!.month,
                      validityEnd!.day,
                    );

                    bool hasOverlap = false;

                    final checkList = _isCapacityEditing
                        ? _editableCapacities
                        : (ref.read(userCapacitiesStreamProvider(userEmail)).value ?? []);

                    for (final other in checkList) {
                      if (initialCap != null && other.id == initialCap.id) continue;
                      if (other.type != CapacityType.specific) continue;
                      final s2 = DateTime(
                        other.startDate!.year,
                        other.startDate!.month,
                        other.startDate!.day,
                      );
                      final e2 = DateTime(
                        other.endDate!.year,
                        other.endDate!.month,
                        other.endDate!.day,
                      );
                      if (!s1.isAfter(e2) && !s2.isAfter(e1)) {
                        hasOverlap = true;
                        break;
                      }
                    }

                    if (hasOverlap) {
                      setModalState(() {
                        modalError =
                            'Overlap detected with an existing capacity period.';
                      });
                      return;
                    }

                    if (isEditingRow) {
                      final editIdxInEditable = _editableCapacities.indexWhere((c) => c.id == initialCap!.id);
                      if (editIdxInEditable != -1) {
                        setState(() {
                          _editableCapacities[editIdxInEditable] =
                              _editableCapacities[editIdxInEditable].copyWith(
                                startDate: () => s1,
                                endDate: () => e1,
                              );
                        });
                      }
                    } else {
                      final id = const Uuid().v4();
                      final now = DateTime.now();

                      final newCap = UserCapacityModel(
                        id: id,
                        userEmail: userEmail,
                        type: 'Specific',
                        startDate: s1,
                        endDate: e1,
                        monday: 8.0,
                        tuesday: 8.0,
                        wednesday: 8.0,
                        thursday: 8.0,
                        friday: 8.0,
                        saturday: 0.0,
                        sunday: 0.0,
                        createdBy: userEmail,
                        createdAt: now,
                        lastModifiedBy: userEmail,
                        lastModifiedAt: now,
                      );

                      final db = ref.read(databaseServiceProvider);
                      await db.saveUserCapacity(newCap);
                    }

                    if (context.mounted) {
                      Navigator.of(context).pop();
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

  Widget _buildPeriodCell(UserCapacityModel cap, int idx, double cellWidth) {
    final theme = Theme.of(context);
    final r = idx + 1;
    final c = 0;

    BoxDecoration? cellDeco;
    final isSelected =
        _selectedRange != null &&
        _selectedRange!.contains(r, c) &&
        (!_isCapacityEditing || _isCellEditable(r, c));
    final isDragFill =
        _dragFillRange != null &&
        _dragFillRange!.contains(r, c) &&
        (!_isCapacityEditing || _isCellEditable(r, c));

    if (isSelected) {
      final borderSide = BorderSide(
        color: theme.colorScheme.primary,
        width: 1.5,
      );
      final gridBorderSide = BorderSide(
        color: theme.colorScheme.primary,
        width: 0.5,
      );
      cellDeco = BoxDecoration(
        color: Color.alphaBlend(
          theme.colorScheme.primary.withValues(alpha: 0.12),
          Colors.transparent,
        ),
        border: Border(
          top: r == _selectedRange!.minRow ? borderSide : BorderSide.none,
          bottom: r == _selectedRange!.maxRow ? borderSide : gridBorderSide,
          left: c == _selectedRange!.minCol ? borderSide : BorderSide.none,
          right: c == _selectedRange!.maxCol ? borderSide : BorderSide.none,
        ),
      );
    } else if (isDragFill) {
      final borderSide = BorderSide(
        color: theme.colorScheme.secondary,
        width: 1.5,
      );
      final gridBorderSide = BorderSide(
        color: theme.colorScheme.primary,
        width: 0.5,
      );
      cellDeco = BoxDecoration(
        color: Color.alphaBlend(
          theme.colorScheme.secondary.withValues(alpha: 0.12),
          Colors.transparent,
        ),
        border: Border(
          top: r == _dragFillRange!.minRow ? borderSide : BorderSide.none,
          bottom: r == _dragFillRange!.maxRow ? borderSide : gridBorderSide,
          left: c == _dragFillRange!.minCol ? borderSide : BorderSide.none,
          right: c == _dragFillRange!.maxCol ? borderSide : BorderSide.none,
        ),
      );
    }
final periodText = _formatTimePeriod(cap.startDate, cap.endDate);
final Widget cellChild = Text(
  periodText,
  key: Key('capacity_period_text_${cap.id}'),
  textAlign: TextAlign.start,
  style: TextStyle(
    color: theme.colorScheme.primary,
    fontWeight: cap.type == CapacityType.standard ? FontWeight.bold : FontWeight.normal,
  ),
);

    final MenuController controller = _getOrCreateMenuController('${cap.id}_period');

    final menuItems = [
      MenuItemButton(
        key: const Key('context_menu_copy'),
        onPressed: _selectedRange != null ? _copySelectedCells : null,
        leadingIcon: const Icon(Icons.copy, size: 18),
        child: const Text('Copy'),
      ),
      MenuItemButton(
        key: const Key('context_menu_paste'),
        onPressed: _isCapacityEditing && _selectedRange != null
            ? _pasteSelectedCells
            : null,
        leadingIcon: const Icon(Icons.paste, size: 18),
        child: const Text('Paste'),
      ),
    ];

    return _HoverCell(
      key: Key('capacity_period_cell_${cap.id}'),
      width: cellWidth,
      height: 48,
      decoration: cellDeco,
      tooltip: null,
      onTap: null,
      onPointerDown: (event) {
        if (event.buttons != 1) return;
        if (_isDraggingFill) return;

        final now = DateTime.now();
        if (_lastPeriodCellClickTime != null &&
            now.difference(_lastPeriodCellClickTime!) <
                const Duration(milliseconds: 300) &&
            _lastPeriodCellClickIndex == idx) {
          if (_isCapacityEditing && cap.type != 'Standard') {
            _showTimePeriodModal(
              context,
              ref.read(currentUserProvider)!.email,
              editIndex: idx,
            );
          }
        }
        _lastPeriodCellClickTime = now;
        _lastPeriodCellClickIndex = idx;

        if (_isCapacityEditing) return; // Not selectable in edit mode
        _tableFocusNode.requestFocus();

        setState(() {
          _selectionStart = _CellPosition(r, c);
          _selectedRange = _CellRange(_selectionStart!, _selectionStart!);
          _dragFillRange = null;
          _isDraggingSelection = true;
        });
      },
      onPointerMove: (event) {
        if (_isDraggingSelection && _selectionStart != null) {
          var currentCell = _getCellAtGlobalPosition(event.position);
          if (currentCell != null && currentCell != _selectedRange?.end) {
            if (_isCapacityEditing) {
              final clampedRow = currentCell.row.clamp(
                1,
                _currentCapacities.length,
              );
              final clampedCol = currentCell.col.clamp(1, 7);
              currentCell = _CellPosition(clampedRow, clampedCol);
            }
            setState(() {
              _selectedRange = _CellRange(_selectionStart!, currentCell!);
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
      onSecondaryTapDown: (details) {
        if (_isCapacityEditing) return;
        final currentCell = _getCellAtGlobalPosition(details.globalPosition);
        if (currentCell != null) {
          if (_selectedRange == null ||
              !_selectedRange!.contains(currentCell.row, currentCell.col)) {
            setState(() {
              _selectionStart = currentCell;
              _selectedRange = _CellRange(_selectionStart!, _selectionStart!);
            });
          }
        }
        controller.open();
      },
      child: Directionality(
        textDirection: TextDirection.ltr,
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
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Align(alignment: Alignment.centerLeft, child: cellChild),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayCell(
    UserCapacityModel cap,
    int idx,
    String dayName,
    double Function() getter,
    void Function(double) setter,
    double cellWidth,
  ) {
    final theme = Theme.of(context);
    final valStr = _formatDoubleValue(getter());
    final r = idx + 1;
    final c = _columnDays.indexOf(dayName) + 1;

    BoxDecoration? cellDeco;
    final isSelected =
        _selectedRange != null &&
        _selectedRange!.contains(r, c) &&
        (!_isCapacityEditing || _isCellEditable(r, c));
    final isDragFill =
        _dragFillRange != null &&
        _dragFillRange!.contains(r, c) &&
        (!_isCapacityEditing || _isCellEditable(r, c));

    if (isSelected) {
      final borderSide = BorderSide(
        color: theme.colorScheme.primary,
        width: 1.5,
      );
      final gridBorderSide = BorderSide(
        color: theme.colorScheme.primary,
        width: 0.5,
      );
      cellDeco = BoxDecoration(
        color: Color.alphaBlend(
          theme.colorScheme.primary.withValues(alpha: 0.12),
          Colors.transparent,
        ),
        border: Border(
          top: r == _selectedRange!.minRow ? borderSide : BorderSide.none,
          bottom: r == _selectedRange!.maxRow ? borderSide : gridBorderSide,
          left: c == _selectedRange!.minCol ? borderSide : BorderSide.none,
          right: c == _selectedRange!.maxCol ? borderSide : BorderSide.none,
        ),
      );
    } else if (isDragFill) {
      final borderSide = BorderSide(
        color: theme.colorScheme.secondary,
        width: 1.5,
      );
      final gridBorderSide = BorderSide(
        color: theme.colorScheme.primary,
        width: 0.5,
      );
      cellDeco = BoxDecoration(
        color: Color.alphaBlend(
          theme.colorScheme.secondary.withValues(alpha: 0.12),
          Colors.transparent,
        ),
        border: Border(
          top: r == _dragFillRange!.minRow ? borderSide : BorderSide.none,
          bottom: r == _dragFillRange!.maxRow ? borderSide : gridBorderSide,
          left: c == _dragFillRange!.minCol ? borderSide : BorderSide.none,
          right: c == _dragFillRange!.maxCol ? gridBorderSide : BorderSide.none,
        ),
      );
    }

    final isCellEditing =
        _isCapacityEditing &&
        _isCellEditable(r, c) &&
        _selectedRange != null &&
        _selectedRange!.start.row == r &&
        _selectedRange!.start.col == c &&
        (_cellEditMode == CellEditMode.typingFromType ||
            _cellEditMode == CellEditMode.typingFromDouble);
final cellStyle = theme.textTheme.bodyMedium?.copyWith(
  color: theme.colorScheme.primary,
  fontSize: 14,
);

    final focusNode = (_isCapacityEditing && _isCellEditable(r, c))
        ? _getOrCreateFocusNode('${cap.id}_$dayName')
        : null;

    if (focusNode != null) {
      focusNode.onKeyEvent = (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter) {
            if (_cellEditMode == CellEditMode.typingFromType ||
                _cellEditMode == CellEditMode.typingFromDouble) {
              final ctrl = _capacityControllers['${cap.id}_$dayName'];
              if (ctrl != null) {
                final parsed = double.tryParse(ctrl.text) ?? 0.0;
                setter(parsed);
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
    }

    Widget cellChild;
    if (isCellEditing) {
      final focusKey = '${cap.id}_$dayName';
      final controller = _getOrCreateController(
        focusKey,
        valStr,
        isEditing: isCellEditing,
      );
      cellChild = Container(
        color: Colors.transparent,
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: TextField(
            key: Key('capacity_input_${cap.id}_$dayName'),
            controller: controller,
            focusNode: focusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            expands: true,
            maxLines: null,
            minLines: null,
            style: cellStyle,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onTap: () {
              if (_cellEditMode != CellEditMode.typingFromDouble) {
                controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: controller.text.length,
                );
              }
            },
            onChanged: (val) {
              final parsed = double.tryParse(val) ?? 0.0;
              setter(parsed);
              setState(() {});
            },
            onSubmitted: (val) {
              final parsed = double.tryParse(val) ?? 0.0;
              setter(parsed);
              setState(() {
                _cellEditMode = CellEditMode.selected;
              });
              _tableFocusNode.requestFocus();
            },
          ),
        ),
      );
    } else {
      cellChild = Container(
        color: Colors.transparent,
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Text(
            valStr,
            key: Key('capacity_${dayName}_text_${cap.id}'),
            textAlign: TextAlign.center,
            style: cellStyle,
          ),
        ),
      );
    }

    final isBottomRight =
        _selectedRange != null &&
        r == _selectedRange!.maxRow &&
        c == _selectedRange!.maxCol;

    if (isBottomRight &&
        _isCapacityEditing &&
        _isCellEditable(r, c) &&
        c >= 1 &&
        c <= 7) {
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
                  _dragFillStart = _CellPosition(r, c);
                  _dragFillRange = _CellRange(_dragFillStart!, _dragFillStart!);
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
                        _dragFillRange = _CellRange(
                          _dragFillStart!,
                          _CellPosition(currentCell.row, _dragFillStart!.col),
                        );
                      } else {
                        _dragFillRange = _CellRange(
                          _dragFillStart!,
                          _CellPosition(_dragFillStart!.row, currentCell.col),
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

    final menuKey = '${cap.id}_$dayName';
    final MenuController controller = _getOrCreateMenuController(menuKey);
    final isRightHalf = c >= 4;

    final menuItems = [
      MenuItemButton(
        key: Key('context_menu_copy_${cap.id}_${r}_$c'),
        onPressed: _selectedRange != null ? _copySelectedCells : null,
        leadingIcon: const Icon(Icons.copy, size: 18),
        child: const Text('Copy'),
      ),
      MenuItemButton(
        key: Key('context_menu_paste_${cap.id}_${r}_$c'),
        onPressed:
            _isCapacityEditing &&
                _isCellEditable(r, c) &&
                _selectedRange != null
            ? _pasteSelectedCells
            : null,
        leadingIcon: const Icon(Icons.paste, size: 18),
        child: const Text('Paste'),
      ),
    ];

    return _HoverCell(
      key: Key('capacity_${dayName}_cell_${cap.id}'),
      width: cellWidth,
      height: 48,
      decoration: cellDeco,
      tooltip: null,
      onTap: null,
      onDoubleTap: (_isCapacityEditing && _isCellEditable(r, c))
          ? () => _startTypingFromDouble(r, c)
          : null,
      onPointerDown: (event) {
        if (event.buttons != 1) return;
        if (_isDraggingFill) return;
        if (_isCapacityEditing && !_isCellEditable(r, c)) return;

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
        }

        setState(() {
          _selectionStart = _CellPosition(r, c);
          _isDraggingSelection = true;
          _dragFillRange = null;
          if (!isCurrentEditing) {
            _selectedRange = _CellRange(_selectionStart!, _selectionStart!);
            _cellEditMode = CellEditMode.selected;
          }
        });
      },
      onPointerMove: (event) {
        if (_isDraggingSelection && _selectionStart != null) {
          var currentCell = _getCellAtGlobalPosition(event.position);
          if (currentCell != null && currentCell != _selectedRange?.end) {
            if (_isCapacityEditing) {
              final clampedRow = currentCell.row.clamp(
                1,
                _currentCapacities.length,
              );
              final clampedCol = currentCell.col.clamp(1, 7);
              currentCell = _CellPosition(clampedRow, clampedCol);
            }
            setState(() {
              _selectedRange = _CellRange(_selectionStart!, currentCell!);
              if (_selectedRange!.start != _selectedRange!.end) {
                _cellEditMode = CellEditMode.selected;
                _tableFocusNode.requestFocus();
              }
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
      onSecondaryTapDown: (details) {
        if (_isCapacityEditing && !_isCellEditable(r, c)) return;
        final currentCell = _getCellAtGlobalPosition(details.globalPosition);
        if (currentCell != null) {
          if (_selectedRange == null ||
              !_selectedRange!.contains(currentCell.row, currentCell.col)) {
            setState(() {
              _selectionStart = currentCell;
              _selectedRange = _CellRange(_selectionStart!, _selectionStart!);
            });
          }
        }
        controller.open();
      },
      child: Directionality(
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
      ),
    );
  }

  Widget _buildHeaderCell({
    required int c,
    required double width,
    required Widget child,
    required GlobalKey key,
    Alignment alignment = Alignment.center,
  }) {
    final theme = Theme.of(context);
    final isSelected =
        _selectedRange != null &&
        _selectedRange!.contains(0, c) &&
        !_isCapacityEditing;
    final isDragFill =
        _dragFillRange != null &&
        _dragFillRange!.contains(0, c) &&
        !_isCapacityEditing;
BoxDecoration? cellDeco;
if (isSelected) {
  final borderSide = BorderSide(
    color: theme.colorScheme.primary,
    width: 1.5,
  );
  final gridBorderSide = BorderSide(
    color: theme.colorScheme.primary,
    width: 0.5,
  );
  cellDeco = BoxDecoration(
    color: Color.alphaBlend(
      theme.colorScheme.primary.withValues(alpha: 0.12),
      Colors.white,
    ),
    border: Border(
      top: borderSide,
      bottom: 0 == _selectedRange!.maxRow ? borderSide : gridBorderSide,
      left: c == _selectedRange!.minCol ? borderSide : BorderSide.none,
      right: c == _selectedRange!.maxCol ? borderSide : BorderSide.none,
    ),
  );
} else if (isDragFill) {
  final borderSide = BorderSide(
    color: theme.colorScheme.secondary,
    width: 1.5,
  );
  final gridBorderSide = BorderSide(
    color: theme.colorScheme.primary,
    width: 0.5,
  );
  cellDeco = BoxDecoration(
    color: Color.alphaBlend(
      theme.colorScheme.secondary.withValues(alpha: 0.12),
      Colors.white,
    ),
    border: Border(
      top: borderSide,
      bottom: 0 == _dragFillRange!.maxRow ? borderSide : gridBorderSide,
      left: c == _dragFillRange!.minCol ? borderSide : BorderSide.none,
      right: c == _dragFillRange!.maxCol ? borderSide : BorderSide.none,
    ),
  );
} else {
  cellDeco = const BoxDecoration(color: Colors.white);
}

    final controller = _getOrCreateMenuController('header_$c');
    final isRightHalf = c >= 4;

    final menuItems = [
      MenuItemButton(
        key: const Key('context_menu_copy'),
        onPressed: _selectedRange != null ? _copySelectedCells : null,
        leadingIcon: const Icon(Icons.copy, size: 18),
        child: const Text('Copy'),
      ),
    ];

    return _HoverCell(
      key: key,
      width: width,
      height: 48,
      decoration: cellDeco,
      onPointerDown: (event) {
        if (event.buttons != 1) return;
        if (_isCapacityEditing) return; // Header not selectable in edit mode
        _tableFocusNode.requestFocus();
        setState(() {
          _selectionStart = _CellPosition(0, c);
          _selectedRange = _CellRange(_selectionStart!, _selectionStart!);
          _dragFillRange = null;
          _isDraggingSelection = true;
        });
      },
      onPointerMove: (event) {
        if (_isDraggingSelection && _selectionStart != null) {
          var currentCell = _getCellAtGlobalPosition(event.position);
          if (currentCell != null && currentCell != _selectedRange?.end) {
            setState(() {
              _selectedRange = _CellRange(_selectionStart!, currentCell);
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
      onSecondaryTapDown: (details) {
        if (_isCapacityEditing) return;
        final currentCell = _getCellAtGlobalPosition(details.globalPosition);
        if (currentCell != null) {
          if (_selectedRange == null ||
              !_selectedRange!.contains(currentCell.row, currentCell.col)) {
            setState(() {
              _selectionStart = currentCell;
              _selectedRange = _CellRange(_selectionStart!, _selectionStart!);
            });
          }
        }
        controller.open();
      },
      child: Directionality(
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
            child: Align(alignment: alignment, child: child),
          ),
        ),
      ),
    );
  }

  Widget _buildSumCell(UserCapacityModel cap, int idx, double cellWidth) {
    final theme = Theme.of(context);
    final sumStr = _formatDoubleValue(cap.sum);
    final r = idx + 1;
    final c = 8;

    BoxDecoration? cellDeco;
    final isSelected =
        _selectedRange != null &&
        _selectedRange!.contains(r, c) &&
        (!_isCapacityEditing || _isCellEditable(r, c));
    final isDragFill =
        _dragFillRange != null &&
        _dragFillRange!.contains(r, c) &&
        (!_isCapacityEditing || _isCellEditable(r, c));

    if (isSelected) {
      final borderSide = BorderSide(
        color: theme.colorScheme.primary,
        width: 1.5,
      );
      final gridBorderSide = BorderSide(
        color: theme.colorScheme.primary,
        width: 0.5,
      );
      cellDeco = BoxDecoration(
        color: Color.alphaBlend(
          theme.colorScheme.primary.withValues(alpha: 0.12),
          Colors.transparent,
        ),
        border: Border(
          top: r == _selectedRange!.minRow ? borderSide : BorderSide.none,
          bottom: r == _selectedRange!.maxRow ? borderSide : gridBorderSide,
          left: c == _selectedRange!.minCol ? borderSide : BorderSide.none,
          right: c == _selectedRange!.maxCol ? borderSide : BorderSide.none,
        ),
      );
    } else if (isDragFill) {
      final borderSide = BorderSide(
        color: theme.colorScheme.secondary,
        width: 1.5,
      );
      final gridBorderSide = BorderSide(
        color: theme.colorScheme.primary,
        width: 0.5,
      );
      cellDeco = BoxDecoration(
        color: Color.alphaBlend(
          theme.colorScheme.secondary.withValues(alpha: 0.12),
          Colors.transparent,
        ),
        border: Border(
          top: r == _dragFillRange!.minRow ? borderSide : BorderSide.none,
          bottom: r == _dragFillRange!.maxRow ? borderSide : gridBorderSide,
          left: c == _dragFillRange!.minCol ? borderSide : BorderSide.none,
          right: c == _dragFillRange!.maxCol ? borderSide : BorderSide.none,
        ),
      );
    }
final Widget sumChild = Center(
  child: Text(
    sumStr,
    key: Key('capacity_sum_${cap.id}'),
    textAlign: TextAlign.center,
    style: TextStyle(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.primary,
    ),
  ),
);

    final controller = _getOrCreateMenuController('${cap.id}_sum');

    final menuItems = [
      MenuItemButton(
        key: const Key('context_menu_copy'),
        onPressed: _selectedRange != null ? _copySelectedCells : null,
        leadingIcon: const Icon(Icons.copy, size: 18),
        child: const Text('Copy'),
      ),
      MenuItemButton(
        key: const Key('context_menu_paste'),
        onPressed:
            _isCapacityEditing &&
                _isCellEditable(r, c) &&
                _selectedRange != null
            ? _pasteSelectedCells
            : null,
        leadingIcon: const Icon(Icons.paste, size: 18),
        child: const Text('Paste'),
      ),
    ];

    return _HoverCell(
      key: Key('capacity_sum_cell_${cap.id}'),
      width: cellWidth,
      height: 48,
      decoration: cellDeco,
      tooltip: null,
      onTap: null,
      onPointerDown: (event) {
        if (event.buttons != 1) return;
        if (_isDraggingFill) return;
        if (_isCapacityEditing) return; // Not selectable in edit mode
        _tableFocusNode.requestFocus();
        setState(() {
          _selectionStart = _CellPosition(r, c);
          _selectedRange = _CellRange(_selectionStart!, _selectionStart!);
          _dragFillRange = null;
          _isDraggingSelection = true;
        });
      },
      onPointerMove: (event) {
        if (_isDraggingSelection && _selectionStart != null) {
          var currentCell = _getCellAtGlobalPosition(event.position);
          if (currentCell != null && currentCell != _selectedRange?.end) {
            if (_isCapacityEditing) {
              final clampedRow = currentCell.row.clamp(
                1,
                _currentCapacities.length,
              );
              final clampedCol = currentCell.col.clamp(1, 7);
              currentCell = _CellPosition(clampedRow, clampedCol);
            }
            setState(() {
              _selectedRange = _CellRange(_selectionStart!, currentCell!);
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
      onSecondaryTapDown: (details) {
        if (_isCapacityEditing) return;
        final currentCell = _getCellAtGlobalPosition(details.globalPosition);
        if (currentCell != null) {
          if (_selectedRange == null ||
              !_selectedRange!.contains(currentCell.row, currentCell.col)) {
            setState(() {
              _selectionStart = currentCell;
              _selectedRange = _CellRange(_selectionStart!, _selectionStart!);
            });
          }
        }
        controller.open();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
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
            child: sumChild,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final loc = GoRouterState.of(context).matchedLocation;
    final isEditing = loc == RouterPaths.profileEdit;

    if (loc != _lastLoc) {
      _lastLoc = loc;
      if (isEditing) {
        _nameController.text = user?.fullName ?? '';
        _titleController.text = user?.title ?? '';
      }
    }

    // Listen to changes in the current user to reload their associated org unit.
    ref.listen<UserModel?>(currentUserProvider, (previous, next) {
      _loadOrgUnit();
    });

    final isOrgInactive = _orgUnit != null && _orgUnit!.status == 'Inactive';



    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (event.buttons != 1) return;
          if (_tappedInteractive) {
            _tappedInteractive = false;
            return;
          }
          if (_selectedRange != null ||
              _isDraggingSelection ||
              _isDraggingFill) {
            setState(() {
              _selectedRange = null;
              _isDraggingSelection = false;
              _isDraggingFill = false;
              _dragFillRange = null;
              _dragFillStart = null;
            });
          }
        },
        child: SingleChildScrollView(
          physics: _isDraggingFill || _isDraggingSelection
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Align(
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Listener(
                  onPointerDown: (_) => _tappedInteractive = true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Profile',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      if (!isEditing)
                        FilledButton(
                          key: const Key('profile_edit_button'),
                          onPressed: () {
                            context.go(RouterPaths.profileEdit);
                          },
                          child: const Text('Edit'),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              key: const Key('profile_cancel_button'),
                              onPressed: () {
                                context.go(RouterPaths.profile);
                              },
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              key: const Key('profile_save_button'),
                              onPressed: () async {
                                if (user != null) {
                                  final updatedUser = UserModel(
                                    id: user.id,
                                    fullName: _nameController.text,
                                    email: user.email,
                                    title: _titleController.text,
                                    orgUnitId: user.orgUnitId,
                                    status: user.status,
                                    role: user.role,
                                  );
                                  await ref
                                      .read(databaseServiceProvider)
                                      .saveUser(updatedUser);
                                  ref.read(currentUserProvider.notifier).update(updatedUser);
                                }
                                if (context.mounted) {
                                  context.go(RouterPaths.profile);
                                }
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 400,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isEditing) ...[
                        TextField(
                          key: const Key('profile_name_input'),
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('profile_title_input'),
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('profile_email_input'),
                          controller: TextEditingController(
                            text: user?.email ?? '',
                          ),
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('profile_org_unit_input'),
                          controller: TextEditingController(
                            text: _orgUnit?.name ?? 'None',
                          ),
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Org Unit',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ] else ...[
                        IgnorePointer(
                          child: TextField(
                            key: const Key('profile_full_name'),
                            enabled: true,
                            controller: TextEditingController(
                              text: user?.fullName ?? '',
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        IgnorePointer(
                          child: TextField(
                            key: const Key('profile_title'),
                            enabled: true,
                            controller: TextEditingController(
                              text: user?.title ?? '',
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        IgnorePointer(
                          child: TextField(
                            key: const Key('profile_email'),
                            enabled: true,
                            controller: TextEditingController(
                              text: user?.email ?? '',
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        IgnorePointer(
                          child: TextField(
                            key: const Key('profile_role'),
                            enabled: true,
                            controller: TextEditingController(
                              text: user?.role ?? '',
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        IgnorePointer(
                          child: TextField(
                            key: const Key('profile_org_unit'),
                            enabled: true,
                            controller: TextEditingController(
                              text: _orgUnit?.name ?? 'None',
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Org Unit',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (isOrgInactive) ...[
                          const SizedBox(height: 16),
                          Container(
                            key: const Key('profile_org_inactive_warning'),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.colors.warningContainer,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: context.colors.warning),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: context.colors.onWarningContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Warning: Associated organization unit is inactive.',
                                    style: TextStyle(
                                      color: context.colors.onWarningContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // My Capacity Section Header
                Listener(
                  onPointerDown: (_) => _tappedInteractive = true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Capacity',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      if (user != null)
                        if (!_isCapacityEditing)
                          Row(
                            children: [
                              FilledButton(
                                key: const Key('capacity_edit_button'),
                                onPressed: () {
                                  final currentCapacities =
                                      ref
                                          .read(
                                            userCapacitiesStreamProvider(
                                              user.email,
                                            ),
                                          )
                                          .value ??
                                      [];
                                  setState(() {
                                    _isCapacityEditing = true;
                                    _selectedRange = null;
                                    _cellEditMode = CellEditMode.none;
                                    _capacityError = null;
                                    final sortedList =
                                        List<UserCapacityModel>.from(
                                          currentCapacities,
                                        );
                                    sortedList.sort((a, b) {
                                      if (a.type == CapacityType.standard) return -1;
                                      if (b.type == CapacityType.standard) return 1;
                                      return (a.startDate ?? DateTime.now())
                                          .compareTo(
                                            b.startDate ?? DateTime.now(),
                                          );
                                    });
                                    _editableCapacities = sortedList;
                                    _deletedCapacityIds.clear();
                                    _initCapacityControllers();
                                  });
                                },
                                child: const Text('Edit'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                key: const Key('capacity_add_button'),
                                onPressed: () {
                                  _showTimePeriodModal(context, user.email);
                                },
                                child: const Text('Add'),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              OutlinedButton(
                                key: const Key('capacity_cancel_button'),
                                onPressed: () {
                                  final currentCapacities = ref
                                          .read(
                                            userCapacitiesStreamProvider(
                                              user.email,
                                            ),
                                          )
                                          .value ??
                                      [];
                                  final sortedList =
                                      List<UserCapacityModel>.from(
                                        currentCapacities,
                                      );
                                  sortedList.sort((a, b) {
                                    if (a.type == CapacityType.standard) return -1;
                                    if (b.type == CapacityType.standard) return 1;
                                    return (a.startDate ?? DateTime.now())
                                        .compareTo(
                                          b.startDate ?? DateTime.now(),
                                        );
                                  });
                                  setState(() {
                                    _isCapacityEditing = false;
                                    _selectedRange = null;
                                    _cellEditMode = CellEditMode.none;
                                    _capacityError = null;
                                    _deletedCapacityIds.clear();
                                    _editableCapacities = sortedList;
                                    _initCapacityControllers();
                                  });
                                },
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                key: const Key('capacity_save_button'),
                                onPressed: () async {
                                  final success = await _saveCapacityEdits(
                                    user.email,
                                  );
                                  if (success) {
                                    setState(() {
                                      _isCapacityEditing = false;
                                      _selectedRange = null;
                                      _cellEditMode = CellEditMode.none;
                                      _capacityError = null;
                                      _isDraggingSelection = false;
                                      _isDraggingFill = false;
                                      _dragFillRange = null;
                                      _dragFillStart = null;
                                    });
                                  }
                                },
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_capacityError != null) ...[
                  Text(
                    _capacityError!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Table
                if (user != null)
                  Consumer(
                    builder: (context, ref, child) {
                      final capacitiesAsync = ref.watch(
                        userCapacitiesStreamProvider(user.email),
                      );

                      return capacitiesAsync.when(
                        data: (dbCapacities) {
                          final theme = Theme.of(context);

                          final allSource = _isCapacityEditing
                              ? _editableCapacities
                              : dbCapacities;

                          final sortedSource = List<UserCapacityModel>.from(allSource);
                          sortedSource.sort((a, b) {
                            if (a.type == CapacityType.standard) return -1;
                            if (b.type == CapacityType.standard) return 1;
                            return (a.startDate ?? DateTime.now())
                                .compareTo(b.startDate ?? DateTime.now());
                          });

                          final standardCaps = sortedSource.where((c) => c.type == CapacityType.standard).toList();
                          final specificCaps = sortedSource.where((c) => c.type != CapacityType.standard).toList();

                          // Dynamic years collection ONLY from custom capacities:
                          final yearsSet = <int>{};
                          for (final cap in specificCaps) {
                            if (cap.startDate != null) yearsSet.add(cap.startDate!.year);
                            if (cap.endDate != null) yearsSet.add(cap.endDate!.year);
                          }
                          final sortedYears = yearsSet.toList()..sort();

                          // Apply the selected year filter (if any)
                          List<UserCapacityModel> filteredSpecifics = specificCaps;
                          if (_selectedYearFilter != null) {
                            filteredSpecifics = specificCaps.where((cap) {
                              final startYear = cap.startDate?.year;
                              final endYear = cap.endDate?.year;
                              return (startYear == null || startYear <= _selectedYearFilter!) &&
                                     (endYear == null || endYear >= _selectedYearFilter!);
                            }).toList();
                          }

                          final totalSpecifics = filteredSpecifics.length;
                          final maxPage = (totalSpecifics / 5).ceil().clamp(1, 9999);
                          if (_currentPage > maxPage) {
                            _currentPage = maxPage;
                          }

                          final paginatedSpecifics = filteredSpecifics
                              .skip((_currentPage - 1) * 5)
                              .take(5)
                              .toList();

                          final displayedList = [
                            ...standardCaps,
                            ...paginatedSpecifics,
                          ];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (specificCaps.isNotEmpty) ...[
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    MenuAnchor(
                                      builder: (context, controller, child) {
                                        final bool isSelected =
                                            _selectedYearFilter != null;
                                        return FilterChip(
                                          key: const Key(
                                            'profile_capacity_year_filter_dropdown',
                                          ),
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _selectedYearFilter
                                                        ?.toString() ??
                                                    'Year',
                                                style: TextStyle(
                                                  color:
                                                      isSelected
                                                          ? Colors.white
                                                          : null,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.arrow_drop_down,
                                                size: 18,
                                                color:
                                                    isSelected
                                                        ? Colors.white
                                                        : null,
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
                                        );
                                      },
                                      menuChildren: [
                                        MenuItemButton(
                                          key: const Key(
                                            'profile_capacity_year_filter_all_item',
                                          ),
                                          onPressed:
                                              () => setState(() {
                                                _selectedYearFilter = null;
                                                _currentPage = 1;
                                              }),
                                          child: const Text('All'),
                                        ),
                                        ...sortedYears.map((year) {
                                          return MenuItemButton(
                                            key: Key(
                                              'profile_capacity_year_filter_item_$year',
                                            ),
                                            onPressed:
                                                () => setState(() {
                                                  _selectedYearFilter = year;
                                                  _currentPage = 1;
                                                }),
                                            child: Text(year.toString()),
                                          );
                                        }),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          totalSpecifics == 0
                                              ? '0 of 0'
                                              : '${(_currentPage - 1) * 5 + 1}-${((_currentPage * 5) > totalSpecifics) ? totalSpecifics : (_currentPage * 5)} of $totalSpecifics',
                                          key: const Key(
                                            'profile_capacity_pagination_displayed_count',
                                          ),
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        const SizedBox(width: 16),
                                        IconButton(
                                          key: const Key(
                                            'profile_capacity_page_back',
                                          ),
                                          icon: const Icon(Icons.chevron_left),
                                          onPressed:
                                              _currentPage > 1
                                                  ? () => setState(
                                                    () => _currentPage--,
                                                  )
                                                  : null,
                                        ),
                                        const SizedBox(width: 8),
                                        PageIndicatorInput(
                                          currentPage: _currentPage,
                                          maxPage: maxPage,
                                          onPageChanged:
                                              (page) => setState(
                                                () => _currentPage = page,
                                              ),
                                          inputKey: const Key(
                                            'profile_capacity_pagination_pages_input',
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '/ $maxPage',
                                          key: const Key(
                                            'profile_capacity_pagination_pages',
                                          ),
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          key: const Key(
                                            'profile_capacity_page_forward',
                                          ),
                                          icon: const Icon(Icons.chevron_right),
                                          onPressed:
                                              _currentPage < maxPage
                                                  ? () => setState(
                                                    () => _currentPage++,
                                                  )
                                                  : null,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                              LayoutBuilder(
                                builder: (context, constraints) {
                              final totalWidth = constraints.maxWidth;
                              final availableWidth = totalWidth - 84;
                              final periodWidth = availableWidth * 0.2;
                              final cellWidth = (availableWidth * 0.8) / 8;
                              _currentCapacities = displayedList;

                              return Listener(
                                onPointerDown: (_) => _tappedInteractive = true,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    // Consume tap inside the table so it doesn't clear selection
                                  },
                                  child: Focus(
                                    focusNode: _tableFocusNode,
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent) {
                                        final isShortcut =
                                            (HardwareKeyboard
                                                .instance
                                                .isControlPressed ||
                                            HardwareKeyboard
                                                .instance
                                                .isMetaPressed);
                                        if (isShortcut &&
                                            event.logicalKey ==
                                                LogicalKeyboardKey.keyC) {
                                          _copySelectedCells();
                                          return KeyEventResult.handled;
                                        }
                                        if (_isCapacityEditing &&
                                            isShortcut &&
                                            event.logicalKey ==
                                                LogicalKeyboardKey.keyV) {
                                          _pasteSelectedCells();
                                          return KeyEventResult.handled;
                                        }

                                        if (_selectedRange != null) {
                                          final key = event.logicalKey;

                                          // 1. Arrow Key Navigation (when in selected or typing mode)
                                          if (key ==
                                                  LogicalKeyboardKey.arrowUp ||
                                              key ==
                                                  LogicalKeyboardKey
                                                      .arrowDown) {
                                            if (_cellEditMode ==
                                                    CellEditMode.selected ||
                                                _cellEditMode ==
                                                    CellEditMode
                                                        .typingFromType ||
                                                _cellEditMode ==
                                                    CellEditMode
                                                        .typingFromDouble) {
                                              _navigateSelection(key);
                                              return KeyEventResult.handled;
                                            }
                                          } else if (key ==
                                                  LogicalKeyboardKey.arrowLeft ||
                                              key ==
                                                  LogicalKeyboardKey
                                                      .arrowRight) {
                                            if (_cellEditMode ==
                                                CellEditMode.selected) {
                                              _navigateSelection(key);
                                              return KeyEventResult.handled;
                                            }
                                          }

                                           // 2. Typing to Enter Typing Mode (when in selected mode and editing is enabled)
                                          if (_isCapacityEditing &&
                                              _cellEditMode ==
                                                  CellEditMode.selected) {
                                            final character = _getCharacterFromKey(key, event.character);
                                            if (character != null && _isCharacterKey(
                                              key,
                                              character,
                                            )) {
                                              _startTypingFromType(
                                                _selectedRange!.start.row,
                                                _selectedRange!.start.col,
                                                character,
                                              );
                                              return KeyEventResult.handled;
                                            } else if (key ==
                                                    LogicalKeyboardKey
                                                        .backspace ||
                                                key ==
                                                    LogicalKeyboardKey.delete) {
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
                                    child: Listener(
                                      onPointerUp: (event) {
                                        if (_isDraggingSelection) {
                                          setState(() {
                                            _isDraggingSelection = false;
                                          });
                                        }
                                        if (_isDraggingFill) {
                                          setState(() {
                                            _performDragFill();
                                            _isDraggingFill = false;
                                            _dragFillRange = null;
                                            _dragFillStart = null;
                                          });
                                        }
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Header row
                                          Container(
                                            key: _headerRowKey,
                                            height: 48,
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
                                              horizontal: 16,
                                            ),
                                            child: Row(
                                              children: [
                                                _buildHeaderCell(
                                                  c: 0,
                                                  width: periodWidth,
                                                  key: _colKeys[0] ??=
                                                      GlobalKey(),
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(
                                                      left: 8.0,
                                                    ),
                                                    child: Text(
                                                      'Time Period',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: theme.colorScheme.primary,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                _buildHeaderCell(
                                                  c: 1,
                                                  width: cellWidth,
                                                  key: _colKeys[1] ??=
                                                      GlobalKey(),
                                                  child: Text(
                                                    'Monday',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: theme.colorScheme.primary,
                                                    ),
                                                  ),
                                                ),
                                                _buildHeaderCell(
                                                  c: 2,
                                                  width: cellWidth,
                                                  key: _colKeys[2] ??=
                                                      GlobalKey(),
                                                  child: Text(
                                                    'Tuesday',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: theme.colorScheme.primary,
                                                    ),
                                                  ),
                                                ),
                                                _buildHeaderCell(
                                                  c: 3,
                                                  width: cellWidth,
                                                  key: _colKeys[3] ??=
                                                      GlobalKey(),
                                                  child: Text(
                                                    'Wednesday',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: theme.colorScheme.primary,
                                                    ),
                                                  ),
                                                ),
                                                _buildHeaderCell(
                                                  c: 4,
                                                  width: cellWidth,
                                                  key: _colKeys[4] ??=
                                                      GlobalKey(),
                                                  child: Text(
                                                    'Thursday',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: theme.colorScheme.primary,
                                                    ),
                                                  ),
                                                ),
                                                _buildHeaderCell(
                                                  c: 5,
                                                  width: cellWidth,
                                                  key: _colKeys[5] ??=
                                                      GlobalKey(),
                                                  child: Text(
                                                    'Friday',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: theme.colorScheme.primary,
                                                    ),
                                                  ),
                                                ),
                                                _buildHeaderCell(
                                                  c: 6,
                                                  width: cellWidth,
                                                  key: _colKeys[6] ??=
                                                      GlobalKey(),
                                                  child: Text(
                                                    'Saturday',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: theme.colorScheme.primary,
                                                    ),
                                                  ),
                                                ),
                                                _buildHeaderCell(
                                                  c: 7,
                                                  width: cellWidth,
                                                  key: _colKeys[7] ??=
                                                      GlobalKey(),
                                                  child: Text(
                                                    'Sunday',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: theme.colorScheme.primary,
                                                    ),
                                                  ),
                                                ),
                                                _buildHeaderCell(
                                                  c: 8,
                                                  width: cellWidth,
                                                  key: _colKeys[8] ??=
                                                      GlobalKey(),
                                                  child: Text(
                                                    'Sum',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: theme.colorScheme.primary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 48),
                                              ],
                                            ),
                                          ),
                                          if (displayedList.isEmpty)
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
                                              child: const Center(
                                                child: Text(
                                                  'No capacities found.',
                                                ),
                                              ),
                                            )
                                          else
                                            ...List.generate(displayedList.length, (
                                              idx,
                                            ) {
                                              final cap = displayedList[idx];
                                              final rowKey = _rowKeys[idx] ??=
                                                  GlobalKey();
                                              return Container(
                                                key: rowKey,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color: theme.colorScheme.primary,
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    _buildPeriodCell(
                                                      cap,
                                                      idx,
                                                      periodWidth,
                                                    ),
                                                    _buildDayCell(
                                                      cap,
                                                      idx,
                                                      'monday',
                                                      () => cap.monday,
                                                      (v) {
                                                        final targetIndex = _editableCapacities.indexWhere((c) => c.id == cap.id);
                                                        if (targetIndex != -1) {
                                                          _editableCapacities[targetIndex] = _editableCapacities[targetIndex].copyWith(monday: v);
                                                        }
                                                      },
                                                      cellWidth,
                                                    ),
                                                    _buildDayCell(
                                                      cap,
                                                      idx,
                                                      'tuesday',
                                                      () => cap.tuesday,
                                                      (v) {
                                                        final targetIndex = _editableCapacities.indexWhere((c) => c.id == cap.id);
                                                        if (targetIndex != -1) {
                                                          _editableCapacities[targetIndex] = _editableCapacities[targetIndex].copyWith(tuesday: v);
                                                        }
                                                      },
                                                      cellWidth,
                                                    ),
                                                    _buildDayCell(
                                                      cap,
                                                      idx,
                                                      'wednesday',
                                                      () => cap.wednesday,
                                                      (v) {
                                                        final targetIndex = _editableCapacities.indexWhere((c) => c.id == cap.id);
                                                        if (targetIndex != -1) {
                                                          _editableCapacities[targetIndex] = _editableCapacities[targetIndex].copyWith(wednesday: v);
                                                        }
                                                      },
                                                      cellWidth,
                                                    ),
                                                    _buildDayCell(
                                                      cap,
                                                      idx,
                                                      'thursday',
                                                      () => cap.thursday,
                                                      (v) {
                                                        final targetIndex = _editableCapacities.indexWhere((c) => c.id == cap.id);
                                                        if (targetIndex != -1) {
                                                          _editableCapacities[targetIndex] = _editableCapacities[targetIndex].copyWith(thursday: v);
                                                        }
                                                      },
                                                      cellWidth,
                                                    ),
                                                    _buildDayCell(
                                                      cap,
                                                      idx,
                                                      'friday',
                                                      () => cap.friday,
                                                      (v) {
                                                        final targetIndex = _editableCapacities.indexWhere((c) => c.id == cap.id);
                                                        if (targetIndex != -1) {
                                                          _editableCapacities[targetIndex] = _editableCapacities[targetIndex].copyWith(friday: v);
                                                        }
                                                      },
                                                      cellWidth,
                                                    ),
                                                    _buildDayCell(
                                                      cap,
                                                      idx,
                                                      'saturday',
                                                      () => cap.saturday,
                                                      (v) {
                                                        final targetIndex = _editableCapacities.indexWhere((c) => c.id == cap.id);
                                                        if (targetIndex != -1) {
                                                          _editableCapacities[targetIndex] = _editableCapacities[targetIndex].copyWith(saturday: v);
                                                        }
                                                      },
                                                      cellWidth,
                                                    ),
                                                    _buildDayCell(
                                                      cap,
                                                      idx,
                                                      'sunday',
                                                      () => cap.sunday,
                                                      (v) {
                                                        final targetIndex = _editableCapacities.indexWhere((c) => c.id == cap.id);
                                                        if (targetIndex != -1) {
                                                          _editableCapacities[targetIndex] = _editableCapacities[targetIndex].copyWith(sunday: v);
                                                        }
                                                      },
                                                      cellWidth,
                                                    ),
                                                    _buildSumCell(
                                                      cap,
                                                      idx,
                                                      cellWidth,
                                                    ),
                                                    SizedBox(
                                                      width: 48,
                                                      child:
                                                          _isCapacityEditing &&
                                                              cap.type ==
                                                                  CapacityType.specific
                                                          ? Listener(
                                                              onPointerDown: (_) =>
                                                                  _tappedInteractive =
                                                                      true,
                                                              child: IconButton(
                                                                key: Key(
                                                                  'capacity_delete_${cap.id}',
                                                                ),
                                                                icon: const Icon(
                                                                  Icons.delete,
                                                                  color: Colors
                                                                      .red,
                                                                ),
                                                                onPressed: () {
                                                                  setState(() {
                                                                    _editableCapacities.removeWhere((c) => c.id == cap.id);
                                                                    if (!cap.id.startsWith(
                                                                          'temp_',
                                                                        ) &&
                                                                        cap
                                                                            .id
                                                                            .isNotEmpty) {
                                                                      _deletedCapacityIds
                                                                          .add(
                                                                            cap.id,
                                                                          );
                                                                    }
                                                                  });
                                                                },
                                                              ),
                                                            )
                                                          : const SizedBox.shrink(),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                        loading: () =>
                            _buildProfileTableSkeleton(Theme.of(context)),
                        error: (err, stack) =>
                            Text('Error loading capacities: $err'),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTableSkeleton(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 40,
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
              const SizedBox(width: 12),
              Container(
                width: 150,
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        ...List.generate(3, (index) {
          return Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 0.5,
                ),
                left: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 0.5,
                ),
                right: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                ...List.generate(8, (m) {
                  return Container(
                    width: 32,
                    height: 16,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _HoverCell extends StatefulWidget {
  final double width;
  final double height;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final String? tooltip;
  final Decoration? decoration;
  final MouseCursor? cursor;
  final PointerDownEventListener? onPointerDown;
  final PointerMoveEventListener? onPointerMove;
  final PointerUpEventListener? onPointerUp;
  final GestureTapDownCallback? onSecondaryTapDown;
  final VoidCallback? onHoverEnter;
  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;

  const _HoverCell({
    super.key,
    required this.width,
    required this.height,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.tooltip,
    this.decoration,
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onSecondaryTapDown,
    this.cursor,
    this.onHoverEnter,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
  });

  @override
  State<_HoverCell> createState() => _HoverCellState();
}

class _HoverCellState extends State<_HoverCell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Decoration combinedDecoration = widget.decoration ?? const BoxDecoration();
    if (_isHovered) {
      if (combinedDecoration is BoxDecoration) {
        combinedDecoration = combinedDecoration.copyWith(
          color:
              (combinedDecoration.color ?? Colors.transparent).withValues(
                    alpha: 0.24,
                  ) ==
                  Colors.transparent
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.12)
              : Color.alphaBlend(
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.12),
                  combinedDecoration.color ?? Colors.transparent,
                ),
        );
      }
    }

    Widget cell = MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        widget.onHoverEnter?.call();
      },
      onExit: (_) => setState(() => _isHovered = false),
      cursor:
          widget.cursor ??
          (widget.onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.text),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: combinedDecoration,
        child: widget.child,
      ),
    );

    if (widget.onPointerDown != null ||
        widget.onPointerMove != null ||
        widget.onPointerUp != null) {
      cell = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: widget.onPointerDown,
        onPointerMove: widget.onPointerMove,
        onPointerUp: widget.onPointerUp,
        child: cell,
      );
    }

    if (widget.onPanStart != null ||
        widget.onTap != null ||
        widget.onDoubleTap != null ||
        widget.onSecondaryTapDown != null) {
      cell = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onPanStart: widget.onPanStart,
        onPanUpdate: widget.onPanUpdate,
        onPanEnd: widget.onPanEnd,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        child: cell,
      );
    }

    if (widget.tooltip != null) {
      cell = Tooltip(message: widget.tooltip!, child: cell);
    }

    return cell;
  }
}

class _CellPosition {
  final int row;
  final int col;
  const _CellPosition(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CellPosition &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

class _CellRange {
  final _CellPosition start;
  final _CellPosition end;
  const _CellRange(this.start, this.end);

  int get minRow => start.row < end.row ? start.row : end.row;
  int get maxRow => start.row > end.row ? start.row : end.row;
  int get minCol => start.col < end.col ? start.col : end.col;
  int get maxCol => start.col > end.col ? start.col : end.col;

  bool contains(int r, int c) {
    return r >= minRow && r <= maxRow && c >= minCol && c <= maxCol;
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

