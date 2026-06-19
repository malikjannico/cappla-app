import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/router_paths.dart';
import '../../../core/theme/theme_extensions.dart';
import 'category_detail_view.dart' show categoryStreamProvider;

class CategoryEditView extends ConsumerStatefulWidget {
  final String id;
  const CategoryEditView({super.key, required this.id});

  @override
  ConsumerState<CategoryEditView> createState() => _CategoryEditViewState();
}

class _CategoryEditViewState extends ConsumerState<CategoryEditView> {
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
          child: Text('Only heads of organization units can edit categories.'),
        ),
      );
    }

    final categoryAsync = ref.watch(categoryStreamProvider(widget.id));
    final category = categoryAsync.value;

    if (category == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFFFFF),
        body: Center(child: Text('Loading Category or Category Not Found')),
      );
    }

    final catStatus = category.statusMap[myOrg.id] ?? 'Active';
    final isOwner = category.ownerOrgUnitId == myOrg.id;

    if (!_initialized || widget.id != _lastId) {
      _nameController.text = category.name;
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
                    label: 'Categories',
                    linkKey: const Key('category_edit_back_button'),
                    onTap: () => context.go(RouterPaths.settingsCategories),
                  ),
                  Text(
                    ' / ${category.name} / Edit',
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
                      category.name,
                      key: const Key('category_edit_title'),
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
                        key: const Key('category_edit_cancel_button'),
                        onPressed: () => context.go(
                          RouterPaths.settingsCategoriesDetailPath(category.id),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: const Key('category_edit_save_button'),
                        onPressed: isOwner
                            ? () async {
                                final newName = _nameController.text.trim();
                                if (newName.isEmpty) {
                                  setState(
                                    () => _errorMessage =
                                        'Category Name is required.',
                                  );
                                  return;
                                }

                                try {
                                  final updated = category.copyWith(
                                    name: newName,
                                    lastModifiedBy: user?.email ?? 'system',
                                    lastModifiedAt: DateTime.now(),
                                  );
                                  await ref
                                      .read(databaseServiceProvider)
                                      .saveCategory(updated);
                                  if (context.mounted) {
                                    context.go(
                                      RouterPaths.settingsCategoriesDetailPath(
                                        category.id,
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
                          key: const Key('category_edit_status_label'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildStatusChip(catStatus, theme, context),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('category_edit_name_input'),
                      controller: _nameController,
                      enabled: isOwner,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFFFF9C4),
                        label: const Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: 'Category Name'),
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
                        key: const Key('category_edit_error_text'),
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

class BreadcrumbLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Key? linkKey;

  const BreadcrumbLink({
    super.key,
    required this.label,
    required this.onTap,
    this.linkKey,
  });

  @override
  State<BreadcrumbLink> createState() => _BreadcrumbLinkState();
}

class _BreadcrumbLinkState extends State<BreadcrumbLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          key: widget.linkKey,
          style: TextStyle(
            color: _isHovered
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            decoration: _isHovered
                ? TextDecoration.underline
                : TextDecoration.none,
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
