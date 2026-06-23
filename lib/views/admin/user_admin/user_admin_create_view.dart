import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/router_paths.dart';
import '../../../models/user_model.dart';
import '../../../models/org_unit_model.dart';

class UserAdminCreateView extends ConsumerStatefulWidget {
  const UserAdminCreateView({super.key});

  @override
  ConsumerState<UserAdminCreateView> createState() =>
      _UserAdminCreateViewState();
}

class _UserAdminCreateViewState extends ConsumerState<UserAdminCreateView> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _titleController = TextEditingController();

  String _role = 'User';
  String? _orgUnitId;
  String _errorMessage = '';

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _clearFields() {
    _fullNameController.clear();
    _emailController.clear();
    _titleController.clear();
    setState(() {
      _role = 'User';
      _orgUnitId = null;
      _errorMessage = '';
    });
  }

  Future<bool> _saveUser() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final title = _titleController.text.trim();

    if (fullName.isEmpty) {
      setState(() => _errorMessage = 'Full Name is required.');
      return false;
    }
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Email is required.');
      return false;
    }

    try {
      final adminEmail = ref.read(currentUserProvider)?.email ?? 'system';
      final now = DateTime.now();
      final newUser = UserModel(
        id: const Uuid().v4(),
        fullName: fullName,
        email: email,
        title: title.isEmpty ? 'Specialist' : title,
        status: 'Active',
        role: _role,
        orgUnitId: _orgUnitId,
        createdBy: adminEmail,
        createdAt: now,
        lastModifiedBy: adminEmail,
        lastModifiedAt: now,
      );

      final tempPassword = '${const Uuid().v4()}Aa1!';
      await ref.read(authServiceProvider).createUser(newUser, tempPassword);

      final db = ref.read(databaseServiceProvider);
      if (!db.toString().contains('Mock')) {
        // Write request to trigger activation email
        final baseUrl = Uri.base.origin;
        await FirebaseFirestore.instance
            .collection('activationRequests')
            .doc(email.trim().toLowerCase())
            .set({
          'baseUrl': baseUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void _showOrgSelectionModal(List<OrgUnitModel> orgUnits) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String query = '';
        String? localSelectedId = _orgUnitId;
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
                      _orgUnitId = localSelectedId;
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
    final orgUnitsAsync = ref.watch(orgUnitsStreamProvider);
    final orgUnits = orgUnitsAsync.value ?? [];

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
                  label: 'Users',
                  onTap: () => context.go(RouterPaths.adminUsers),
                ),
                Text(
                  ' / New User',
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
                  'Create New User',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      key: const Key('user_create_cancel_button'),
                      onPressed: () {
                        ref
                                .read(
                                  showDetailedUserCreateFormProvider.notifier,
                                )
                                .state =
                            false;
                        context.go(RouterPaths.adminUsers);
                      },
                      child: const Text('Cancel'),
                    ),
                    OutlinedButton(
                      key: const Key('user_create_save_create_button'),
                      onPressed: () async {
                        final success = await _saveUser();
                        if (success) {
                          _clearFields();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('User created successfully.'),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Save & Create'),
                    ),
                    FilledButton(
                      key: const Key('create_user_button'),
                      onPressed: () async {
                        final success = await _saveUser();
                        if (success) {
                          ref
                                  .read(
                                    showDetailedUserCreateFormProvider.notifier,
                                  )
                                  .state =
                              false;
                          if (context.mounted) {
                            context.go(RouterPaths.adminUsers);
                          }
                        }
                      },
                      child: const Text('Create'),
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
                      key: const Key('user_create_fullname_input'),
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
                      key: const Key('user_create_email_input'),
                      controller: _emailController,
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
                      key: const Key('user_create_title_input'),
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Role Dropdown
                    MenuAnchor(
                      key: const Key('user_create_role_dropdown'),
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
                              _role,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        );
                      },
                      menuChildren: const ['Administrator', 'User'].map((item) {
                        return MenuItemButton(
                          onPressed: () => setState(() => _role = item),
                          child: Text(item),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Org Unit Search Selector
                    (() {
                      final selectedOrg = orgUnits
                          .cast<OrgUnitModel?>()
                          .firstWhere(
                            (o) => o?.id == _orgUnitId,
                            orElse: () => null,
                          );
                      return GestureDetector(
                        onTap: () => _showOrgSelectionModal(orgUnits),
                        child: AbsorbPointer(
                          child: TextField(
                            key: const Key('user_create_org_unit_dropdown'),
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
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        key: const Key('user_create_error_text'),
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
    final primaryColor = theme.colorScheme.onSurfaceVariant;
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
