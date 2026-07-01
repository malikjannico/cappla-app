// File: lib/core/router/router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'router_paths.dart';
import 'router_guards.dart';
import '../providers/providers.dart';
import '../../models/org_unit_model.dart';

// View Imports
import '../../views/login/login_view.dart';
import '../../views/login/reset_password_view.dart';
import '../../views/layout/layout.dart';
import '../../views/profile/profile_view.dart';
import '../../views/standard/planning_view.dart';
import '../../views/standard/reports_view.dart';
import '../../views/standard/dashboards_view.dart';
import '../../views/standard/settings/activity_groups_list_view.dart';
import '../../views/standard/settings/activity_group_create_view.dart';
import '../../views/standard/settings/activity_group_detail_view.dart';
import '../../views/standard/settings/activity_group_edit_view.dart';
import '../../views/standard/settings/activity_create_view.dart';
import '../../views/standard/settings/activity_detail_view.dart';
import '../../views/standard/settings/activity_edit_view.dart';
import '../../views/standard/settings/categories_list_view.dart';
import '../../views/standard/settings/category_create_view.dart';
import '../../views/standard/settings/category_detail_view.dart';
import '../../views/standard/settings/category_edit_view.dart';
import '../../views/standard/no_org_unit_view.dart';
import '../../views/admin/user_admin/user_admin_list_view.dart';
import '../../views/admin/user_admin/user_admin_create_view.dart';
import '../../views/admin/user_admin/user_admin_detail_view.dart';
import '../../views/admin/org_admin/org_admin_list_view.dart';
import '../../views/admin/org_admin/org_admin_create_view.dart';
import '../../views/admin/org_admin/org_admin_detail_view.dart';

part 'router.g.dart';

// Dummy NotFoundView for unknown route paths
class NotFoundView extends StatelessWidget {
  const NotFoundView({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('404 - Page Not Found')));
  }
}

// Notifier that triggers navigation on auth state transitions
class RouterTransitionNotifier extends ChangeNotifier {
  RouterTransitionNotifier(Ref ref) {
    ref.listen<UserModel?>(currentUserProvider, (previous, next) {
      debugPrint('RouterTransitionNotifier: currentUserProvider changed next=${next?.email}');
      if (next == null || next.status == 'Inactive') {
        final authService = ref.read(authServiceProvider);
        if (authService.hasCurrentUser) {
          authService.signOut();
        }
      }
      notifyListeners();
    });
    ref.listen<OrgUnitModel?>(userOwnedOrgUnitProvider, (previous, next) {
      debugPrint('RouterTransitionNotifier: userOwnedOrgUnitProvider changed');
      notifyListeners();
    });
    ref.listen<OrgUnitModel?>(userOrgUnitProvider, (previous, next) {
      debugPrint('RouterTransitionNotifier: userOrgUnitProvider changed');
      notifyListeners();
    });
    ref.listen(authStateSyncProvider, (previous, next) {
      debugPrint('RouterTransitionNotifier: authStateSyncProvider changed next=${next.value?.email}');
      notifyListeners();
    });
  }
}

final routerTransitionNotifierProvider = Provider(
  (ref) => RouterTransitionNotifier(ref),
);

class RiverpodAuthState implements AuthStateInterface {
  final UserModel? user;
  final List<OrgUnitModel> allOrgs;
  @override
  final bool isOrgUnitsLoading;
  final bool isAuthUserNull;

  RiverpodAuthState(
    this.user,
    this.allOrgs, {
    this.isOrgUnitsLoading = false,
    required this.isAuthUserNull,
  });

  @override
  bool get isAuthenticated => user != null && !isAuthUserNull;

  @override
  UserProfile? get currentUser {
    if (user == null || isAuthUserNull) return null;
    final isHead = allOrgs.any(
      (o) =>
          o.headOfEmail.trim().toLowerCase() ==
          user!.email.trim().toLowerCase(),
    );
    return UserProfile(
      email: user!.email,
      role: user!.role,
      status: user!.status,
      orgUnitId: user!.orgUnitId,
      isHeadOfOrg: isHead,
    );
  }

  @override
  bool isOrgUnitActive(String orgUnitId) {
    try {
      final org = allOrgs.firstWhere((o) => o.id == orgUnitId);
      return org.status == 'Active';
    } catch (_) {
      return false;
    }
  }
}

// =========================================================================
// GO ROUTER BUILDER TYPED ROUTE DEFINITIONS
// =========================================================================

@TypedGoRoute<LoginRoute>(path: '/login')
class LoginRoute extends GoRouteData {
  const LoginRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => LoginView(key: state.pageKey);
}

@TypedGoRoute<ResetPasswordRoute>(path: '/reset-password')
class ResetPasswordRoute extends GoRouteData {
  final String? email;
  final bool? trigger;

