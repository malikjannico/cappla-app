import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/router_paths.dart';
import 'category_create_view.dart' show BreadcrumbLink;

class ActivityCreateView extends ConsumerStatefulWidget {
  final String activityGroupId;
  const ActivityCreateView({super.key, required this.activityGroupId});

  @override
  ConsumerState<ActivityCreateView> createState() => _ActivityCreateViewState();
}

class _ActivityCreateViewState extends ConsumerState<ActivityCreateView> {
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

  @override
  void dispose() {
    _nameController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
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

  Future<ActivityModel?> _saveActivity() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Activity Name is required.');
      return null;
    }

    if (_selectedType == 'Limited') {
      final startParsed = DateTime.tryParse(_startDateController.text.trim());
      if (startParsed != null) {
        _validityStart = startParsed;
      }
      final endParsed = DateTime.tryParse(_endDateController.text.trim());
      if (endParsed != null) {
        _validityEnd = endParsed;
      }
      if (_validityStart == null || _validityEnd == null) {
        setState(
          () => _errorMessage =
              'Validity dates are required for Limited activities.',
        );
        return null;
      }
      if (_validityEnd!.isBefore(_validityStart!)) {
        setState(() => _errorMessage = 'End date cannot be before start date.');
        return null;
      }
    }

    final myOrg = ref.read(userOwnedOrgUnitProvider);
    if (myOrg == null) {
      setState(
        () => _errorMessage =
            'Only heads of organization units can create activities.',
      );
      return null;
    }

    final user = ref.read(currentUserProvider);
    final id = const Uuid().v4();
    final now = DateTime.now();
    final creator = user?.email ?? 'system';

    // If type is limited, check if current end date has already passed.
    // If so, the initial status might need to be inactive, but normally it starts Active if validity is in future.
    final initialStatus =
        (_selectedType == 'Limited' && _validityEnd!.isBefore(now))
        ? 'Inactive'
        : 'Active';

    try {
      final allActs = await ref
          .read(databaseServiceProvider)
          .getAllActivities();
      final groupActs = allActs
          .where(
            (a) =>
                a.activityGroupId == widget.activityGroupId &&
                a.ownerOrgUnitId == myOrg.id,
          )
          .toList();
      final nextOrder = groupActs.isEmpty
          ? 1
          : groupActs.map((a) => a.order).reduce((a, b) => a > b ? a : b) + 1;

      final activity = ActivityModel(
        id: id,
        name: name,
        activityGroupId: widget.activityGroupId,
        categoryId: _selectedCategoryId,
        type: _selectedType,
        validityStart: _selectedType == 'Limited' ? _validityStart : null,
        validityEnd: _selectedType == 'Limited' ? _validityEnd : null,
        ownerOrgUnitId: myOrg.id,
        sharedOrgUnitIds: [],
        appliedOrgUnitIds: [],
        statusMap: {myOrg.id: initialStatus},
        createdBy: creator,
        createdAt: now,
        lastModifiedBy: creator,
        lastModifiedAt: now,
        order: nextOrder,
      );

      await ref.read(databaseServiceProvider).saveActivity(activity);
      return activity;
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
      );
      return null;
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myOrg = ref.watch(userOwnedOrgUnitProvider);

    if (myOrg == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Only heads of organization units can create activities.',
          ),
        ),
      );
    }

    final groupsAsync = ref.watch(activityGroupsStreamProvider);
    final allGroups = groupsAsync.value ?? [];
    final parentGroup = allGroups.cast<ActivityGroupModel?>().firstWhere(
      (g) => g?.id == widget.activityGroupId,
      orElse: () => null,
    );

    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final allCategories = categoriesAsync.value ?? [];

    final categoryName = _selectedCategoryId != null
        ? allCategories
              .firstWhere(
                (c) => c.id == _selectedCategoryId,
                orElse: () => CategoryModel(
                  id: '',
                  name: '',
                  ownerOrgUnitId: '',
                  sharedOrgUnitIds: [],
                  appliedOrgUnitIds: [],
                  statusMap: {},
                  createdBy: '',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                  lastModifiedBy: '',
                  lastModifiedAt: DateTime.fromMillisecondsSinceEpoch(0),
                  order: 0,
                ),
              )
              .name
        : 'None';

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
                    linkKey: const Key('activity_create_back_button'),
                    onTap: () => context.go(RouterPaths.settingsActivityGroups),
                  ),
                  if (parentGroup != null) ...[
                    Text(
                      ' / ',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    BreadcrumbLink(
                      label: parentGroup.name,
                      onTap: () => context.go(
                        RouterPaths.settingsActivityGroupsDetailPath(
                          widget.activityGroupId,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    ' / New Activity',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
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
                      'New Activity',
                      key: const Key('activity_create_title'),
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
                        key: const Key('activity_create_cancel_button'),
                        onPressed: () => context.go(
                          RouterPaths.settingsActivityGroupsDetailPath(
                            widget.activityGroupId,
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        key: const Key('activity_create_save_create_button'),
                        onPressed: () async {
                          final act = await _saveActivity();
                          if (act != null) {
                            setState(() {
                              _nameController.clear();
                              _selectedCategoryId = null;
                              _selectedType = 'Unlimited';
                              _validityStart = null;
                              _validityEnd = null;
                              _errorMessage = '';
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Activity created successfully.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Save + Create'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: const Key('activity_create_button'),
                        onPressed: () async {
                          final act = await _saveActivity();
                          if (act != null && context.mounted) {
                            context.go(
                              RouterPaths.settingsActivityGroupsDetailPath(
                                widget.activityGroupId,
                              ),
                            );
                          }
                        },
                        child: const Text('Create'),
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
                    TextField(
                      key: const Key('activity_create_name_input'),
                      controller: _nameController,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFFFF9C4),
                        label: Text.rich(
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
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Activity Group (Read Only)
                    TextField(
                      key: const Key('activity_create_group_input'),
                      readOnly: true,
                      controller: TextEditingController(
                        text: parentGroup?.name ?? '',
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Activity Group',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Category Selection Trigger
                    GestureDetector(
                      key: const Key('activity_create_category_input'),
                      onTap: () =>
                          _showCategorySelectionModal(allCategories, myOrg.id),
                      child: AbsorbPointer(
                        child: TextField(
                          controller: TextEditingController(text: categoryName),
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Type Selection using MenuAnchor
                    MenuAnchor(
                      key: const Key('activity_create_type_input'),
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
                          onPressed: () => setState(() => _selectedType = item),
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
                                'activity_create_validity_start_input',
                              ),
                              controller: _startDateController,
                              focusNode: _startFocusNode,
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
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today),
                                  onPressed: () => _selectDate(context, true),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              key: const Key(
                                'activity_create_validity_end_input',
                              ),
                              controller: _endDateController,
                              focusNode: _endFocusNode,
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
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today),
                                  onPressed: () => _selectDate(context, false),
                                ),
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
                        key: const Key('activity_create_error_text'),
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
