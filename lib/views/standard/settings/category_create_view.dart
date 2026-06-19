import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/router_paths.dart';

class CategoryCreateView extends ConsumerStatefulWidget {
  const CategoryCreateView({super.key});

  @override
  ConsumerState<CategoryCreateView> createState() => _CategoryCreateViewState();
}

class _CategoryCreateViewState extends ConsumerState<CategoryCreateView> {
  final _nameController = TextEditingController();
  String _errorMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<CategoryModel?> _saveCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Category Name is required.');
      return null;
    }

    final myOrg = ref.read(userOwnedOrgUnitProvider);
    if (myOrg == null) {
      setState(
        () => _errorMessage =
            'Only heads of organization units can create categories.',
      );
      return null;
    }

    final user = ref.read(currentUserProvider);
    final id = const Uuid().v4();
    final now = DateTime.now();
    final creator = user?.email ?? 'system';

    try {
      final allCats = await ref
          .read(databaseServiceProvider)
          .getAllCategories();
      final myCats = allCats
          .where((c) => c.ownerOrgUnitId == myOrg.id)
          .toList();
      final nextOrder = myCats.isEmpty
          ? 1
          : myCats.map((c) => c.order).reduce((a, b) => a > b ? a : b) + 1;

      final category = CategoryModel(
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

      await ref.read(databaseServiceProvider).saveCategory(category);
      return category;
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
                    label: 'Categories',
                    linkKey: const Key('category_create_back_button'),
                    onTap: () => context.go(RouterPaths.settingsCategories),
                  ),
                  Text(
                    ' / New Category',
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
                      'New Category',
                      key: const Key('category_create_title'),
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
                        key: const Key('category_create_cancel_button'),
                        onPressed: () =>
                            context.go(RouterPaths.settingsCategories),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        key: const Key('category_create_save_create_button'),
                        onPressed: () async {
                          final cat = await _saveCategory();
                          if (cat != null) {
                            setState(() {
                              _nameController.clear();
                              _errorMessage = '';
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Category created successfully.',
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
                        key: const Key('category_create_button'),
                        onPressed: () async {
                          final cat = await _saveCategory();
                          if (cat != null && context.mounted) {
                            context.go(RouterPaths.settingsCategories);
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
                      key: const Key('category_create_name_input'),
                      controller: _nameController,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFFFF9C4),
                        label: Text.rich(
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
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        key: const Key('category_create_error_text'),
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