  const ResetPasswordRoute({this.email, this.trigger});

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final triggerVal = trigger ?? false;
    return ResetPasswordView(email: email ?? '', triggerCode: triggerVal);
  }
}

@TypedShellRoute<AppShellRouteData>(
  routes: <TypedRoute<GoRouteData>>[
    TypedGoRoute<HomeRoute>(path: '/'),
    TypedGoRoute<PlanningRoute>(
      path: '/plan',
      routes: [
        TypedGoRoute<PlanActivitiesRoute>(path: 'activities'),
        TypedGoRoute<PlanEmployeesRoute>(path: 'employees'),
      ],
    ),
    TypedGoRoute<ReportsRoute>(path: '/reports'),
    TypedGoRoute<DashboardsRoute>(path: '/dashboards'),
    TypedGoRoute<SettingsRoute>(
      path: '/settings',
      routes: [
        TypedGoRoute<SettingsActivityGroupsRoute>(
          path: 'activitygroups',
          routes: [
            TypedGoRoute<SettingsActivityGroupsNewRoute>(path: 'new'),
            TypedGoRoute<SettingsActivityGroupsDetailRoute>(
              path: ':id',
              routes: [
                TypedGoRoute<SettingsActivityGroupsEditRoute>(path: 'edit'),
                TypedGoRoute<SettingsActivitiesNewRoute>(path: 'activities/new'),
                TypedGoRoute<SettingsActivitiesDetailRoute>(
                  path: 'activities/:activityId',
                  routes: [
                    TypedGoRoute<SettingsActivitiesEditRoute>(path: 'edit'),
                  ],
                ),
              ],
            ),
          ],
        ),
        TypedGoRoute<SettingsCategoriesRoute>(
          path: 'categories',
          routes: [
            TypedGoRoute<SettingsCategoriesNewRoute>(path: 'new'),
            TypedGoRoute<SettingsCategoriesDetailRoute>(
              path: ':id',
              routes: [
                TypedGoRoute<SettingsCategoriesEditRoute>(path: 'edit'),
              ],
            ),
          ],
        ),
      ],
    ),
    TypedGoRoute<ProfileRoute>(
      path: '/profile',
      routes: [
        TypedGoRoute<ProfileEditRoute>(path: 'edit'),
      ],
    ),
    TypedGoRoute<AdminUsersRoute>(
      path: '/admin/users',
      routes: [
        TypedGoRoute<AdminUserNewRoute>(path: 'new'),
        TypedGoRoute<AdminUserDetailRoute>(
          path: ':id',
          routes: [
            TypedGoRoute<AdminUserEditRoute>(path: 'edit'),
          ],
        ),
      ],
    ),
    TypedGoRoute<AdminOrgsRoute>(
      path: '/admin/orgs',
      routes: [
        TypedGoRoute<AdminOrgNewRoute>(path: 'new'),
        TypedGoRoute<AdminOrgDetailRoute>(
          path: ':id',
          routes: [
            TypedGoRoute<AdminOrgEditRoute>(path: 'edit'),
          ],
        ),
      ],
    ),
  ],
)
class AppShellRouteData extends ShellRouteData {
  const AppShellRouteData();

  @override
  Widget builder(BuildContext context, GoRouterState state, Widget navigator) {
    return AppShellLayout(child: navigator);
  }
}

class HomeRoute extends GoRouteData {
  const HomeRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const NoOrgUnitView();
}

class PlanningRoute extends GoRouteData {
  const PlanningRoute();
  @override
  String? redirect(BuildContext context, GoRouterState state) {
    if (state.uri.path == '/plan') {
      return '/plan/activities';
    }
    return null;
  }
  @override
  Widget build(BuildContext context, GoRouterState state) => const SizedBox.shrink();
}

class PlanActivitiesRoute extends GoRouteData {
  const PlanActivitiesRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const PlanningView(viewType: 'activity');
}

class PlanEmployeesRoute extends GoRouteData {
  const PlanEmployeesRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const PlanningView(viewType: 'employee');
}

class ReportsRoute extends GoRouteData {
  const ReportsRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const ReportsView();
}

class DashboardsRoute extends GoRouteData {
  const DashboardsRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const DashboardsView();
}

class SettingsRoute extends GoRouteData {
  const SettingsRoute();
  @override
  String? redirect(BuildContext context, GoRouterState state) {
    if (state.uri.path == '/settings') {
      return '/settings/activitygroups';
    }
    return null;
  }
  @override
  Widget build(BuildContext context, GoRouterState state) => const SizedBox.shrink();
}

class SettingsActivityGroupsRoute extends GoRouteData {
  const SettingsActivityGroupsRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const ActivityGroupsListView();
}

class SettingsActivityGroupsNewRoute extends GoRouteData {
  const SettingsActivityGroupsNewRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const ActivityGroupCreateView();
}

