// File: lib/core/router/router_paths.dart

class RouterPaths {
  // Root Path
  static const String home = '/';

  // Authentication & Guest Paths
  static const String login = '/login';
  static const String resetPassword = '/reset-password';

  // Standard Application Paths (Wrapped inside App Navigation Shell)
  static const String planning = '/plan';
  static const String planActivities = '/plan/activities';
  static const String planEmployees = '/plan/employees';
  static const String reports = '/reports';
  static const String dashboards = '/dashboards';
  static const String settings = '/settings';
  static const String settingsActivityGroups = '/settings/acitivitygroups';
  static const String settingsActivityGroupsNew =
      '/settings/acitivitygroups/new';
  static const String settingsActivityGroupsDetail =
      '/settings/acitivitygroups/:id';
  static const String settingsActivityGroupsEdit =
      '/settings/acitivitygroups/:id/edit';
  static const String settingsActivitiesNew =
      '/settings/acitivitygroups/:id/activities/new';
  static const String settingsActivitiesDetail =
      '/settings/acitivitygroups/:id/activities/:activityId';
  static const String settingsActivitiesEdit =
      '/settings/acitivitygroups/:id/activities/:activityId/edit';
  static const String settingsCategories = '/settings/categories';
  static const String settingsCategoriesNew = '/settings/categories/new';
  static const String settingsCategoriesDetail = '/settings/categories/:id';
  static const String settingsCategoriesEdit = '/settings/categories/:id/edit';
  static const String profile = '/profile';
  static const String profileEdit = '/profile/edit';

  // Admin-only Paths (Wrapped inside App Navigation Shell, Restricted)
  static const String adminUsers = '/admin/users';
  static const String adminUserNew = '/admin/users/new';
  static const String adminUserDetail = '/admin/users/:id';
  static const String adminUserEdit = '/admin/users/:id/edit';
  static const String adminOrgs = '/admin/orgs';
  static const String adminOrgNew = '/admin/orgs/new';
  static const String adminOrgDetail = '/admin/orgs/:id';
  static const String adminOrgEdit = '/admin/orgs/:id/edit';

  // Dynamic path helpers
  static String adminUserDetailPath(String id) => '/admin/users/$id';
  static String adminUserEditPath(String id) => '/admin/users/$id/edit';
  static String adminOrgDetailPath(String id) => '/admin/orgs/$id';
  static String adminOrgEditPath(String id) => '/admin/orgs/$id/edit';
  static String settingsActivityGroupsDetailPath(String id) =>
      '/settings/acitivitygroups/$id';
  static String settingsActivityGroupsEditPath(String id) =>
      '/settings/acitivitygroups/$id/edit';
  static String settingsActivitiesNewPath(String groupId) =>
      '/settings/acitivitygroups/$groupId/activities/new';
  static String settingsActivitiesDetailPath(
    String groupId,
    String activityId,
  ) => '/settings/acitivitygroups/$groupId/activities/$activityId';
  static String settingsActivitiesEditPath(String groupId, String activityId) =>
      '/settings/acitivitygroups/$groupId/activities/$activityId/edit';
  static String settingsCategoriesDetailPath(String id) =>
      '/settings/categories/$id';
  static String settingsCategoriesEditPath(String id) =>
      '/settings/categories/$id/edit';
}

class RouterNames {
  static const String home = 'home';
  static const String login = 'login';
  static const String resetPassword = 'reset-password';
  static const String planning = 'planning';
  static const String planActivities = 'plan-activities';
  static const String planEmployees = 'plan-employees';
  static const String reports = 'reports';
  static const String dashboards = 'dashboards';
  static const String settings = 'settings';
  static const String settingsActivityGroups = 'settings-activity-groups';
  static const String settingsActivityGroupsNew =
      'settings-activity-groups-new';
  static const String settingsActivityGroupsDetail =
      'settings-activity-groups-detail';
  static const String settingsActivityGroupsEdit =
      'settings-activity-groups-edit';
  static const String settingsActivitiesNew = 'settings-activities-new';
  static const String settingsActivitiesDetail = 'settings-activities-detail';
  static const String settingsActivitiesEdit = 'settings-activities-edit';
  static const String settingsCategories = 'settings-categories';
  static const String settingsCategoriesNew = 'settings-categories-new';
  static const String settingsCategoriesDetail = 'settings-categories-detail';
  static const String settingsCategoriesEdit = 'settings-categories-edit';
  static const String profile = 'profile';
  static const String profileEdit = 'profile-edit';
  static const String adminUsers = 'admin-users';
  static const String adminUserNew = 'admin-user-new';
  static const String adminUserDetail = 'admin-user-detail';
  static const String adminUserEdit = 'admin-user-edit';
  static const String adminOrgs = 'admin-orgs';
  static const String adminOrgNew = 'admin-org-new';
  static const String adminOrgDetail = 'admin-org-detail';
  static const String adminOrgEdit = 'admin-org-edit';
}
