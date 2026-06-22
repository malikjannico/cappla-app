import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/router_paths.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../models/user_model.dart';
import '../user_admin/user_admin_list_view.dart';
import 'org_detail_view.dart';

class OrgAdminView extends ConsumerStatefulWidget {
  const OrgAdminView({super.key});

  @override
  ConsumerState<OrgAdminView> createState() => _OrgAdminViewState();
}

class _OrgAdminViewState extends ConsumerState<OrgAdminView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;
  String? _typeFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTypeName(String type) {
    if (type.isEmpty) return '';
    return type
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          if (word == 'md' || word == 'svp' || word == 'vp') {
            return word.toUpperCase();
          }
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Register dependency on GoRouterState to trigger rebuild on navigation transitions
    GoRouterState.of(context);
    final orgsAsync = ref.watch(orgUnitsStreamProvider);
    final allOrgs = orgsAsync.value ?? [];
    final usersAsync = ref.watch(usersStreamProvider);
    final allUsers = usersAsync.value ?? [];

    // Filter logic: search query, type filter, and show all units (root and child)
    var filteredOrgs = allOrgs.where((o) {
      if (_typeFilter != null && o.type != _typeFilter) return false;
      if (_searchQuery.isNotEmpty &&
          !o.name.toLowerCase().contains(_searchQuery.toLowerCase()) &&
          !o.abbreviation.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    // Pagination
    final totalOrgs = filteredOrgs.length;
    const itemsPerPage = 5;
    final maxPage = (totalOrgs / itemsPerPage).ceil().clamp(1, 9999);

    if (_currentPage > maxPage) {
      _currentPage = maxPage;
    }

    final displayedOrgs = filteredOrgs
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
            'Organization Units',
            key: const Key('org_admin_title'),
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
                  key: const Key('org_search_input'),
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search Org Units',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      key: const Key('org_search_button'),
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
                key: const Key('create_org_button'),
                onPressed: () {
                  context.go(RouterPaths.adminOrgNew);
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Org'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Filters & Pagination Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MenuAnchor(
                builder: (context, controller, child) {
                  final bool isSelected = _typeFilter != null;
                  return FilterChip(
                    key: const Key('filter_type_dropdown'),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _typeFilter != null
                              ? _formatTypeName(_typeFilter!)
                              : 'Type',
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
                    key: const Key('filter_type_all_item'),
                    onPressed: () => setState(() {
                      _typeFilter = null;
                      _currentPage = 1;
                    }),
                    child: const Text('All'),
                  ),
                  MenuItemButton(
                    key: const Key('filter_type_md_item'),
                    onPressed: () => setState(() {
                      _typeFilter = 'md division';
                      _currentPage = 1;
                    }),
                    child: const Text('MD Division'),
                  ),
                  MenuItemButton(
                    key: const Key('filter_type_svp_item'),
                    onPressed: () => setState(() {
                      _typeFilter = 'svp division';
                      _currentPage = 1;
                    }),
                    child: const Text('SVP Division'),
                  ),
                  MenuItemButton(
                    key: const Key('filter_type_vp_item'),
                    onPressed: () => setState(() {
                      _typeFilter = 'vp division';
                      _currentPage = 1;
                    }),
                    child: const Text('VP Division'),
                  ),
                  MenuItemButton(
                    key: const Key('filter_type_dept_item'),
                    onPressed: () => setState(() {
                      _typeFilter = 'department';
                      _currentPage = 1;
                    }),
                    child: const Text('Department'),
                  ),
                  MenuItemButton(
                    key: const Key('filter_type_group_item'),
                    onPressed: () => setState(() {
                      _typeFilter = 'group';
                      _currentPage = 1;
                    }),
                    child: const Text('Group'),
                  ),
                  MenuItemButton(
                    key: const Key('filter_type_team_item'),
                    onPressed: () => setState(() {
                      _typeFilter = 'team';
                      _currentPage = 1;
                    }),
                    child: const Text('Team'),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    totalOrgs == 0
                        ? '0 of 0'
                        : '${(_currentPage - 1) * 5 + 1}-${((_currentPage * 5) > totalOrgs) ? totalOrgs : (_currentPage * 5)} of $totalOrgs',
                    key: const Key('org_pagination_displayed_count'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    key: const Key('org_page_back'),
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
                    inputKey: const Key('org_pagination_pages_input'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '/ $maxPage',
                    key: const Key('org_pagination_pages'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('org_page_forward'),
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
                        'Name',
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
                      flex: 2,
                      child: Text(
                        'Abbreviation',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Type',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Head of',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 180),
                  ],
                ),
              ),
              if (orgsAsync.value == null && orgsAsync.isLoading)
                _buildTableSkeleton(theme)
              else if (displayedOrgs.isEmpty)
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
                  child: const Center(
                    child: Text('No organization units found.'),
                  ),
                )
              else
                ListView.builder(
                  key: const Key('org_table'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayedOrgs.length,
                  itemBuilder: (context, idx) {
                    final org = displayedOrgs[idx];
                    return InkWell(
                      key: Key('org_row_${org.id}'),
                      onTap: () {
                        context.go(RouterPaths.adminOrgDetailPath(org.id));
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: idx == displayedOrgs.length - 1
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
                            Expanded(flex: 3, child: Text(org.name)),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _buildStatusChip(
                                  org.status,
                                  theme,
                                  context,
                                ),
                              ),
                            ),
                            Expanded(flex: 2, child: Text(org.abbreviation)),
                            Expanded(
                              flex: 2,
                              child: Text(formatOrgType(org.type)),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                (() {
                                  final u = allUsers
                                      .cast<UserModel?>()
                                      .firstWhere(
                                        (usr) => usr?.email == org.headOfEmail,
                                        orElse: () => null,
                                      );
                                  return u != null ? u.fullName : 'None';
                                })(),
                              ),
                            ),
                            SizedBox(
                              width: 180,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  FilledButton(
                                    key: Key('org_row_edit_button_${org.id}'),
                                    onPressed: () {
                                      context.go(
                                        RouterPaths.adminOrgEditPath(org.id),
                                      );
                                    },
                                    child: const Text('Edit'),
                                  ),
                                  const SizedBox(width: 8),
                                  Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: MenuAnchor(
                                      key: Key(
                                        'org_row_overflow_button_${org.id}',
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
                                              'org_row_toggle_status_item_${org.id}',
                                            ),
                                            onPressed: () async {
                                              final newStatus =
                                                  org.status == 'Active'
                                                  ? 'Inactive'
                                                  : 'Active';
                                              await ref
                                                  .read(databaseServiceProvider)
                                                  .saveOrgUnit(
                                                    org.copyWith(
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
                                            },
                                            child: Text(
                                              org.status == 'Active'
                                                  ? 'Deactivate'
                                                  : 'Active',
                                            ),
                                          ),
                                        ),
                                        Directionality(
                                          textDirection: TextDirection.ltr,
                                          child: MenuItemButton(
                                            key: Key(
                                              'org_row_delete_item_${org.id}',
                                            ),
                                            onPressed: () async {
                                              await ref
                                                  .read(databaseServiceProvider)
                                                  .deleteOrgUnit(org.id);
                                            },
                                            child: const Text('Delete'),
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
