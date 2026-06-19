import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/router_paths.dart';
import 'category_create_view.dart' show BreadcrumbLink;

class ActivityGroupCreateView extends ConsumerStatefulWidget {
  const ActivityGroupCreateView({super.key});

  @override
  ConsumerState<ActivityGroupCreateView> createState() =>
      _ActivityGroupCreateViewState();
}

class _ActivityGroupCreateViewState
    extends ConsumerState<ActivityGroupCreateView> {
  final _nameController = TextEditingController();
  String _errorMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<ActivityGroupModel?> _saveActivityGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Activity Group Name is required.');
      return null;
    }

    final myOrg = ref.read(userOwnedOrgUnitProvider);
    if (myOrg == null) {
      setState(
        () => _errorMessage =
            'Only heads of organization units can create activity groups.',
      );
      return null;
    }

    final user = ref.read(currentUserProvider);
    final id = const Uuid().v4();
    final now = DateTime.now();
    final creator = user?.email ?? 'system';

    try {
      final allGroups = await ref
          .read(databaseServiceProvider)
          .getAllActivityGroups();
      final myGroups = allGroups
          .where((g) => g.ownerOrgUnitId == myOrg.id)
          .toList();
      final nextOrder = myGroups.isEmpty
          ? 1
          : myGroups.map((g) => g.order).reduce((a, b) => a > b ? a : b) + 1;

      final group = ActivityGroupModel(
        id: id,
        name: name,
        ownerOrgUnitId: myOrg.id,
        sharedOrgUnitIds: [],
        appliedOrgUnitIds: [],
        statusMap: {myOrg.id: 'Active'},
        createdBy: creator,
        createdAt: now,
        lastModifiedBy: creator,
        lastModifiedAt: now,
        order: nextOrder,
      );

      await ref.read(databaseServiceProvider).saveActivityGroup(group);
      return group;
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    linkKey: const Key('activity_group_create_back_button'),
                    onTap: () => context.go(RouterPaths.settingsActivityGroups),
                  ),
                  Text(
                    ' / New Activity Group',
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
                      'New Activity Group',
                      key: const Key('activity_group_create_title'),
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
                        key: const Key('activity_group_create_cancel_button'),
                        onPressed: () =>
                            context.go(RouterPaths.settingsActivityGroups),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        key: const Key(
                          'activity_group_create_save_create_button',
                        ),
                        onPressed: () async {
                          final g = await _saveActivityGroup();
                          if (g != null) {
                            setState(() {
                              _nameController.clear();
                              _errorMessage = '';
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Activity Group created successfully.',
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
                        key: const Key('activity_group_create_button'),
                        onPressed: () async {
                          final g = await _saveActivityGroup();
                          if (g != null && context.mounted) {
                            context.go(RouterPaths.settingsActivityGroups);
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
                      key: const Key('activity_group_create_name_input'),
                      controller: _nameController,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFFFF9C4),
                        label: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: 'Activity Group Name'),
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
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        key: const Key('activity_group_create_error_text'),
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
