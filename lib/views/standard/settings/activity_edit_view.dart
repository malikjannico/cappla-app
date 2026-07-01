import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/router_paths.dart';
import '../../../core/theme/theme_extensions.dart';
import 'activity_detail_view.dart' show activityStreamProvider;
import 'category_create_view.dart' show BreadcrumbLink;

class ActivityEditView extends ConsumerStatefulWidget {
  final String activityGroupId;
  final String activityId;
  const ActivityEditView({
    super.key,
    required this.activityGroupId,
    required this.activityId,
  });

  @override
  ConsumerState<ActivityEditView> createState() => _ActivityEditViewState();
}

class _ActivityEditViewState extends ConsumerState<ActivityEditView> {
  final _nameController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _startFocusNode = FocusNode();
  final _endFocusNode = FocusNode();

  String? _selectedCategoryId;
  String _selectedType = 'Unlimited';
  DateTime? _validityStart;
  DateTime? _validityEnd;
  String _errorMessage = '';
  bool _initialized = false;
  String? _lastId;

  @override
  void dispose() {
    _nameController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    super.dispose();
  }

  void _showCategorySelectionModal(
    List<CategoryModel> categories,
    String orgUnitId,
  ) {
    // Only active categories of the organization unit
    final activeCategories = categories.where((cat) {
      final status = cat.statusMap[orgUnitId] ?? 'Active';
      final isOwner = cat.ownerOrgUnitId == orgUnitId;
      final isApplied = cat.appliedOrgUnitIds.contains(orgUnitId);
      return status == 'Active' && (isOwner || isApplied);
    }).toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        String query = '';
        String? localSelectedId = _selectedCategoryId;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredCats = activeCategories.where((cat) {
              final q = query.trim().toLowerCase();
              if (q.isEmpty) return true;
              return cat.name.toLowerCase().contains(q);
            }).toList();

            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: const Text('Select Category'),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      key: const Key('category_modal_search_input'),
                      decoration: InputDecoration(
                        labelText: 'Search Categories',
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
                      child: (filteredCats.isEmpty && query.isNotEmpty)
                          ? const Center(
                              child: Text('No active categories found.'),
                            )
                          : ListView.builder(
                              itemCount: filteredCats.length + 1,
                              itemBuilder: (context, idx) {
                                if (idx == 0) {
                                  final isSelected = localSelectedId == null;
                                  return ListTile(
                                    key: const Key(
                                      'category_select_modal_row_none',
                                    ),
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
                                        localSelectedId = null;
                                      });
                                    },
                                  );
                                }
                                final cat = filteredCats[idx - 1];
                                final isSelected = cat.id == localSelectedId;
                                return ListTile(
                                  key: Key(
                                    'category_select_modal_row_${cat.id}',
                                  ),
                                  title: Text(cat.name),
                                  selected: isSelected,
                                  trailing: isSelected
                                      ? Icon(
                                          Icons.check_circle,
                                          color: theme.colorScheme.primary,
                                        )
                                      : null,
                                  onTap: () {
                                    setDialogState(() {
                                      localSelectedId = cat.id;
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
                  key: const Key('category_modal_cancel_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('category_modal_select_button'),
                  onPressed: () {
                    setState(() {
                      _selectedCategoryId = localSelectedId;
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

  Future<void> _selectDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_validityStart ?? DateTime.now())
          : (_validityEnd ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _validityStart = picked;
          _startDateController.text = picked.toLocal().toString().split(' ')[0];
        } else {
          _validityEnd = picked;
          _endDateController.text = picked.toLocal().toString().split(' ')[0];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final myOrg = ref.watch(userOwnedOrgUnitProvider);

    if (myOrg == null) {
      return const Scaffold(
        body: Center(
          child: Text('Only heads of organization units can edit activities.'),
        ),
      );
    }

    final activityAsync = ref.watch(activityStreamProvider(widget.activityId));
    final activity = activityAsync.value;

    if (activity == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFFFFF),
        body: Center(child: Text('Loading Activity or Activity Not Found')),
      );
    }

    final actStatus = activity.statusMap[myOrg.id] ?? 'Active';
    final isOwner = activity.ownerOrgUnitId == myOrg.id;

    if (!_initialized || widget.activityId != _lastId) {
      _nameController.text = activity.name;
      _selectedCategoryId = activity.categoryId;
      _selectedType = activity.type.value;
      _validityStart = activity.validityStart;
      _validityEnd = activity.validityEnd;
      _startDateController.text = _validityStart != null
          ? _validityStart!.toLocal().toString().split(' ')[0]
          : '';
      _endDateController.text = _validityEnd != null
          ? _validityEnd!.toLocal().toString().split(' ')[0]
          : '';
      _lastId = widget.activityId;
      _initialized = true;
    }

    // Load category and group info
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final allCategories = categoriesAsync.value ?? [];
    final selectedCategory = allCategories.cast<CategoryModel?>().firstWhere(
      (c) => c?.id == _selectedCategoryId,
      orElse: () => null,
    );

    final groupsAsync = ref.watch(activityGroupsStreamProvider);
    final allGroups = groupsAsync.value ?? [];
    final group = allGroups.cast<ActivityGroupModel?>().firstWhere(
      (g) => g?.id == widget.activityGroupId,
      orElse: () => null,
    );

    final categoryName = selectedCategory?.name ?? 'None';

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
                    label: 'Activity Groups',
                    linkKey: const Key('activity_edit_back_button'),
                    onTap: () => context.go(RouterPaths.settingsActivityGroups),
                  ),
                  if (group != null) ...[
                    Text(
                      ' / ',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    BreadcrumbLink(
                      label: group.name,
                      onTap: () => context.go(
                        RouterPaths.settingsActivityGroupsDetailPath(
                          widget.activityGroupId,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    ' / ${activity.name} / Edit',
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
                      activity.name,
                      key: const Key('activity_edit_title'),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        key: const Key('activity_edit_cancel_button'),
                        onPressed: () => context.go(
                          RouterPaths.settingsActivitiesDetailPath(
                            widget.activityGroupId,
                            activity.id,
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: const Key('activity_edit_save_button'),
                        onPressed: isOwner
                            ? () async {
                                final newName = _nameController.text.trim();
                                if (newName.isEmpty) {
                                  setState(
                                    () => _errorMessage =
                                        'Activity Name is required.',
                                  );
                                  return;
                                }

                                if (_selectedType == 'Limited') {
                                  final startParsed = DateTime.tryParse(
                                    _startDateController.text.trim(),
                                  );
                                  if (startParsed != null) {
                                    _validityStart = startParsed;
                                  }
                                  final endParsed = DateTime.tryParse(
                                    _endDateController.text.trim(),
                                  );
                                  if (endParsed != null) {
                                    _validityEnd = endParsed;
                                  }
                                  if (_validityStart == null ||
                                      _validityEnd == null) {
                                    setState(
                                      () => _errorMessage =
                                          'Validity dates are required for Limited activities.',
                                    );
                                    return;
                                  }
                                  if (_validityEnd!.isBefore(_validityStart!)) {
                                    setState(
                                      () => _errorMessage =
                                          'End date cannot be before start date.',
                                    );
                                    return;
                                  }
                                }

                                try {
                                  final updated = activity.copyWith(
                                    name: newName,
                                    categoryId: () => _selectedCategoryId,
                                    type: _selectedType,
                                    validityStart: () =>
                                        _selectedType == 'Limited'
                                        ? _validityStart
                                        : null,
                                    validityEnd: () =>
                                        _selectedType == 'Limited'
                                        ? _validityEnd
                                        : null,
                                    lastModifiedBy: user?.email ?? 'system',
                                    lastModifiedAt: DateTime.now(),
                                  );
                                  await ref
                                      .read(databaseServiceProvider)
                                      .saveActivity(updated);
                                  if (context.mounted) {
                                    context.go(
                                      RouterPaths.settingsActivitiesDetailPath(
                                        widget.activityGroupId,
                                        activity.id,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setState(
                                    () => _errorMessage = e
                                        .toString()
                                        .replaceAll('Exception: ', ''),
                                  );
                                }
                              }
                            : null,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          key: const Key('activity_edit_status_label'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildStatusChip(actStatus, theme, context),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('activity_edit_name_input'),
                      controller: _nameController,
                      enabled: isOwner,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFFFF9C4),
                        label: const Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: 'Activity Name'),
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
                        border: const OutlineInputBorder(),
                        helperText: isOwner
                            ? null
                            : 'Only the owning organization unit head can update this resource.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Activity Group (Read Only)
                    TextField(
                      key: const Key('activity_edit_group_input'),
                      readOnly: true,
                      controller: TextEditingController(
                        text: group?.name ?? '',
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Activity Group',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Category Selection Trigger
                    GestureDetector(
                      key: const Key('activity_edit_category_input'),
                      onTap: isOwner
                          ? () => _showCategorySelectionModal(
                              allCategories,
                              myOrg.id,
                            )
                          : null,
                      child: AbsorbPointer(
                        child: TextField(
                          controller: TextEditingController(text: categoryName),
                          decoration: InputDecoration(
                            labelText: 'Category',
                            border: const OutlineInputBorder(),
                            suffixIcon: isOwner
                                ? const Icon(Icons.arrow_drop_down)
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Type Selection
                    // Type Selection using MenuAnchor
                    MenuAnchor(
                      key: const Key('activity_edit_type_input'),
                      builder: (context, controller, child) {
                        return InkWell(
                          onTap: isOwner
                              ? () {
                                  if (controller.isOpen) {
                                    controller.close();
                                  } else {
                                    controller.open();
                                  }
                                }
                              : null,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Color(0xFFFFF9C4),
                              label: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: 'Type'),
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
                              suffixIcon: Icon(Icons.arrow_drop_down),
                            ),
                            child: Text(
                              _selectedType,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        );
                      },
                      menuChildren: const ['Unlimited', 'Limited'].map((item) {
                        return MenuItemButton(
                          onPressed: () {
                            setState(() {
                              _selectedType = item;
                              if (_selectedType == 'Limited') {
                                _validityStart ??= DateTime.now();
                                _validityEnd ??= DateTime.now().add(
                                  const Duration(days: 30),
                                );
                                _startDateController.text = _validityStart!
                                    .toLocal()
                                    .toString()
                                    .split(' ')[0];
                                _endDateController.text = _validityEnd!
                                    .toLocal()
                                    .toString()
                                    .split(' ')[0];
                              }
                            });
                          },
                          child: Text(item),
                        );
                      }).toList(),
                    ),
                    if (_selectedType == 'Limited') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key(
                                'activity_edit_validity_start_input',
                              ),
                              controller: _startDateController,
                              focusNode: _startFocusNode,
                              enabled: isOwner,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFFFF9C4),
                                label: const Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: 'Start Date'),
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
                                border: const OutlineInputBorder(),
                                suffixIcon: isOwner
                                    ? IconButton(
                                        icon: const Icon(Icons.calendar_today),
                                        onPressed: () => _selectDate(true),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              key: const Key(
                                'activity_edit_validity_end_input',
                              ),
                              controller: _endDateController,
                              focusNode: _endFocusNode,
                              enabled: isOwner,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFFFF9C4),
                                label: const Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: 'End Date'),
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
                                border: const OutlineInputBorder(),
                                suffixIcon: isOwner
                                    ? IconButton(
                                        icon: const Icon(Icons.calendar_today),
                                        onPressed: () => _selectDate(false),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        key: const Key('activity_edit_error_text'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
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