class SettingsActivityGroupsDetailRoute extends GoRouteData {
  final String id;
  const SettingsActivityGroupsDetailRoute({required this.id});
  @override
  Widget build(BuildContext context, GoRouterState state) => ActivityGroupDetailView(id: id);
}

class SettingsActivityGroupsEditRoute extends GoRouteData {
  final String id;
  const SettingsActivityGroupsEditRoute({required this.id});
  @override
  Widget build(BuildContext context, GoRouterState state) => ActivityGroupEditView(id: id);
}

class SettingsActivitiesNewRoute extends GoRouteData {
  final String id;
  const SettingsActivitiesNewRoute({required this.id});
  @override
  Widget build(BuildContext context, GoRouterState state) => ActivityCreateView(activityGroupId: id);
}

class SettingsActivitiesDetailRoute extends GoRouteData {
  final String id;
  final String activityId;
  const SettingsActivitiesDetailRoute({required this.id, required this.activityId});
  @override
  Widget build(BuildContext context, GoRouterState state) => ActivityDetailView(activityGroupId: id, activityId: activityId);
}

class SettingsActivitiesEditRoute extends GoRouteData {
  final String id;
  final String activityId;
  const SettingsActivitiesEditRoute({required this.id, required this.activityId});
  @override
  Widget build(BuildContext context, GoRouterState state) => ActivityEditView(activityGroupId: id, activityId: activityId);
}

class SettingsCategoriesRoute extends GoRouteData {
  const SettingsCategoriesRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const CategoriesListView();
}

class SettingsCategoriesNewRoute extends GoRouteData {
  const SettingsCategoriesNewRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const CategoryCreateView();
}

class SettingsCategoriesDetailRoute extends GoRouteData {
  final String id;
  const SettingsCategoriesDetailRoute({required this.id});
  @override
  Widget build(BuildContext context, GoRouterState state) => CategoryDetailView(id: id);
}

class SettingsCategoriesEditRoute extends GoRouteData {
  final String id;
  const SettingsCategoriesEditRoute({required this.id});
  @override
  Widget build(BuildContext context, GoRouterState state) => CategoryEditView(id: id);
}

class ProfileRoute extends GoRouteData {
  const ProfileRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const ProfileView();
}

class ProfileEditRoute extends GoRouteData {
  const ProfileEditRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const ProfileView();
}

class AdminUsersRoute extends GoRouteData {
  const AdminUsersRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const UserAdminListView();
}

class AdminUserNewRoute extends GoRouteData {
  const AdminUserNewRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const UserAdminCreateView();
}

class AdminUserDetailRoute extends GoRouteData {
  final String id;
  const AdminUserDetailRoute({required this.id});
  @override
  Widget build(BuildContext context, GoRouterState state) => UserAdminDetailView(id: id);
}

class AdminUserEditRoute extends GoRouteData {
  final String id;
  const AdminUserEditRoute({required this.id});
  @override
  Widget build(BuildContext context, GoRouterState state) => UserAdminDetailView(id: id);
}

class AdminOrgsRoute extends GoRouteData {
  const AdminOrgsRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const OrgAdminListView();
}

class AdminOrgNewRoute extends GoRouteData {
  const AdminOrgNewRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const OrgAdminCreateView();
}

class AdminOrgDetailRoute extends GoRouteData {
  final String id;
  const AdminOrgDetailRoute({required this.id});
  @override
  Widget build(BuildContext context, GoRouterState state) => OrgAdminDetailView(id: id);
}

class AdminOrgEditRoute extends GoRouteData {
  final String id;
  const AdminOrgEditRoute({required this.id});
  @override
  Widget build(BuildContext context, GoRouterState state) => OrgAdminDetailView(id: id);
}

// =========================================================================
// GO ROUTER GLOBAL CONFIGURATION PROVIDER
// =========================================================================

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = ref.watch(routerTransitionNotifierProvider);

  return GoRouter(
    initialLocation: RouterPaths.home,
    refreshListenable: listenable,
    routes: $appRoutes,
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final orgUnitsAsync = ref.read(orgUnitsStreamProvider);
      final allOrgs = orgUnitsAsync.value ?? <OrgUnitModel>[];
      final isOrgUnitsLoading = orgUnitsAsync.isLoading ||
          !orgUnitsAsync.hasValue;
      final auth = ref.read(firebaseAuthProvider);
      final isAuthUserNull = auth.currentUser == null;
      final authState = RiverpodAuthState(
        user,
        allOrgs,
        isOrgUnitsLoading: isOrgUnitsLoading,
        isAuthUserNull: isAuthUserNull,
      );
      return appRedirectGuard(context, state, authState);
    },
    errorBuilder: (context, state) => const NotFoundView(),
  );
});
