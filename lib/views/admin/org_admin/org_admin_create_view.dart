import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/router_paths.dart';
import '../../../models/org_unit_model.dart';
import '../../../models/user_model.dart';
import '../user_admin/user_admin_list_view.dart' show usersStreamProvider;

class OrgAdminCreateView extends ConsumerStatefulWidget {
  const OrgAdminCreateView({super.key});

  @override
  ConsumerState<OrgAdminCreateView> createState() => _OrgAdminCreateViewState();
}

class _OrgAdminCreateViewState extends ConsumerState<OrgAdminCreateView> {
  final _nameController = TextEditingController();
  final _abbreviationController = TextEditingController();

  String _type = 'Team';
  String? _headOfEmail;
  String _errorMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    _abbreviationController.dispose();
    super.dispose();
  }

  void _clearFields() {
    _nameController.clear();
    _abbreviationController.clear();
    setState(() {
      _type = 'Team';
      _headOfEmail = null;
      _errorMessage = '';
    });
  }

  Future<bool> _saveOrg() async {
    final name = _nameController.text.trim();
    final abbreviation = _abbreviationController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Name is required.');
      return false;
    }
    if (abbreviation.isEmpty) {
      setState(() => _errorMessage = 'Abbreviation is required.');
      return false;
    }

    try {
      final id = const Uuid().v4();
      final adminEmail = ref.read(currentUserProvider)?.email ?? 'system';
      final now = DateTime.now();
      final newOrg = OrgUnitModel(
        id: id,
        name: name,
        abbreviation: abbreviation,
        type: _type.toLowerCase(),
        headOfEmail: _headOfEmail ?? '',
        childIds: [],
        status: 'Active',
        createdBy: adminEmail,
        createdAt: now,
        lastModifiedBy: adminEmail,
        lastModifiedAt: now,
      );

      await ref.read(databaseServiceProvider).saveOrgUnit(newOrg);
      return true;
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void _showHeadOfSelectionModal(List<UserModel> users) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String query = '';
        String? localSelectedEmail = _headOfEmail;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredUsers = users.where((u) {
              final q = query.trim().toLowerCase();
              if (q.isEmpty) return true;
              return u.fullName.toLowerCase().contains(q) ||
                  u.email.toLowerCase().contains(q);
            }).toList();

            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: const Text('Select Head Of'),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      key: const Key('user_modal_search_input'),
                      decoration: InputDecoration(
                        labelText: 'Search Users',
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
                        itemCount: filteredUsers.length + 1,
                        itemBuilder: (context, idx) {
                          if (idx == 0) {
                            final isSelected = localSelectedEmail == null;
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
                                  localSelectedEmail = null;
                                });
                              },
                            );
                          }
                          final u = filteredUsers[idx - 1];
                          final isSelected = u.email == localSelectedEmail;
                          return ListTile(
                            title: Text(u.fullName),
                            subtitle: Text(u.email),
                            selected: isSelected,
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                            onTap: () {
                              setDialogState(() {
                                localSelectedEmail = u.email;
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
                  key: const Key('user_modal_cancel_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('user_modal_select_button'),
                  onPressed: () {
                    setState(() {
                      _headOfEmail = localSelectedEmail;
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
    final usersAsync = ref.watch(usersStreamProvider);
    final users = usersAsync.value ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Breadcrumbs
            Row(
              children: [
                BreadcrumbLink(
                  label: 'Organization Units',
                  onTap: () => context.go(RouterPaths.adminOrgs),
                ),
                Text(
                  ' / New Organization Unit',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Header Row (Title and Buttons)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  'Create Organization Unit',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      key: const Key('org_create_cancel_button'),
                      onPressed: () {
                        ref
                                .read(
                                  showDetailedOrgCreateFormProvider.notifier,
                                )
                                .state =
                            false;
                        context.go(RouterPaths.adminOrgs);
                      },
                      child: const Text('Cancel'),
                    ),
                    OutlinedButton(
                      key: const Key('org_create_save_create_button'),
                      onPressed: () async {
                        final success = await _saveOrg();
                        if (success) {
                          _clearFields();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Org unit created successfully.'),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Save & Create'),
                    ),
                    FilledButton(
                      key: const Key('org_create_save_button'),
                      onPressed: () async {
                        final success = await _saveOrg();
                        if (success) {
                          ref
                                  .read(
                                    showDetailedOrgCreateFormProvider.notifier,
                                  )
                                  .state =
                              false;
                          if (context.mounted) {
                            context.go(RouterPaths.adminOrgs);
                          }
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Fields Container (width 400)
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: const Key('org_create_name_input'),
                      controller: _nameController,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFFFF9C4),
                        label: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: 'Name'),
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
                      key: const Key('org_create_abbrev_input'),
                      controller: _abbreviationController,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFFFF9C4),
                        label: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: 'Abbreviation'),
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
                    // Type Dropdown
                    MenuAnchor(
                      key: const Key('org_create_type_dropdown'),
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
                              labelText: 'Type',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.arrow_drop_down),
                            ),
                            child: Text(
                              _type,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        );
                      },
                      menuChildren:
                          const [
                            'MD Division',
                            'SVP Division',
                            'VP Division',
                            'Department',
                            'Group',
                            'Team',
                          ].map((item) {
                            return MenuItemButton(
                              onPressed: () => setState(() => _type = item),
                              child: Text(item),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Head Of User Search Selector
                    (() {
                      final selectedUser = users.cast<UserModel?>().firstWhere(
                        (u) => u?.email == _headOfEmail,
                        orElse: () => null,
                      );
                      return GestureDetector(
                        onTap: () => _showHeadOfSelectionModal(users),
                        child: AbsorbPointer(
                          child: TextField(
                            key: const Key('org_create_head_dropdown'),
                            controller: TextEditingController(
                              text: selectedUser != null
                                  ? '${selectedUser.fullName} (${selectedUser.email})'
                                  : 'None',
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Head Of',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.arrow_drop_down),
                            ),
                          ),
                        ),
                      );
                    })(),
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        key: const Key('org_create_error_text'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
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
    final hoverColor = theme.colorScheme.secondary;

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
