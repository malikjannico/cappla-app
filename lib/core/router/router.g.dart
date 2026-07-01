// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $loginRoute,
  $resetPasswordRoute,
  $appShellRouteData,
];

RouteBase get $loginRoute => GoRouteData.$route(
  path: '/login',

  factory: $LoginRouteExtension._fromState,
);

extension $LoginRouteExtension on LoginRoute {
  static LoginRoute _fromState(GoRouterState state) => const LoginRoute();

  String get location => GoRouteData.$location('/login');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $resetPasswordRoute => GoRouteData.$route(
  path: '/reset-password',

  factory: $ResetPasswordRouteExtension._fromState,
);

extension $ResetPasswordRouteExtension on ResetPasswordRoute {
  static ResetPasswordRoute _fromState(GoRouterState state) =>
      ResetPasswordRoute(
        email: state.uri.queryParameters['email'],
        trigger: _$convertMapValue(
          'trigger',
          state.uri.queryParameters,
          _$boolConverter,
        ),
      );

  String get location => GoRouteData.$location(
    '/reset-password',
    queryParams: {
      if (email != null) 'email': email,
      if (trigger != null) 'trigger': trigger!.toString(),
    },
  );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

T? _$convertMapValue<T>(
  String key,
  Map<String, String> map,
  T Function(String) converter,
) {
  final value = map[key];
  return value == null ? null : converter(value);
}

bool _$boolConverter(String value) {
  switch (value) {
    case 'true':
      return true;
    case 'false':
      return false;
    default:
      throw UnsupportedError('Cannot convert "$value" into a bool.');
  }
}

RouteBase get $appShellRouteData => ShellRouteData.$route(
  factory: $AppShellRouteDataExtension._fromState,
  routes: [
    GoRouteData.$route(path: '/', factory: $HomeRouteExtension._fromState),
    GoRouteData.$route(
      path: '/plan',

      factory: $PlanningRouteExtension._fromState,
      routes: [
        GoRouteData.$route(
          path: 'activities',

          factory: $PlanActivitiesRouteExtension._fromState,
        ),
        GoRouteData.$route(
          path: 'employees',

          factory: $PlanEmployeesRouteExtension._fromState,
        ),
      ],
    ),
    GoRouteData.$route(
      path: '/reports',

      factory: $ReportsRouteExtension._fromState,
    ),
    GoRouteData.$route(
      path: '/dashboards',

      factory: $DashboardsRouteExtension._fromState,
    ),
    GoRouteData.$route(
      path: '/settings',

      factory: $SettingsRouteExtension._fromState,
      routes: [
        GoRouteData.$route(
          path: 'activitygroups',

          factory: $SettingsActivityGroupsRouteExtension._fromState,
          routes: [
            GoRouteData.$route(
              path: 'new',

              factory: $SettingsActivityGroupsNewRouteExtension._fromState,
            ),
            GoRouteData.$route(
              path: ':id',

              factory: $SettingsActivityGroupsDetailRouteExtension._fromState,
              routes: [
                GoRouteData.$route(
                  path: 'edit',

                  factory: $SettingsActivityGroupsEditRouteExtension._fromState,
                ),
                GoRouteData.$route(
                  path: 'activities/new',

                  factory: $SettingsActivitiesNewRouteExtension._fromState,
                ),
                GoRouteData.$route(
                  path: 'activities/:activityId',

                  factory: $SettingsActivitiesDetailRouteExtension._fromState,
                  routes: [
                    GoRouteData.$route(
                      path: 'edit',

                      factory: $SettingsActivitiesEditRouteExtension._fromState,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        GoRouteData.$route(
          path: 'categories',

          factory: $SettingsCategoriesRouteExtension._fromState,
          routes: [
            GoRouteData.$route(
              path: 'new',

              factory: $SettingsCategoriesNewRouteExtension._fromState,
            ),
            GoRouteData.$route(
              path: ':id',

              factory: $SettingsCategoriesDetailRouteExtension._fromState,
              routes: [
                GoRouteData.$route(
                  path: 'edit',

                  factory: $SettingsCategoriesEditRouteExtension._fromState,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRouteData.$route(
      path: '/profile',

      factory: $ProfileRouteExtension._fromState,
      routes: [
        GoRouteData.$route(
          path: 'edit',

          factory: $ProfileEditRouteExtension._fromState,
        ),
      ],
    ),
    GoRouteData.$route(
      path: '/admin/users',

      factory: $AdminUsersRouteExtension._fromState,
      routes: [
        GoRouteData.$route(
          path: 'new',

          factory: $AdminUserNewRouteExtension._fromState,
        ),
        GoRouteData.$route(
          path: ':id',

          factory: $AdminUserDetailRouteExtension._fromState,
          routes: [
            GoRouteData.$route(
              path: 'edit',

              factory: $AdminUserEditRouteExtension._fromState,
            ),
          ],
        ),
      ],
    ),
    GoRouteData.$route(
      path: '/admin/orgs',

      factory: $AdminOrgsRouteExtension._fromState,
      routes: [
        GoRouteData.$route(
          path: 'new',

          factory: $AdminOrgNewRouteExtension._fromState,
        ),
        GoRouteData.$route(
          path: ':id',

          factory: $AdminOrgDetailRouteExtension._fromState,
          routes: [
            GoRouteData.$route(
              path: 'edit',

              factory: $AdminOrgEditRouteExtension._fromState,
            ),
          ],
        ),
      ],
    ),
  ],
);

extension $AppShellRouteDataExtension on AppShellRouteData {
  static AppShellRouteData _fromState(GoRouterState state) =>
      const AppShellRouteData();
}

extension $HomeRouteExtension on HomeRoute {
  static HomeRoute _fromState(GoRouterState state) => const HomeRoute();

  String get location => GoRouteData.$location('/');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $PlanningRouteExtension on PlanningRoute {
  static PlanningRoute _fromState(GoRouterState state) => const PlanningRoute();

  String get location => GoRouteData.$location('/plan');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $PlanActivitiesRouteExtension on PlanActivitiesRoute {
  static PlanActivitiesRoute _fromState(GoRouterState state) =>
      const PlanActivitiesRoute();

  String get location => GoRouteData.$location('/plan/activities');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $PlanEmployeesRouteExtension on PlanEmployeesRoute {
  static PlanEmployeesRoute _fromState(GoRouterState state) =>
      const PlanEmployeesRoute();

  String get location => GoRouteData.$location('/plan/employees');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $ReportsRouteExtension on ReportsRoute {
  static ReportsRoute _fromState(GoRouterState state) => const ReportsRoute();

  String get location => GoRouteData.$location('/reports');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $DashboardsRouteExtension on DashboardsRoute {
  static DashboardsRoute _fromState(GoRouterState state) =>
      const DashboardsRoute();

  String get location => GoRouteData.$location('/dashboards');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $SettingsRouteExtension on SettingsRoute {
  static SettingsRoute _fromState(GoRouterState state) => const SettingsRoute();

  String get location => GoRouteData.$location('/settings');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $SettingsActivityGroupsRouteExtension on SettingsActivityGroupsRoute {
  static SettingsActivityGroupsRoute _fromState(GoRouterState state) =>
      const SettingsActivityGroupsRoute();

  String get location => GoRouteData.$location('/settings/activitygroups');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $SettingsActivityGroupsNewRouteExtension
    on SettingsActivityGroupsNewRoute {
  static SettingsActivityGroupsNewRoute _fromState(GoRouterState state) =>
      const SettingsActivityGroupsNewRoute();

  String get location => GoRouteData.$location('/settings/activitygroups/new');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $SettingsActivityGroupsDetailRouteExtension
    on SettingsActivityGroupsDetailRoute {
  static SettingsActivityGroupsDetailRoute _fromState(GoRouterState state) =>
      SettingsActivityGroupsDetailRoute(id: state.pathParameters['id']!);

  String get location => GoRouteData.$location(
    '/settings/activitygroups/${Uri.encodeComponent(id)}',
  );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $SettingsActivityGroupsEditRouteExtension
    on SettingsActivityGroupsEditRoute {
  static SettingsActivityGroupsEditRoute _fromState(GoRouterState state) =>
      SettingsActivityGroupsEditRoute(id: state.pathParameters['id']!);

  String get location => GoRouteData.$location(
    '/settings/activitygroups/${Uri.encodeComponent(id)}/edit',
  );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $SettingsActivitiesNewRouteExtension on SettingsActivitiesNewRoute {
  static SettingsActivitiesNewRoute _fromState(GoRouterState state) =>
      SettingsActivitiesNewRoute(id: state.pathParameters['id']!);

  String get location => GoRouteData.$location(
    '/settings/activitygroups/${Uri.encodeComponent(id)}/activities/new',
  );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $SettingsActivitiesDetailRouteExtension
    on SettingsActivitiesDetailRoute {
  static SettingsActivitiesDetailRoute _fromState(GoRouterState state) =>
      SettingsActivitiesDetailRoute(
        id: state.pathParameters['id']!,
        activityId: state.pathParameters['activityId']!,
      );

  String get location => GoRouteData.$location(
    '/settings/activitygroups/${Uri.encodeComponent(id)}/activities/${Uri.encodeComponent(activityId)}',
  );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $SettingsActivitiesEditRouteExtension on SettingsActivitiesEditRoute {
  static SettingsActivitiesEditRoute _fromState(GoRouterState state) =>
      SettingsActivitiesEditRoute(
        id: state.pathParameters['id']!,
        activityId: state.pathParameters['activityId']!,
      );

  String get location => GoRouteData.$location(
    '/settings/activitygroups/${Uri.encodeComponent(id)}/activities/${Uri.encodeComponent(activityId)}/edit',
  );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $SettingsCategoriesRouteExtension on SettingsCategoriesRoute {
  static SettingsCategoriesRoute _fromState(GoRouterState state) =>
      const SettingsCategoriesRoute();

  String get location => GoRouteData.$location('/settings/categories');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $SettingsCategoriesNewRouteExtension on SettingsCategoriesNewRoute {
  static SettingsCategoriesNewRoute _fromState(GoRouterState state) =>
      const SettingsCategoriesNewRoute();

  String get location => GoRouteData.$location('/settings/categories/new');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $SettingsCategoriesDetailRouteExtension
    on SettingsCategoriesDetailRoute {
  static SettingsCategoriesDetailRoute _fromState(GoRouterState state) =>
      SettingsCategoriesDetailRoute(id: state.pathParameters['id']!);

  String get location =>
      GoRouteData.$location('/settings/categories/${Uri.encodeComponent(id)}');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $SettingsCategoriesEditRouteExtension on SettingsCategoriesEditRoute {
  static SettingsCategoriesEditRoute _fromState(GoRouterState state) =>
      SettingsCategoriesEditRoute(id: state.pathParameters['id']!);

  String get location => GoRouteData.$location(
    '/settings/categories/${Uri.encodeComponent(id)}/edit',
  );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $ProfileRouteExtension on ProfileRoute {
  static ProfileRoute _fromState(GoRouterState state) => const ProfileRoute();

  String get location => GoRouteData.$location('/profile');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $ProfileEditRouteExtension on ProfileEditRoute {
  static ProfileEditRoute _fromState(GoRouterState state) =>
      const ProfileEditRoute();

  String get location => GoRouteData.$location('/profile/edit');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $AdminUsersRouteExtension on AdminUsersRoute {
  static AdminUsersRoute _fromState(GoRouterState state) =>
      const AdminUsersRoute();

  String get location => GoRouteData.$location('/admin/users');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $AdminUserNewRouteExtension on AdminUserNewRoute {
  static AdminUserNewRoute _fromState(GoRouterState state) =>
      const AdminUserNewRoute();

  String get location => GoRouteData.$location('/admin/users/new');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $AdminUserDetailRouteExtension on AdminUserDetailRoute {
  static AdminUserDetailRoute _fromState(GoRouterState state) =>
      AdminUserDetailRoute(id: state.pathParameters['id']!);

  String get location =>
      GoRouteData.$location('/admin/users/${Uri.encodeComponent(id)}');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $AdminUserEditRouteExtension on AdminUserEditRoute {
  static AdminUserEditRoute _fromState(GoRouterState state) =>
      AdminUserEditRoute(id: state.pathParameters['id']!);

  String get location =>
      GoRouteData.$location('/admin/users/${Uri.encodeComponent(id)}/edit');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $AdminOrgsRouteExtension on AdminOrgsRoute {
  static AdminOrgsRoute _fromState(GoRouterState state) =>
      const AdminOrgsRoute();

  String get location => GoRouteData.$location('/admin/orgs');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $AdminOrgNewRouteExtension on AdminOrgNewRoute {
  static AdminOrgNewRoute _fromState(GoRouterState state) =>
      const AdminOrgNewRoute();

  String get location => GoRouteData.$location('/admin/orgs/new');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $AdminOrgDetailRouteExtension on AdminOrgDetailRoute {
  static AdminOrgDetailRoute _fromState(GoRouterState state) =>
      AdminOrgDetailRoute(id: state.pathParameters['id']!);

  String get location =>
      GoRouteData.$location('/admin/orgs/${Uri.encodeComponent(id)}');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $AdminOrgEditRouteExtension on AdminOrgEditRoute {
  static AdminOrgEditRoute _fromState(GoRouterState state) =>
      AdminOrgEditRoute(id: state.pathParameters['id']!);

  String get location =>
      GoRouteData.$location('/admin/orgs/${Uri.encodeComponent(id)}/edit');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}
