import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'router_paths.dart';
import 'router_guards.dart';
import '../providers/providers.dart';
import '../../models/user_model.dart';
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
import '../../views/admin/org_admin/org_admin_view.dart';
import '../../views/admin/org_admin/org_admin_create_view.dart';
import '../../views/admin/org_admin/org_detail_view.dart';

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
      notifyListeners();
    });
    ref.listen<OrgUnitModel?>(userOwnedOrgUnitProvider, (previous, next) {
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
  RiverpodAuthState(this.user, this.allOrgs, {this.isOrgUnitsLoading = false});

  @override
  bool get isAuthenticated => user != null;

  @override
  UserProfile? get currentUser {
    if (user == null) return null;
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

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = ref.watch(routerTransitionNotifierProvider);

  return GoRouter(
    initialLocation: RouterPaths.home,
    refreshListenable: listenable,
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final orgUnitsAsync = ref.read(orgUnitsStreamProvider);
      final allOrgs = orgUnitsAsync.value ?? <OrgUnitModel>[];
      final isOrgUnitsLoading = orgUnitsAsync.isLoading ||
          !orgUnitsAsync.hasValue ||
          (user != null &&
              user.orgUnitId != null &&
              user.orgUnitId!.isNotEmpty &&
              allOrgs.isEmpty);
      final authState = RiverpodAuthState(
        user,
        allOrgs,
        isOrgUnitsLoading: isOrgUnitsLoading,
      );
      return appRedirectGuard(context, state, authState);
    },
    routes: [
      // Guest / Authentication routes outside of the global shell
      GoRoute(
        path: RouterPaths.login,
        name: RouterNames.login,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginView()),
      ),
      GoRoute(
        path: RouterPaths.resetPassword,
        name: RouterNames.resetPassword,
        pageBuilder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return NoTransitionPage(child: ResetPasswordView(email: email));
        },
      ),

      // Application Shell wrapping pages with top nav layout scaffold
      ShellRoute(
        builder: (context, state, child) {
          return AppShellLayout(child: child);
        },
        routes: [
          GoRoute(
            path: RouterPaths.home,
            name: RouterNames.home,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: NoOrgUnitView()),
          ),
          GoRoute(
            path: RouterPaths.planning,
            name: RouterNames.planning,
            redirect: (context, state) => RouterPaths.planActivities,
          ),
          GoRoute(
            path: RouterPaths.planActivities,
            name: RouterNames.planActivities,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PlanningView(viewType: 'activity'),
            ),
          ),
          GoRoute(
            path: RouterPaths.planEmployees,
            name: RouterNames.planEmployees,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PlanningView(viewType: 'employee'),
            ),
          ),
          GoRoute(
            path: RouterPaths.reports,
            name: RouterNames.reports,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReportsView()),
          ),
          GoRoute(
            path: RouterPaths.dashboards,
            name: RouterNames.dashboards,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardsView()),
          ),
          GoRoute(
            path: RouterPaths.settings,
            name: RouterNames.settings,
            redirect: (context, state) => RouterPaths.settingsActivityGroups,
          ),
          GoRoute(
            path: RouterPaths.settingsActivityGroups,
            name: RouterNames.settingsActivityGroups,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ActivityGroupsListView()),
            routes: [
              GoRoute(
                path: 'new',
                name: RouterNames.settingsActivityGroupsNew,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ActivityGroupCreateView()),
              ),
              GoRoute(
                path: ':id',
                name: RouterNames.settingsActivityGroupsDetail,
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return NoTransitionPage(
                    child: ActivityGroupDetailView(id: id),
                  );
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: RouterNames.settingsActivityGroupsEdit,
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return NoTransitionPage(
                        child: ActivityGroupEditView(id: id),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'activities/new',
                    name: RouterNames.settingsActivitiesNew,
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return NoTransitionPage(
                        child: ActivityCreateView(activityGroupId: id),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'activities/:activityId',
                    name: RouterNames.settingsActivitiesDetail,
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      final activityId =
                          state.pathParameters['activityId'] ?? '';
                      return NoTransitionPage(
                        child: ActivityDetailView(
                          activityGroupId: id,
                          activityId: activityId,
                        ),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        name: RouterNames.settingsActivitiesEdit,
                        pageBuilder: (context, state) {
                          final id = state.pathParameters['id'] ?? '';
                          final activityId =
                              state.pathParameters['activityId'] ?? '';
                          return NoTransitionPage(
                            child: ActivityEditView(
                              activityGroupId: id,
                              activityId: activityId,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: RouterPaths.settingsCategories,
            name: RouterNames.settingsCategories,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CategoriesListView()),
            routes: [
              GoRoute(
                path: 'new',
                name: RouterNames.settingsCategoriesNew,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: CategoryCreateView()),
              ),
              GoRoute(
                path: ':id',
                name: RouterNames.settingsCategoriesDetail,
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return NoTransitionPage(child: CategoryDetailView(id: id));
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: RouterNames.settingsCategoriesEdit,
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return NoTransitionPage(child: CategoryEditView(id: id));
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: RouterPaths.profile,
            name: RouterNames.profile,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfileView()),
            routes: [
              GoRoute(
                path: 'edit',
                name: RouterNames.profileEdit,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProfileView()),
              ),
            ],
          ),

          // Admin views with nested path structures
          GoRoute(
            path: RouterPaths.adminUsers,
            name: RouterNames.adminUsers,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: UserAdminListView()),
            routes: [
              GoRoute(
                path: 'new', // Evaluates to /admin/users/new
                name: RouterNames.adminUserNew,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: UserAdminCreateView()),
              ),
              GoRoute(
                path: ':id', // Evaluates to /admin/users/:id
                name: RouterNames.adminUserDetail,
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return NoTransitionPage(child: UserAdminDetailView(id: id));
                },
                routes: [
                  GoRoute(
                    path: 'edit', // Evaluates to /admin/users/:id/edit
                    name: RouterNames.adminUserEdit,
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return NoTransitionPage(
                        child: UserAdminDetailView(id: id),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: RouterPaths.adminOrgs,
            name: RouterNames.adminOrgs,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: OrgAdminView()),
            routes: [
              GoRoute(
                path: 'new', // Evaluates to /admin/orgs/new
                name: RouterNames.adminOrgNew,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: OrgAdminCreateView()),
              ),
              GoRoute(
                path: ':id', // Evaluates to /admin/orgs/:id
                name: RouterNames.adminOrgDetail,
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return NoTransitionPage(child: OrgDetailView(id: id));
                },
                routes: [
                  GoRoute(
                    path: 'edit', // Evaluates to /admin/orgs/:id/edit
                    name: RouterNames.adminOrgEdit,
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return NoTransitionPage(child: OrgDetailView(id: id));
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const NotFoundView(),
  );
});
