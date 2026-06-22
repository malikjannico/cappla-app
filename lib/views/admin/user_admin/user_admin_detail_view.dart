import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/router_paths.dart';
import '../../../models/user_model.dart';
import '../../../models/org_unit_model.dart';
import '../../../core/theme/theme_extensions.dart';

final userStreamProvider = StreamProvider.autoDispose
    .family<UserModel?, String>((ref, id) {
      return ref.watch(databaseServiceProvider).watchUser(id);
    });

class UserAdminDetailView extends ConsumerStatefulWidget {
  final String id;
  const UserAdminDetailView({super.key, required this.id});

  @override
  ConsumerState<UserAdminDetailView> createState() =>
      _UserAdminDetailViewState();
}

class _UserAdminDetailViewState extends ConsumerState<UserAdminDetailView> {
  late TextEditingController _fullNameController;
  late TextEditingController _titleController;
  late TextEditingController _orgUnitController;
  String? _selectedRole;
  String? _selectedStatus;
  bool _initialized = false;
  String? _lastLoc;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _titleController = TextEditingController();
    _orgUnitController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _titleController.dispose();
    _orgUnitController.dispose();
    super.dispose();
  }

  void _showOrgSelectionModal(List<OrgUnitModel> orgUnits) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String query = '';
        String? localSelectedId = _orgUnitController.text.trim().isEmpty
            ? null
            : _orgUnitController.text.trim();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredOrgs = orgUnits.where((org) {
              final q = query.trim().toLowerCase();
              if (q.isEmpty) return true;
              return org.name.toLowerCase().contains(q) ||
                  org.abbreviation.toLowerCase().contains(q);
            }).toList();

            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: const Text('Select Organization Unit'),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      key: const Key('org_modal_search_input'),
                      decoration: InputDecoration(
                        labelText: 'Search Org Units',
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
                      child: ListView.builder(
                        itemCount: filteredOrgs.length + 1,
                        itemBuilder: (context, idx) {
                          if (idx == 0) {
                            final isSelected = localSelectedId == null;
                            return ListTile(
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
                          final org = filteredOrgs[idx - 1];
                          final isSelected = org.id == localSelectedId;
                          return ListTile(
                            title: Text(org.name),
                            subtitle: Text(org.abbreviation),
                            selected: isSelected,
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                            onTap: () {
                              setDialogState(() {
                                localSelectedId = org.id;
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
                  key: const Key('org_modal_cancel_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('org_modal_select_button'),
                  onPressed: () {
                    setState(() {
                      _orgUnitController.text = localSelectedId ?? '';
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
    final loc = GoRouterState.of(context).matchedLocation;
    final isEditing = loc.endsWith('/edit');
    final userAsync = ref.watch(userStreamProvider(widget.id));
    final user = userAsync.value ?? ref.watch(selectedUserForDetailsProvider);

    if (user != null) {
      if (!_initialized || user.id != _lastUserId || _lastLoc != loc) {
        _fullNameController.text = user.fullName;
        _titleController.text = user.title;
        _orgUnitController.text = user.orgUnitId ?? '';
        _selectedRole = user.role;
        _selectedStatus = user.status;
        _lastUserId = user.id;
        _lastLoc = loc;
        _initialized = true;
      }
    }

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFFFFF),
        body: Center(child: Text('No User Selected')),
      );
    }

    final orgUnitsAsync = ref.watch(orgUnitsStreamProvider);
    final orgUnits = orgUnitsAsync.value ?? [];

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
                    label: 'Users',
                    linkKey: const Key('user_detail_back_button'),
                    onTap: () => context.go(RouterPaths.adminUsers),
                  ),
                  Text(
                    ' / ${user.fullName}',
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
                      user.fullName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isEditing) ...[
                            FilledButton(
                              key: const Key('user_detail_edit_button'),
                              onPressed: () {
                                context.go(
                                  RouterPaths.adminUserEditPath(widget.id),
                                );
                              },
                              child: const Text('Edit'),
                            ),
                            const SizedBox(width: 8),
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: MenuAnchor(
                                key: const Key('user_detail_overflow_button'),
                                builder: (context, controller, child) {
                                  return IconButton(
                                    icon: const Icon(Icons.more_vert),
                                    tooltip: 'Show menu',
                                    onPressed: () {
                                      if (controller.isOpen) {
                                        controller.close();
                                      } else {
                                        controller.open();
                                      }
                                    },
                                  );
                                },
                                menuChildren: [
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: MenuItemButton(
                                      onPressed: () async {
                                        final newStatus =
                                            user.status == 'Active'
                                            ? 'Inactive'
                                            : 'Active';
                                        await ref
                                            .read(databaseServiceProvider)
                                            .saveUser(
                                              user.copyWith(
                                                status: newStatus,
                                                lastModifiedBy:
                                                    ref
                                                        .read(
                                                          currentUserProvider,
                                                        )
                                                        ?.email ??
                                                    'system',
                                                lastModifiedAt: DateTime.now(),
                                              ),
                                            );
                                        if (user.email ==
                                            ref
                                                .read(currentUserProvider)
                                                ?.email) {
                                          final updated = await ref
                                              .read(databaseServiceProvider)
                                              .getUser(user.email);
                                          ref
                                                  .read(
                                                    currentUserProvider
                                                        .notifier,
                                                  )
                                                  .state =
                                              updated;
                                        }
                                      },
                                      child: Text(
                                        user.status == 'Active'
                                            ? 'Deactivate'
                                            : 'Active',
                                      ),
                                    ),
                                  ),
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: MenuItemButton(
                                      onPressed: () async {
                                        await ref
                                            .read(authServiceProvider)
                                            .sendPasswordResetEmail(
                                              email: user.email,
                                            );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Password reset email sent to ${user.email}.',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('Reset Password'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            OutlinedButton(
                              key: const Key('user_detail_cancel_button'),
                              onPressed: () {
                                context.go(
                                  RouterPaths.adminUserDetailPath(widget.id),
                                );
                              },
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              key: const Key('user_detail_save_button'),
                              onPressed: () async {
                                final targetOrgId =
                                    _orgUnitController.text.trim().isEmpty
                                    ? null
                                    : _orgUnitController.text.trim();
                                final targetStatus =
                                    _selectedStatus ?? user.status;

                                final updated = UserModel(
                                  id: user.id,
                                  fullName: _fullNameController.text.trim(),
                                  email: user.email,
                                  title: _titleController.text.trim(),
                                  status: targetStatus,
                                  role: _selectedRole ?? user.role,
                                  orgUnitId: targetOrgId,
                                );
                                await ref
                                    .read(databaseServiceProvider)
                                    .saveUser(updated);

                                final currentUser = ref.read(
                                  currentUserProvider,
                                );
                                if (currentUser != null &&
                                    currentUser.email == updated.email) {
                                  ref.read(currentUserProvider.notifier).state =
                                      updated;
                                }

                                if (context.mounted) {
                                  context.go(
                                    RouterPaths.adminUserDetailPath(widget.id),
                                  );
                                }
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Fields container (width 400)
              SizedBox(
                width: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isEditing) ...[
                      Text(
                        'Status',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        key: const Key('user_detail_status_input'),
                        child: _buildStatusChip(
                          _selectedStatus ?? 'Active',
                          theme,
                          context,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('user_detail_name_input'),
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Color(0xFFFFF9C4),
                          label: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: 'Full Name'),
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
                      TextField(
                        key: const Key('user_detail_email_input'),
                        controller: TextEditingController(text: user.email),
                        enabled: false,
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Color(0xFFFFF9C4),
                          label: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: 'Email'),
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
                      TextField(
                        key: const Key('user_detail_title_input'),
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      MenuAnchor(
                        key: const Key('user_detail_role_input'),
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
                                labelText: 'Role',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.arrow_drop_down),
                              ),
                              child: Text(
                                _selectedRole ?? '',
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          );
                        },
                        menuChildren: const ['Administrator', 'User'].map((
                          item,
                        ) {
                          return MenuItemButton(
                            onPressed: () =>
                                setState(() => _selectedRole = item),
                            child: Text(item),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Org Unit Search Selector
                      (() {
                        final currentId = _orgUnitController.text.trim();
                        final selectedOrg = orgUnits
                            .cast<OrgUnitModel?>()
                            .firstWhere(
                              (o) => o?.id == currentId,
                              orElse: () => null,
                            );
                        return GestureDetector(
                          onTap: () => _showOrgSelectionModal(orgUnits),
                          child: AbsorbPointer(
                            child: TextField(
                              key: const Key('user_detail_org_dropdown'),
                              controller: TextEditingController(
                                text: selectedOrg != null
                                    ? '${selectedOrg.name} (${selectedOrg.abbreviation})'
                                    : 'None',
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Organization Unit',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.arrow_drop_down),
                              ),
                            ),
                          ),
                        );
                      })(),
                    ] else ...[
                      AbsorbPointer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status',
                                  key: const Key('user_detail_status_label'),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildStatusChip(user.status, theme, context),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('user_detail_name'),
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(
                                text: user.fullName,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('user_detail_email'),
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(
                                text: user.email,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('user_detail_title'),
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(
                                text: user.title,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Title',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('user_detail_role'),
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(
                                text: user.role,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Role',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('user_detail_org'),
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(
                                text: (() {
                                  final selectedOrg = orgUnits
                                      .cast<OrgUnitModel?>()
                                      .firstWhere(
                                        (o) => o?.id == user.orgUnitId,
                                        orElse: () => null,
                                      );
                                  return selectedOrg != null
                                      ? '${selectedOrg.name} (${selectedOrg.abbreviation})'
                                      : 'None';
                                })(),
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Org Unit',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('user_detail_created_by'),
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(
                                text: user.createdBy,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Created By',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('user_detail_created_at'),
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(
                                text: user.createdAt.toLocal().toString().split(
                                  '.',
                                )[0],
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Created At',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('user_detail_last_modified_by'),
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(
                                text: user.lastModifiedBy,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Last Modified By',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('user_detail_last_modified_at'),
                              readOnly: true,
                              focusNode: FocusNode(
                                canRequestFocus: false,
                                skipTraversal: true,
                              ),
                              controller: TextEditingController(
                                text: user.lastModifiedAt
                                    .toLocal()
                                    .toString()
                                    .split('.')[0],
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Last Modified At',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
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
    final primaryColor = theme.colorScheme.primary;
    final hoverColor = theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: widget.linkKey,
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: TextStyle(
            color: _isHovered ? hoverColor : primaryColor,
            fontWeight: FontWeight.w500,
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
  // Convenient extension getter context.colors is available from theme_extensions.dart
  // Wait, let's verify if theme_extensions.dart is imported. Yes, user_admin_detail_view imports:
  // but wait, does user_admin_detail_view import theme_extensions.dart?
  // Let's check imports of user_admin_detail_view.dart!
  // It imports:
  // import '../../../core/providers/providers.dart';
  // import '../../../core/router/router_paths.dart';
  // import '../../../models/user_model.dart';
  // import '../../../models/org_unit_model.dart';
  // It DOES NOT import theme_extensions.dart! We must import it!
  // Let's add the import or use the color directly or import theme_extensions.dart!
  // Wait, let's add `import '../../../core/theme/theme_extensions.dart';` at the top of the file.
  // Actually, we can add it here or import it at the top.
  // Let's import it at the top of user_admin_detail_view.dart.
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
    key: const Key(
      'user_detail_status',
    ), // Maintain key here for status chip container or tests
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
    ),
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
  );
}
