import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/providers.dart';
import '../../core/router/router_paths.dart';
import '../../models/org_unit_model.dart';
import '../login/vetter_logo.dart';

class AppShellLayout extends ConsumerStatefulWidget {
  final Widget child;
  const AppShellLayout({super.key, required this.child});

  @override
  ConsumerState<AppShellLayout> createState() => _AppShellLayoutState();
}

class _AppShellLayoutState extends ConsumerState<AppShellLayout> {
  @override
  Widget build(BuildContext context) {
    final selectedCollection = ref.watch(selectedTabCollectionProvider);
    final userRole = ref.watch(currentUserProvider.select((u) => u?.role));
    final userOrgUnitId = ref.watch(
      currentUserProvider.select((u) => u?.orgUnitId),
    );
    final userFullName = ref.watch(
      currentUserProvider.select((u) => u?.fullName ?? ''),
    );
    final userEmail = ref.watch(
      currentUserProvider.select((u) => u?.email ?? ''),
    );
    final allOrgs = ref.watch(orgUnitsStreamProvider).value ?? <OrgUnitModel>[];
    final hasOrgUnit =
        userOrgUnitId != null &&
        userOrgUnitId.isNotEmpty &&
        allOrgs.any((o) => o.id == userOrgUnitId && o.status == 'Active');
    final isHeadOfOrg = ref.watch(
      userOwnedOrgUnitProvider.select((org) => org != null),
    );

    if (userRole != 'Administrator' && selectedCollection == 'Administration') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(selectedTabCollectionProvider.notifier).state = 'Standard';
        }
      });
    }

    final dropdownValue = (userRole == 'Administrator')
        ? selectedCollection
        : 'Standard';

    final routerState = GoRouterState.of(context);
    final location = routerState.matchedLocation;

    // Automatically synchronize state providers based on navigation route changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (location == RouterPaths.home ||
          location.startsWith('/plan') ||
          location.startsWith('/reports') ||
          location.startsWith('/dashboards') ||
          location.startsWith('/settings')) {
        if (ref.read(selectedTabCollectionProvider) != 'Standard') {
          ref.read(selectedTabCollectionProvider.notifier).state = 'Standard';
        }
      } else if (location.startsWith('/admin')) {
        if (ref.read(selectedTabCollectionProvider) != 'Administration') {
          ref.read(selectedTabCollectionProvider.notifier).state =
              'Administration';
        }
        if (location.startsWith(RouterPaths.adminUsers)) {
          if (ref.read(currentAdminRouteProvider) != 'users') {
            ref.read(currentAdminRouteProvider.notifier).state = 'users';
          }
        } else if (location.startsWith(RouterPaths.adminOrgs)) {
          if (ref.read(currentAdminRouteProvider) != 'orgs') {
            ref.read(currentAdminRouteProvider.notifier).state = 'orgs';
          }
        }
      }
    });

    // Automatically navigate when state providers change directly
    ref.listen<String>(selectedTabCollectionProvider, (previous, next) {
      final loc = GoRouterState.of(context).matchedLocation;
      if (next == 'Standard') {
        if (!loc.startsWith('/plan') &&
            !loc.startsWith('/reports') &&
            !loc.startsWith('/dashboards') &&
            !loc.startsWith('/settings')) {
          if (hasOrgUnit) {
            context.go(RouterPaths.planActivities);
          } else {
            context.go(RouterPaths.home);
          }
        }
      } else if (next == 'Administration') {
        final adminRoute = ref.read(currentAdminRouteProvider);
        if (adminRoute == 'users') {
          if (!loc.startsWith(RouterPaths.adminUsers)) {
            context.go(RouterPaths.adminUsers);
          }
        } else {
          if (!loc.startsWith(RouterPaths.adminOrgs)) {
            context.go(RouterPaths.adminOrgs);
          }
        }
      }
    });

    ref.listen<String>(currentAdminRouteProvider, (previous, next) {
      final collection = ref.read(selectedTabCollectionProvider);
      final loc = GoRouterState.of(context).matchedLocation;
      if (collection == 'Administration') {
        if (next == 'users') {
          if (!loc.startsWith(RouterPaths.adminUsers)) {
            context.go(RouterPaths.adminUsers);
          }
        } else {
          if (!loc.startsWith(RouterPaths.adminOrgs)) {
            context.go(RouterPaths.adminOrgs);
          }
        }
      }
    });

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        scrolledUnderElevation: 0,
        elevation: 0,
        shape: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
        leadingWidth: 300,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (userRole == 'Administrator')
                    MenuAnchor(
                      alignmentOffset: const Offset(0, 4),
                      builder:
                          (
                            BuildContext context,
                            MenuController controller,
                            Widget? child,
                          ) {
                            final isStandard = dropdownValue == 'Standard';
                            bool isHovered = false;
                            return StatefulBuilder(
                              builder: (context, setStateBuilder) {
                                return IconButton(
                                  key: const Key('tab_collection_dropdown'),
                                  onPressed: () {
                                    if (controller.isOpen) {
                                      controller.close();
                                    } else {
                                      controller.open();
                                    }
                                  },
                                  onHover: (hovering) {
                                    setStateBuilder(() {
                                      isHovered = hovering;
                                    });
                                  },
                                  icon: Icon(
                                    isStandard ? Icons.apps : Icons.settings,
                                    color: isHovered
                                        ? theme.colorScheme.onSurfaceVariant
                                        : theme.colorScheme.primary,
                                    size: 28,
                                  ),
                                );
                              },
                            );
                          },
                      menuChildren: [
                        MenuItemButton(
                          child: const Text('Standard'),
                          onPressed: () {
                            ref
                                    .read(
                                      selectedTabCollectionProvider.notifier,
                                    )
                                    .state =
                                'Standard';
                            if (hasOrgUnit) {
                              context.go(RouterPaths.planning);
                            } else {
                              context.go(RouterPaths.home);
                            }
                          },
                        ),
                        MenuItemButton(
                          child: const Text('Administration'),
                          onPressed: () {
                            ref
                                    .read(
                                      selectedTabCollectionProvider.notifier,
                                    )
                                    .state =
                                'Administration';
                            final adminRoute = ref.read(
                              currentAdminRouteProvider,
                            );
                            if (adminRoute == 'users') {
                              context.go(RouterPaths.adminUsers);
                            } else {
                              context.go(RouterPaths.adminOrgs);
                            }
                          },
                        ),
                      ],
                    )
                  else if (userRole == 'Administrator')
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.settings,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.apps,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Cappla',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (dropdownValue != 'Standard')
                          TextSpan(
                            text: ' Admin',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.normal,
                              letterSpacing: 1.2,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    key: const Key('app_title'),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ],
              ),
            ),
          ),
        ),
        title: (!location.startsWith('/admin') && hasOrgUnit)
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      key: const Key('nav_planning'),
                      onPressed: () => context.go(RouterPaths.planActivities),
                      style: TextButton.styleFrom(
                        foregroundColor: (location.startsWith('/plan'))
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary,
                        textStyle: TextStyle(
                          fontWeight: (location.startsWith('/plan'))
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      child: const Text('Plan'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      key: const Key('nav_reports_dashboard'),
                      onPressed: () => context.go(RouterPaths.reports),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            (location.startsWith('/reports') ||
                                location.startsWith('/dashboards'))
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary,
                        textStyle: TextStyle(
                          fontWeight:
                              (location.startsWith('/reports') ||
                                  location.startsWith('/dashboards'))
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      child: const Text('Reports & Dashboard'),
                    ),
                    if (isHeadOfOrg) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        key: const Key('nav_settings'),
                        onPressed: () =>
                            context.go(RouterPaths.settingsActivityGroups),
                        style: TextButton.styleFrom(
                          foregroundColor: (location.startsWith('/settings'))
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary,
                          textStyle: TextStyle(
                            fontWeight: (location.startsWith('/settings'))
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        child: const Text('Settings'),
                      ),
                    ],
                  ],
                ),
              )
            : null,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: MenuAnchor(
                builder:
                    (
                      BuildContext context,
                      MenuController controller,
                      Widget? child,
                    ) {
                      return IconButton(
                        key: const Key('profile_dropdown_button'),
                        onPressed: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        icon: CircleAvatar(
                          child: Text(
                            userFullName.isNotEmpty == true
                                ? userFullName.substring(0, 1)
                                : '?',
                          ),
                        ),
                      );
                    },
                menuChildren: [
                  // Display current user name and email in dropdown header (disabled item)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: MenuItemButton(
                      onPressed: null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userFullName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userEmail.replaceAllMapped(
                                RegExp(r'([@._\-])'),
                                (m) => '${m.group(0)}\u{200B}',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: MenuItemButton(
                      key: const Key('profile_menu_item_profile'),
                      onPressed: () {
                        context.go(RouterPaths.profile);
                      },
                      child: const Text('My Profile'),
                    ),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: MenuItemButton(
                      key: const Key('profile_menu_item_logout'),
                      onPressed: () async {
                        await ref.read(authServiceProvider).signOut();
                        ref.read(currentUserProvider.notifier).state = null;
                        if (context.mounted) {
                          context.go(RouterPaths.login);
                        }
                      },
                      child: const Text('Logout'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: location.startsWith('/admin')
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RepaintBoundary(
                  child: SizedBox(
                    width: 256,
                    child: Container(
                      color: const Color(0xFFFFFFFF),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          _SidebarItem(
                            label: 'Users',
                            textKey: const Key('nav_rail_users'),
                            isSelected: location.startsWith(
                              RouterPaths.adminUsers,
                            ),
                            onTap: () {
                              ref
                                      .read(currentAdminRouteProvider.notifier)
                                      .state =
                                  'users';
                              context.go(RouterPaths.adminUsers);
                            },
                          ),
                          _SidebarItem(
                            label: 'Organization Units',
                            textKey: const Key('nav_rail_orgs'),
                            isSelected: location.startsWith(
                              RouterPaths.adminOrgs,
                            ),
                            onTap: () {
                              ref
                                      .read(currentAdminRouteProvider.notifier)
                                      .state =
                                  'orgs';
                              context.go(RouterPaths.adminOrgs);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                VerticalDivider(
                  thickness: 0.5,
                  width: 0.5,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(child: RepaintBoundary(child: widget.child)),
              ],
            )
          : location.startsWith('/settings')
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RepaintBoundary(
                  child: SizedBox(
                    width: 256,
                    child: Container(
                      color: const Color(0xFFFFFFFF),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          _SidebarItem(
                            label: 'Activities',
                            textKey: const Key('nav_rail_activities'),
                            isSelected:
                                location.contains('acitivitygroups') ||
                                location.contains('activities'),
                            onTap: () {
                              context.go(RouterPaths.settingsActivityGroups);
                            },
                          ),
                          _SidebarItem(
                            label: 'Categories',
                            textKey: const Key('nav_rail_categories'),
                            isSelected: location.contains('categories'),
                            onTap: () {
                              context.go(RouterPaths.settingsCategories);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                VerticalDivider(
                  thickness: 0.5,
                  width: 0.5,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(child: RepaintBoundary(child: widget.child)),
              ],
            )
          : RepaintBoundary(child: widget.child),
      bottomNavigationBar: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Powered by ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const VetterLogo(size: 12),
                const SizedBox(width: 4),
                const Text(
                  'Vetter',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Expanded(
              child: Text(
                'Copyright © ${DateTime.now().year} Vetter Pharma-Fertigung GmbH & Co. KG. All rights reserved.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String label;
  final Key textKey;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.label,
    required this.textKey,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.secondary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 160,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                key: textKey,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
