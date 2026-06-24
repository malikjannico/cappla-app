import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/router_paths.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../models/user_model.dart';
import '../../../models/org_unit_model.dart';

final usersStreamProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  return ref.watch(databaseServiceProvider).watchUsers();
});

class UserAdminListView extends ConsumerStatefulWidget {
  const UserAdminListView({super.key});

  @override
  ConsumerState<UserAdminListView> createState() => _UserAdminListViewState();
}

class _UserAdminListViewState extends ConsumerState<UserAdminListView> {
  final _searchController = TextEditingController();
  final _fullnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _searchQuery = '';
  String? _statusFilter;
  String? _roleFilter;
  String? _orgFilter;
  int _currentPage = 1;


  @override
  void dispose() {
    _searchController.dispose();
    _fullnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Register dependency on GoRouterState to trigger rebuild on navigation transitions
    GoRouterState.of(context);

    final showDetailedUserCreate = ref.watch(
      showDetailedUserCreateFormProvider,
    );
    if (showDetailedUserCreate) {
      Future.microtask(() {
        if (context.mounted) {
          final loc = GoRouterState.of(context).matchedLocation;
          if (loc != RouterPaths.adminUserNew) {
            context.go(RouterPaths.adminUserNew);
          }
        }
      });
    }

    final usersAsync = ref.watch(usersStreamProvider);
    final allUsers = usersAsync.value ?? [];
    final orgUnitAsync = ref.watch(orgUnitsStreamProvider);
    final allOrgsList = orgUnitAsync.value ?? [];

    // Filter Logic
    var filteredUsers = allUsers.where((u) {
      if (_searchQuery.isNotEmpty) {
        final escaped = RegExp.escape(_searchQuery);
        final regex = RegExp(escaped, caseSensitive: false);
        if (!regex.hasMatch(u.fullName) && !regex.hasMatch(u.email)) {
          return false;
        }
      }
      if (_statusFilter != null && u.status != _statusFilter) return false;
      if (_roleFilter != null && u.role != _roleFilter) return false;
      if (_orgFilter != null && u.orgUnitId != _orgFilter) return false;
      return true;
    }).toList();

    // Pagination (items per page = 5)
    final totalUsers = filteredUsers.length;
    const itemsPerPage = 5;
    final maxPage = (totalUsers / itemsPerPage).ceil().clamp(1, 9999);

    // Clamp current page to make sure we don't end up on an invalid page after filters change
    if (_currentPage > maxPage) {
      _currentPage = maxPage;
    }

    final displayedUsers = filteredUsers
        .skip((_currentPage - 1) * itemsPerPage)
        .take(itemsPerPage)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Text(
            'Users',
            key: const Key('user_admin_title'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // Search & Create Button Row
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  key: const Key('user_search_input'),
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search Users',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      key: const Key('user_search_button'),
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        setState(() {
                          _searchQuery = _searchController.text;
                          _currentPage = 1;
                        });
                      },
                    ),
                  ),
                  onSubmitted: (val) {
                    setState(() {
                      _searchQuery = val;
                      _currentPage = 1;
                    });
                  },
                ),
              ),
              FilledButton.icon(
                key: const Key('new_user_button'),
                onPressed: () {
                  context.go(RouterPaths.adminUserNew);
                },
                icon: const Icon(Icons.add),
                label: const Text('Create User'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Filters & Pagination Row
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  MenuAnchor(
                    builder: (context, controller, child) {
                      final bool isSelected = _statusFilter != null;
                      return FilterChip(
                        key: const Key('filter_status_dropdown'),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _statusFilter ?? 'Status',
                              style: TextStyle(
                                color: isSelected ? Colors.white : null,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color: isSelected ? Colors.white : null,
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
                        key: const Key('filter_status_all_item'),
                        onPressed: () => setState(() => _statusFilter = null),
                        child: const Text('All'),
                      ),
                      MenuItemButton(
                        key: const Key('filter_status_active_item'),
                        onPressed: () =>
                            setState(() => _statusFilter = 'Active'),
                        child: const Text('Active'),
                      ),
                      MenuItemButton(
                        key: const Key('filter_status_inactive_item'),
                        onPressed: () =>
                            setState(() => _statusFilter = 'Inactive'),
                        child: const Text('Inactive'),
                      ),
                    ],
                  ),
                  MenuAnchor(
                    builder: (context, controller, child) {
                      String roleLabel = 'Role';
                      if (_roleFilter == 'Administrator') roleLabel = 'Admin';
                      if (_roleFilter == 'User') roleLabel = 'User';
                      final bool isSelected = _roleFilter != null;
                      return FilterChip(
                        key: const Key('filter_role_dropdown'),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              roleLabel,
                              style: TextStyle(
                                color: isSelected ? Colors.white : null,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color: isSelected ? Colors.white : null,
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
                        key: const Key('filter_role_all_item'),
                        onPressed: () => setState(() => _roleFilter = null),
                        child: const Text('All'),
                      ),
                      MenuItemButton(
                        key: const Key('filter_role_admin_item'),
                        onPressed: () =>
                            setState(() => _roleFilter = 'Administrator'),
                        child: const Text('Admin'),
                      ),
                      MenuItemButton(
                        key: const Key('filter_role_user_item'),
                        onPressed: () => setState(() => _roleFilter = 'User'),
                        child: const Text('User'),
                      ),
                    ],
                  ),
                  MenuAnchor(
                    builder: (context, controller, child) {
                      final orgUnitAsync = ref.watch(orgUnitsStreamProvider);
                      final allOrgsList = orgUnitAsync.value ?? [];
                      final orgUnit = allOrgsList
                          .cast<OrgUnitModel?>()
                          .firstWhere(
                            (o) => o?.id == _orgFilter,
                            orElse: () => null,
                          );
                      final orgLabel = orgUnit != null
                          ? orgUnit.abbreviation
                          : 'Org Unit';
                      final bool isSelected = _orgFilter != null;
                      return FilterChip(
                        key: const Key('filter_org_unit_dropdown'),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              orgLabel,
                              style: TextStyle(
                                color: isSelected ? Colors.white : null,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color: isSelected ? Colors.white : null,
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
                        key: const Key('filter_org_all_item'),
                        onPressed: () => setState(() => _orgFilter = null),
                        child: const Text('All'),
                      ),
                      MenuItemButton(
                        key: const Key('filter_org_md_item'),
                        onPressed: () => setState(() => _orgFilter = 'MD_DIV'),
                        child: const Text('MD Division'),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    totalUsers == 0
                        ? '0 of 0'
                        : '${(_currentPage - 1) * 5 + 1}-${((_currentPage * 5) > totalUsers) ? totalUsers : (_currentPage * 5)} of $totalUsers',
                    key: const Key('user_pagination_displayed_count'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    key: const Key('user_page_back'),
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 1
                        ? () => setState(() => _currentPage--)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  PageIndicatorInput(
                    currentPage: _currentPage,
                    maxPage: maxPage,
                    onPageChanged: (page) =>
                        setState(() => _currentPage = page),
                    inputKey: const Key('user_pagination_pages_input'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '/ $maxPage',
                    key: const Key('user_pagination_pages'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('user_page_forward'),
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < maxPage
                        ? () => setState(() => _currentPage++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Table
          Column(
            children: [
              Container(
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
                  vertical: 12,
                  horizontal: 16,
                ),
                child: Row(
                  children: const [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Full Name',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Email',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Role',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Title',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Org Unit',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 180),
                  ],
                ),
              ),
              if (usersAsync.value == null && usersAsync.isLoading)
                _buildTableSkeleton(theme)
              else if (displayedUsers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: const Center(child: Text('No users found.')),
                )
              else
                ListView.builder(
                  key: const Key('user_table'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayedUsers.length,
                  itemBuilder: (context, idx) {
                    final user = displayedUsers[idx];
                    return InkWell(
                      key: Key('user_row_${user.email}'),
                      onTap: () {
                        ref
                                .read(selectedUserForDetailsProvider.notifier)
                                .state =
                            user;
                        context.go(RouterPaths.adminUserDetailPath(user.id));
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: idx == displayedUsers.length - 1
                                ? BorderSide.none
                                : BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 0.5,
                                  ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text(user.fullName)),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _buildStatusChip(
                                  user.status,
                                  theme,
                                  context,
                                ),
                              ),
                            ),
                            Expanded(flex: 4, child: Text(user.email)),
                            Expanded(flex: 2, child: Text(user.role)),
                            Expanded(flex: 2, child: Text(user.title)),
                            Expanded(
                              flex: 2,
                              child: Text(
                                allOrgsList
                                        .cast<OrgUnitModel?>()
                                        .firstWhere(
                                          (o) => o?.id == user.orgUnitId,
                                          orElse: () => null,
                                        )
                                        ?.name ??
                                    'None',
                              ),
                            ),
                            SizedBox(
                              width: 180,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  FilledButton(
                                    key: Key(
                                      'user_row_edit_button_${user.email}',
                                    ),
                                    onPressed: () {
                                      ref
                                              .read(
                                                selectedUserForDetailsProvider
                                                    .notifier,
                                              )
                                              .state =
                                          user;
                                      context.go(
                                        RouterPaths.adminUserEditPath(user.id),
                                      );
                                    },
                                    child: const Text('Edit'),
                                  ),
                                  const SizedBox(width: 8),
                                  Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: MenuAnchor(
                                      key: Key(
                                        'user_row_overflow_button_${user.email}',
                                      ),
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
                                            key: Key(
                                              'user_row_toggle_status_item_${user.email}',
                                            ),
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
                                                      lastModifiedAt:
                                                          DateTime.now(),
                                                    ),
                                                  );
                                              if (user.email ==
                                                  ref
                                                      .read(currentUserProvider)
                                                      ?.email) {
                                                final updated = await ref
                                                    .read(
                                                      databaseServiceProvider,
                                                    )
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
                                            key: Key(
                                              'user_row_reset_password_item_${user.email}',
                                            ),
                                            onPressed: () async {
                                              final db = ref.read(databaseServiceProvider);
                                              if (!db.toString().contains('Mock')) {
                                                final baseUrl = Uri.base.origin;
                                                await FirebaseFirestore.instance
                                                    .collection('adminPasswordResetRequests')
                                                    .doc(user.email.trim().toLowerCase())
                                                    .set({
                                                  'baseUrl': baseUrl,
                                                  'createdAt': FieldValue.serverTimestamp(),
                                                });
                                              } else {
                                                await ref
                                                    .read(authServiceProvider)
                                                    .sendPasswordResetEmail(
                                                      email: user.email,
                                                    );
                                              }
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
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    String status,
    ThemeData theme,
    BuildContext context,
  ) {
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
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
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

  Widget _buildTableSkeleton(ThemeData theme) {
    return Column(
      children: List.generate(3, (index) {
        return Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.primary,
                width: 0.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              Container(
                width: 80,
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      }),
    );
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
