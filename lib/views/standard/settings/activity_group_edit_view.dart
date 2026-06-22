import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/router_paths.dart';
import '../../../core/theme/theme_extensions.dart';
import 'activity_group_detail_view.dart' show activityGroupStreamProvider;
import 'category_create_view.dart' show BreadcrumbLink;

class ActivityGroupEditView extends ConsumerStatefulWidget {
  final String id;
  const ActivityGroupEditView({super.key, required this.id});

  @override
  ConsumerState<ActivityGroupEditView> createState() =>
      _ActivityGroupEditViewState();
}

class _ActivityGroupEditViewState extends ConsumerState<ActivityGroupEditView> {
  final _nameController = TextEditingController();
  String _errorMessage = '';
  bool _initialized = false;
  String? _lastId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final myOrg = ref.watch(userOwnedOrgUnitProvider);

    if (myOrg == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Only heads of organization units can edit activity groups.',
          ),
        ),
      );
    }

    final groupAsync = ref.watch(activityGroupStreamProvider(widget.id));
    final group = groupAsync.value;

    if (group == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFFFFF),
        body: Center(child: Text('Loading Activity Group or Group Not Found')),
      );
    }

    final groupStatus = group.statusMap[myOrg.id] ?? 'Active';
    final isOwner = group.ownerOrgUnitId == myOrg.id;

    if (!_initialized || widget.id != _lastId) {
      _nameController.text = group.name;
      _lastId = widget.id;
      _initialized = true;
    }

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
                    linkKey: const Key('activity_group_edit_back_button'),
                    onTap: () => context.go(RouterPaths.settingsActivityGroups),
                  ),
                  Text(
                    ' / ${group.name} / Edit',
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
                      group.name,
                      key: const Key('activity_group_edit_title'),
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
                        key: const Key('activity_group_edit_cancel_button'),
                        onPressed: () => context.go(
                          RouterPaths.settingsActivityGroupsDetailPath(
                            group.id,
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: const Key('activity_group_edit_save_button'),
                        onPressed: isOwner
                            ? () async {
                                final newName = _nameController.text.trim();
                                if (newName.isEmpty) {
                                  setState(
                                    () => _errorMessage =
                                        'Activity Group Name is required.',
                                  );
                                  return;
                                }

                                try {
                                  final updated = group.copyWith(
                                    name: newName,
                                    lastModifiedBy: user?.email ?? 'system',
                                    lastModifiedAt: DateTime.now(),
                                  );
                                  await ref
                                      .read(databaseServiceProvider)
                                      .saveActivityGroup(updated);
                                  if (context.mounted) {
                                    context.go(
                                      RouterPaths.settingsActivityGroupsDetailPath(
                                        group.id,
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
                            : null, // Only owning org unit head can update/edit resource
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
                          key: const Key('activity_group_edit_status_label'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildStatusChip(groupStatus, theme, context),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('activity_group_edit_name_input'),
                      controller: _nameController,
                      enabled: isOwner,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFFFF9C4),
                        label: const Text.rich(
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
                        border: const OutlineInputBorder(),
                        helperText: isOwner
                            ? null
                            : 'Only the owning organization unit head can update this resource.',
                      ),
                    ),
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        key: const Key('activity_group_edit_error_text'),
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
