import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cappla/core/router/router_paths.dart';
import 'package:cappla/core/router/router_guards.dart';
import 'e2e_test_harness.dart';
import 'mock_views.dart';
import 'package:cappla/models/user_model.dart';
import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/core/providers/providers.dart';

class TestAuthState implements AuthStateInterface {
  @override
  final bool isAuthenticated;
  @override
  final UserProfile? currentUser;
  final bool isOrgActive;
  @override
  final bool isOrgUnitsLoading;

  TestAuthState({
    required this.isAuthenticated,
    this.currentUser,
    this.isOrgActive = true,
    this.isOrgUnitsLoading = false,
  });

  @override
  bool isOrgUnitActive(String orgUnitId) => isOrgActive;
}

void main() {
  group('Feature R1: Auth & Password Reset Boundaries', () {
    testWidgets(
      'T2_PWD_01: Entering a 7-character password (e.g. "Abc1!") displays Weak/Medium and blocks saving',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        harness.seedAdminUser();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        // Navigate to Reset Password page
        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('login_reset_password_link')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('reset_code_input')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('reset_verify_button')));
        await tester.pumpAndSettle();
        // Enter 5-character password ("Abc1!")
        await tester.enterText(
          find.byKey(const Key('reset_new_password_input')),
          'Abc1!',
        );

        await tester.pumpAndSettle();

        // Check strength indicator
        expect(
          find.byKey(const Key('password_strength_indicator')),
          findsOneWidget,
        );
        final indicatorFinder = find.byKey(
          const Key('password_strength_indicator'),
        );
        final Text textWidget = tester.widget(indicatorFinder);
        expect(textWidget.data, equals('Weak'));

        // Attempt saving
        await tester.tap(find.byKey(const Key('reset_password_button')));
        await tester.pumpAndSettle();

        // Verify saving is blocked by checking error status message
        expect(
          find.text(
            'Password must meet strong requirements (8+ chars, upper, lower, digit, special).',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T2_PWD_02: Entering an 8-character password with lowercase only displays Medium and blocks saving',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        harness.seedAdminUser();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('login_reset_password_link')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('reset_code_input')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('reset_verify_button')));
        await tester.pumpAndSettle();
        // Enter 8-character lowercase password
        await tester.enterText(
          find.byKey(const Key('reset_new_password_input')),
          'abcdefgh',
        );

        await tester.pumpAndSettle();

        // Check strength is Medium
        final Text textWidget = tester.widget(
          find.byKey(const Key('password_strength_indicator')),
        );
        expect(textWidget.data, equals('Medium'));

        // Attempt saving
        await tester.tap(find.byKey(const Key('reset_password_button')));
        await tester.pumpAndSettle();

        // Verify blocked
        expect(
          find.text(
            'Password must meet strong requirements (8+ chars, upper, lower, digit, special).',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T2_PWD_03: Entering an 8-character password with mixed cases only displays Medium and blocks saving',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        harness.seedAdminUser();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('login_reset_password_link')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('reset_code_input')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('reset_verify_button')));
        await tester.pumpAndSettle();
        // Enter 8-character mixed case password (no digits, no special characters)
        await tester.enterText(
          find.byKey(const Key('reset_new_password_input')),
          'Abcdefgh',
        );

        await tester.pumpAndSettle();

        // Check strength is Medium
        final Text textWidget = tester.widget(
          find.byKey(const Key('password_strength_indicator')),
        );
        expect(textWidget.data, equals('Medium'));

        // Attempt saving
        await tester.tap(find.byKey(const Key('reset_password_button')));
        await tester.pumpAndSettle();

        // Verify blocked
        expect(
          find.text(
            'Password must meet strong requirements (8+ chars, upper, lower, digit, special).',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T2_PWD_04: Entering an 8-character password with uppercase, lowercase, digit, and special displays Strong and enables saving',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        harness.seedAdminUser();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        // Enter email and navigate to password step
        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();

        // Go to Forgot Password page
        await tester.tap(find.byKey(const Key('login_reset_password_link')));
        await tester.pumpAndSettle();

        // Step 1: Verification code
        await tester.enterText(
          find.byKey(const Key('reset_code_input')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('reset_verify_button')));
        await tester.pumpAndSettle();

        // Step 2: Enter valid 8-character strong password
        await tester.enterText(
          find.byKey(const Key('reset_new_password_input')),
          'Abc1234!',
        );
        await tester.pumpAndSettle();

        // Check strength is Strong
        final Text textWidget = tester.widget(
          find.byKey(const Key('password_strength_indicator')),
        );
        expect(textWidget.data, equals('Strong'));

        // Attempt saving
        await tester.tap(find.byKey(const Key('reset_password_button')));
        await tester.pumpAndSettle();

        // Verify reset succeeds
        expect(find.text('Reset email sent successfully.'), findsOneWidget);
      },
    );

    testWidgets(
      'T2_AUTH_02: Attempting to log in with Inactive status user account blocks login and shows error',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        final inactiveUser = UserModel(
          id: 'inactive@vetter-pharma.com',
          fullName: 'Inactive User',
          email: 'inactive@vetter-pharma.com',
          title: 'Specialist',
          status: 'Inactive',
          role: 'User',
        );
        harness.seedUser(inactiveUser, 'Password123!');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        // Attempt login step 1
        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'inactive@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();

        // Attempt login step 2 (Password entry & Submit)
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'Password123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Verify login is blocked and shows error
        expect(find.byKey(const Key('login_error_text')), findsOneWidget);
        expect(
          find.text('Your account is Inactive. Access denied.'),
          findsOneWidget,
        );
        expect(harness.mockAuth.currentUser, isNull);
      },
    );
  });

  group('Feature R2: Routing Guards & Session Boundaries', () {
    testWidgets(
      'T2_GUARD_01: Deep-linking/navigating to /admin/users or /admin/orgs as unauthenticated guest redirects to /login',
      (WidgetTester tester) async {
        final authState = TestAuthState(isAuthenticated: false);
        final router = GoRouter(
          initialLocation: RouterPaths.adminUsers,
          redirect: (context, state) =>
              appRedirectGuard(context, state, authState),
          routes: [
            GoRoute(
              path: RouterPaths.login,
              builder: (c, s) => const Text('Login Page'),
            ),
            GoRoute(
              path: RouterPaths.adminUsers,
              builder: (c, s) => const Text('Admin Users'),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('Login Page'), findsOneWidget);
        expect(find.text('Admin Users'), findsNothing);
      },
    );

    testWidgets(
      'T2_GUARD_02: Deep-linking/navigating to /admin/users as standard User redirects/blocks access (redirects to /planning)',
      (WidgetTester tester) async {
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'user@example.com',
            role: 'User',
            status: 'Active',
            orgUnitId: 'DEPT_IT',
          ),
        );
        final router = GoRouter(
          initialLocation: RouterPaths.adminUsers,
          redirect: (context, state) =>
              appRedirectGuard(context, state, authState),
          routes: [
            GoRoute(
              path: RouterPaths.planning,
              builder: (c, s) => const Text('Planning Dashboard'),
            ),
            GoRoute(
              path: RouterPaths.adminUsers,
              builder: (c, s) => const Text('Admin Users'),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('Planning Dashboard'), findsOneWidget);
        expect(find.text('Admin Users'), findsNothing);
      },
    );

    testWidgets(
      'T2_GUARD_03: Changing user role dynamically in Firestore from Administrator to User mid-session revokes admin navigation capabilities',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        final orgUnit = OrgUnitModel(
          id: 'DEPT_IT',
          name: 'IT Department',
          abbreviation: 'IT',
          headOfEmail: 'manager@vetter.com',
          type: 'department',
          childIds: [],
          status: 'Active',
        );
        harness.mockFirestore.setData('orgUnits', 'DEPT_IT', orgUnit.toMap());
        final adminUser = UserModel(
          id: '00000000-0000-0000-0000-000000000000',
          fullName: 'Malik Jannico Press',
          email: 'MalikJannico.Press@vetter-pharma.com',
          title: 'Administrator',
          status: 'Active',
          role: 'Administrator',
          orgUnitId: 'DEPT_IT',
        );
        harness.seedUser(adminUser, 'AdminPassword123!');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        // Login as Admin
        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'AdminPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Verify Administration is available in dropdown
        await tester.tap(find.byKey(const Key('tab_collection_dropdown')));
        await tester.pumpAndSettle();
        expect(find.text('Administration'), findsWidgets);

        // Close dropdown by tapping outside or selecting Standard
        await tester.tap(find.text('Standard').last);
        await tester.pumpAndSettle();

        // Change user role dynamically in Database to Standard User
        final downgradedUser = UserModel(
          id: 'MalikJannico.Press@vetter-pharma.com',
          fullName: 'Malik Jannico Press',
          email: 'MalikJannico.Press@vetter-pharma.com',
          title: 'Administrator',
          status: 'Active',
          role: 'User', // Downgraded
          orgUnitId: 'DEPT_IT',
        );
        harness.mockFirestore.setData(
          'users',
          downgradedUser.email,
          downgradedUser.toMap(),
        );
        // Update local state to reflect mid-session Firestore change
        harness.container.read(currentUserProvider.notifier).state =
            downgradedUser;
        await tester.pumpAndSettle();

        // Verify Administration tab collection is no longer accessible or displayed (dropdown is hidden)
        expect(find.byKey(const Key('tab_collection_dropdown')), findsNothing);
      },
    );

    testWidgets(
      'T2_ROUTE_01: Navigating to an invalid route /non-existent displays a 404/not found widget',
      (WidgetTester tester) async {
        final router = GoRouter(
          initialLocation: '/non-existent',
          routes: [
            GoRoute(
              path: RouterPaths.planning,
              builder: (c, s) => const Text('Planning'),
            ),
          ],
          errorBuilder: (context, state) =>
              const Scaffold(body: Center(child: Text('404 - Page Not Found'))),
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('404 - Page Not Found'), findsOneWidget);
      },
    );

    testWidgets(
      'T2_ROUTE_02: Router Guard: Accessing /reset-password as unauthenticated guest allows access',
      (WidgetTester tester) async {
        final authState = TestAuthState(isAuthenticated: false);
        final router = GoRouter(
          initialLocation: RouterPaths.resetPassword,
          redirect: (context, state) =>
              appRedirectGuard(context, state, authState),
          routes: [
            GoRoute(
              path: RouterPaths.login,
              builder: (c, s) => const Text('Login'),
            ),
            GoRoute(
              path: RouterPaths.resetPassword,
              builder: (c, s) => const Text('Reset Password Page'),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('Reset Password Page'), findsOneWidget);
      },
    );

    testWidgets(
      'T2_ROUTE_03: Router Guard: Accessing /login as authenticated user redirects to /planning',
      (WidgetTester tester) async {
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'user@example.com',
            role: 'User',
            status: 'Active',
            orgUnitId: 'DEPT_IT',
          ),
        );
        final router = GoRouter(
          initialLocation: RouterPaths.login,
          redirect: (context, state) =>
              appRedirectGuard(context, state, authState),
          routes: [
            GoRoute(
              path: RouterPaths.planning,
              builder: (c, s) => const Text('Planning'),
            ),
            GoRoute(
              path: RouterPaths.login,
              builder: (c, s) => const Text('Login'),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('Planning'), findsOneWidget);
      },
    );

    testWidgets(
      'T2_ROUTE_04: Router Guard: Inactive user accessing standard routes is redirected to /login',
      (WidgetTester tester) async {
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'inactive@example.com',
            role: 'User',
            status: 'Inactive',
          ),
        );
        final router = GoRouter(
          initialLocation: RouterPaths.planning,
          redirect: (context, state) =>
              appRedirectGuard(context, state, authState),
          routes: [
            GoRoute(
              path: RouterPaths.login,
              builder: (c, s) => const Text('Login'),
            ),
            GoRoute(
              path: RouterPaths.planning,
              builder: (c, s) => const Text('Planning'),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('Login'), findsOneWidget);
      },
    );

    testWidgets(
      'T2_ROUTE_05: Router Guard: Standard user without org unit accessing planning is redirected to /',
      (WidgetTester tester) async {
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'user@example.com',
            role: 'User',
            status: 'Active',
            orgUnitId: null,
          ),
        );
        final router = GoRouter(
          initialLocation: RouterPaths.planning,
          redirect: (context, state) =>
              appRedirectGuard(context, state, authState),
          routes: [
            GoRoute(
              path: RouterPaths.home,
              builder: (c, s) => const Text('No Org Unit'),
            ),
            GoRoute(
              path: RouterPaths.planning,
              builder: (c, s) => const Text('Planning'),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('No Org Unit'), findsOneWidget);
      },
    );

    testWidgets(
      'T2_ROUTE_06: Router Guard: Standard user without org unit accessing /login is redirected to /',
      (WidgetTester tester) async {
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'user@example.com',
            role: 'User',
            status: 'Active',
            orgUnitId: null,
          ),
        );
        final router = GoRouter(
          initialLocation: RouterPaths.login,
          redirect: (context, state) =>
              appRedirectGuard(context, state, authState),
          routes: [
            GoRoute(
              path: RouterPaths.home,
              builder: (c, s) => const Text('No Org Unit'),
            ),
            GoRoute(
              path: RouterPaths.login,
              builder: (c, s) => const Text('Login'),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('No Org Unit'), findsOneWidget);
      },
    );

    testWidgets(
      'T2_ROUTE_07: Router Guard: Administrator without org unit accessing / is allowed to stay on /',
      (WidgetTester tester) async {
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'admin@example.com',
            role: 'Administrator',
            status: 'Active',
            orgUnitId: null,
          ),
        );
        final router = GoRouter(
          initialLocation: RouterPaths.home,
          redirect: (context, state) =>
              appRedirectGuard(context, state, authState),
          routes: [
            GoRoute(
              path: RouterPaths.home,
              builder: (c, s) => const Text('No Org Unit'),
            ),
            GoRoute(
              path: RouterPaths.planning,
              builder: (c, s) => const Text('Planning'),
            ),
            GoRoute(
              path: RouterPaths.adminOrgs,
              builder: (c, s) => const Text('Admin Orgs'),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('No Org Unit'), findsOneWidget);
      },
    );
  });

  group('Feature R3: User Management Boundaries', () {
    testWidgets(
      'T3_LIMIT_01: Searching with regex special characters is handled gracefully without crash',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        harness.seedAdminUser();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        // Login
        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'AdminPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Go to User Admin List
        harness.container.read(selectedTabCollectionProvider.notifier).state =
            'Administration';
        await tester.pumpAndSettle();

        // Enter special regex characters into search input
        await tester.enterText(
          find.byKey(const Key('user_search_input')),
          r'*?\[a-z]',
        );
        await tester.tap(find.byKey(const Key('user_search_button')));
        await tester.pumpAndSettle();

        // Verify no crashes occurred and search input is still displayed
        expect(find.byKey(const Key('user_search_input')), findsOneWidget);
      },
    );

    testWidgets(
      'T3_LIMIT_02: Pagination controls: Back and Forward buttons are disabled when total user count is <= 5',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        harness.seedAdminUser(); // 1 user total

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'AdminPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        harness.container.read(selectedTabCollectionProvider.notifier).state =
            'Administration';
        await tester.pumpAndSettle();

        // Verify page is 1 / 1
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('user_pagination_pages_input')),
              )
              .controller
              ?.text,
          '1',
        );
        expect(find.text('/ 1'), findsOneWidget);

        // Verify back and forward button onPressed handlers are null
        final IconButton backButton = tester.widget(
          find.byKey(const Key('user_page_back')),
        );
        final IconButton forwardButton = tester.widget(
          find.byKey(const Key('user_page_forward')),
        );
        expect(backButton.onPressed, isNull);
        expect(forwardButton.onPressed, isNull);
      },
    );

    testWidgets(
      'T3_LIMIT_03: Pagination controls: Adding a 6th user increments max page to 2, enabling the Forward button on Page 1',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        harness.seedAdminUser();
        // Add 4 more users -> total = 5 users
        for (int i = 1; i <= 4; i++) {
          harness.seedUser(
            UserModel(
              id: 'user$i@vetter.com',
              fullName: 'User $i',
              email: 'user$i@vetter.com',
              title: 'Specialist',
              status: 'Active',
              role: 'User',
            ),
            'Pass123!',
          );
        }

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'AdminPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        harness.container.read(selectedTabCollectionProvider.notifier).state =
            'Administration';
        await tester.pumpAndSettle();

        // Currently 5 users -> page 1 / 1, forward disabled
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('user_pagination_pages_input')),
              )
              .controller
              ?.text,
          '1',
        );
        expect(find.text('/ 1'), findsOneWidget);
        IconButton forwardButton = tester.widget(
          find.byKey(const Key('user_page_forward')),
        );
        expect(forwardButton.onPressed, isNull);

        // Enable detailed creation form to enter custom users
        harness.container
                .read(showDetailedUserCreateFormProvider.notifier)
                .state =
            true;
        await tester.pumpAndSettle();

        // Create a 6th user via form
        final submitBtn = find.byKey(const Key('create_user_button'));
        await tester.ensureVisible(
          find.byKey(const Key('user_create_fullname_input')),
        );
        await tester.enterText(
          find.byKey(const Key('user_create_fullname_input')),
          'User Six',
        );
        await tester.enterText(
          find.byKey(const Key('user_create_email_input')),
          'user6@vetter.com',
        );
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Page count should update to 1 / 2
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('user_pagination_pages_input')),
              )
              .controller
              ?.text,
          '1',
        );
        expect(find.text('/ 2'), findsOneWidget);

        // Forward button should now be enabled
        forwardButton = tester.widget(
          find.byKey(const Key('user_page_forward')),
        );
        expect(forwardButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'T3_LIMIT_04: Attempting to create a user with duplicate email triggers database constraint warning',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        harness.seedAdminUser();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'AdminPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        harness.container.read(selectedTabCollectionProvider.notifier).state =
            'Administration';
        harness.container
                .read(showDetailedUserCreateFormProvider.notifier)
                .state =
            true;
        await tester.pumpAndSettle();

        // Enter duplicate email (admin's email already exists in DB)
        final submitBtn = find.byKey(const Key('create_user_button'));
        await tester.ensureVisible(
          find.byKey(const Key('user_create_fullname_input')),
        );
        await tester.enterText(
          find.byKey(const Key('user_create_fullname_input')),
          'Duplicate User',
        );
        await tester.enterText(
          find.byKey(const Key('user_create_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Verify inline validation warning is shown
        expect(find.byKey(const Key('user_create_error_text')), findsOneWidget);
        expect(
          find.text('Error: User with this email already exists.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T3_LIMIT_05: Attempting to create a user with missing required fields (full name empty) shows inline validation error',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        harness.seedAdminUser();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'AdminPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        harness.container.read(selectedTabCollectionProvider.notifier).state =
            'Administration';
        harness.container
                .read(showDetailedUserCreateFormProvider.notifier)
                .state =
            true;
        await tester.pumpAndSettle();

        // Clear full name and enter valid email
        final submitBtn = find.byKey(const Key('create_user_button'));
        await tester.ensureVisible(
          find.byKey(const Key('user_create_fullname_input')),
        );
        await tester.enterText(
          find.byKey(const Key('user_create_fullname_input')),
          '',
        );
        await tester.enterText(
          find.byKey(const Key('user_create_email_input')),
          'some.new@vetter.com',
        );
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Verify error
        expect(find.byKey(const Key('user_create_error_text')), findsOneWidget);
        expect(find.text('Full Name is required.'), findsOneWidget);
      },
    );
  });

  group('Feature R4: Org Unit Hierarchical & Constraint Boundaries', () {
    testWidgets(
      'T4_CYCLE_01: Cycle prevention: Attempting to set an Org Unit\'s parent to itself fails validation',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = E2ETestHarness();
        harness.seedAdminUser();

        final orgA = OrgUnitModel(
          id: 'UNIT_A',
          name: 'Unit A',
          abbreviation: 'UA',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: null,
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(orgA);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'AdminPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Navigate to Org Unit Details
        harness.container.read(selectedTabCollectionProvider.notifier).state =
            'Administration';
        harness.container.read(currentAdminRouteProvider.notifier).state =
            'orgs';
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('org_row_UNIT_A')));
        await tester.pumpAndSettle();

        // Enable custom child inputs
        harness.container
                .read(showDetailedOrgChildInputProvider.notifier)
                .state =
            true;
        await tester.pumpAndSettle();

        // Attempt to add UNIT_A to itself (self-parent) via modal
        await tester.ensureVisible(
          find.byKey(const Key('org_add_child_button')),
        );
        await tester.tap(find.byKey(const Key('org_add_child_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('child_modal_search_input')),
          'UNIT_A',
        );
        await tester.pumpAndSettle();
        expect(find.text('No matching organization units.'), findsOneWidget);
        expect(find.byKey(const Key('child_modal_row_UNIT_A')), findsNothing);

        await tester.tap(find.byKey(const Key('child_modal_cancel_button')));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'T4_CYCLE_02: Cycle prevention: Attempting to assign Unit B as the parent of Unit A when Unit A is already parent of B fails validation',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = E2ETestHarness();
        harness.seedAdminUser();

        // UNIT_A is parent of UNIT_B
        final orgA = OrgUnitModel(
          id: 'UNIT_A',
          name: 'Unit A',
          abbreviation: 'UA',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: null,
          childIds: ['UNIT_B'],
          status: 'Active',
        );
        final orgB = OrgUnitModel(
          id: 'UNIT_B',
          name: 'Unit B',
          abbreviation: 'UB',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: 'UNIT_A',
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(orgA);
        harness.seedOrgUnit(orgB);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'AdminPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        harness.container.read(selectedTabCollectionProvider.notifier).state =
            'Administration';
        harness.container.read(currentAdminRouteProvider.notifier).state =
            'orgs';
        await tester.pumpAndSettle();

        // Go to UNIT_B details
        harness.container.read(selectedOrgForDetailsProvider.notifier).state =
            orgB;
        harness.container.read(currentViewProvider.notifier).state =
            'org_detail';
        harness.container
                .read(showDetailedOrgChildInputProvider.notifier)
                .state =
            true;
        await tester.pumpAndSettle();

        // Attempt to add parent UNIT_A as a child of UNIT_B (making B the parent of A -> circular) via modal
        await tester.ensureVisible(
          find.byKey(const Key('org_add_child_button')),
        );
        await tester.tap(find.byKey(const Key('org_add_child_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('child_modal_search_input')),
          'UNIT_A',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('child_modal_row_UNIT_A')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('child_modal_save_button')));
        await tester.pumpAndSettle();

        // Verify inline warning
        expect(
          find.text('Cycle detected: Circular hierarchy not allowed.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T4_CYCLE_03: Cycle prevention: Indirect loop A -> B -> C -> A fails validation',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = E2ETestHarness();
        harness.seedAdminUser();

        // Hierarchy: A -> B -> C
        final orgA = OrgUnitModel(
          id: 'UNIT_A',
          name: 'Unit A',
          abbreviation: 'UA',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: null,
          childIds: ['UNIT_B'],
          status: 'Active',
        );
        final orgB = OrgUnitModel(
          id: 'UNIT_B',
          name: 'Unit B',
          abbreviation: 'UB',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: 'UNIT_A',
          childIds: ['UNIT_C'],
          status: 'Active',
        );
        final orgC = OrgUnitModel(
          id: 'UNIT_C',
          name: 'Unit C',
          abbreviation: 'UC',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: 'UNIT_B',
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(orgA);
        harness.seedOrgUnit(orgB);
        harness.seedOrgUnit(orgC);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'AdminPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        harness.container.read(selectedTabCollectionProvider.notifier).state =
            'Administration';
        harness.container.read(currentAdminRouteProvider.notifier).state =
            'orgs';
        await tester.pumpAndSettle();

        // Go to UNIT_C details
        harness.container.read(selectedOrgForDetailsProvider.notifier).state =
            orgC;
        harness.container.read(currentViewProvider.notifier).state =
            'org_detail';
        harness.container
                .read(showDetailedOrgChildInputProvider.notifier)
                .state =
            true;
        await tester.pumpAndSettle();

        // Attempt to add UNIT_A as child of UNIT_C (making C parent of A -> loop A->B->C->A) via modal
        await tester.ensureVisible(
          find.byKey(const Key('org_add_child_button')),
        );
        await tester.tap(find.byKey(const Key('org_add_child_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('child_modal_search_input')),
          'UNIT_A',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('child_modal_row_UNIT_A')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('child_modal_save_button')));
        await tester.pumpAndSettle();

        // Verify warning
        expect(
          find.text('Cycle detected: Circular hierarchy not allowed.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T4_TYPE_01: Hierarchy rule: MD Division type unit cannot have any parent assigned',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = E2ETestHarness();
        harness.seedAdminUser();

        // Root A (department), Unit B (md division)
        final orgA = OrgUnitModel(
          id: 'UNIT_A',
          name: 'Unit A',
          abbreviation: 'UA',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: null,
          childIds: [],
          status: 'Active',
        );
        final orgB = OrgUnitModel(
          id: 'UNIT_B',
          name: 'Unit B',
          abbreviation: 'UB',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'md division',
          parentId: null,
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(orgA);
        harness.seedOrgUnit(orgB);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'AdminPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        harness.container.read(selectedTabCollectionProvider.notifier).state =
            'Administration';
        harness.container.read(currentAdminRouteProvider.notifier).state =
            'orgs';
        await tester.pumpAndSettle();

        // Go to UNIT_A details
        harness.container.read(selectedOrgForDetailsProvider.notifier).state =
            orgA;
        harness.container.read(currentViewProvider.notifier).state =
            'org_detail';
        harness.container
                .read(showDetailedOrgChildInputProvider.notifier)
                .state =
            true;
        await tester.pumpAndSettle();

        // Attempt to add B (md division) as a child of A via modal
        await tester.ensureVisible(
          find.byKey(const Key('org_add_child_button')),
        );
        await tester.tap(find.byKey(const Key('org_add_child_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('child_modal_search_input')),
          'UNIT_B',
        );
        await tester.pumpAndSettle();
        expect(find.text('No matching organization units.'), findsOneWidget);
        expect(find.byKey(const Key('child_modal_row_UNIT_B')), findsNothing);

        await tester.tap(find.byKey(const Key('child_modal_cancel_button')));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'T4_TYPE_02: Hierarchy rule: Team type unit cannot have child units assigned (Add child unit button disabled/blocked)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = E2ETestHarness();
        harness.seedAdminUser();

        final teamUnit = OrgUnitModel(
          id: 'TEAM_UNIT',
          name: 'Team Unit',
          abbreviation: 'TU',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'team', // Team type
          parentId: null,
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(teamUnit);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'AdminPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        harness.container.read(selectedTabCollectionProvider.notifier).state =
            'Administration';
        harness.container.read(currentAdminRouteProvider.notifier).state =
            'orgs';
        await tester.pumpAndSettle();

        // Go to TEAM_UNIT details
        harness.container.read(selectedOrgForDetailsProvider.notifier).state =
            teamUnit;
        harness.container.read(currentViewProvider.notifier).state =
            'org_detail';
        harness.container
                .read(showDetailedOrgChildInputProvider.notifier)
                .state =
            true;
        await tester.pumpAndSettle();

        // Verify that Child Units section and Add Child button are not rendered for team type
        expect(find.byKey(const Key('org_add_child_button')), findsNothing);
        expect(find.text('Child Organization Units'), findsNothing);
      },
    );

    testWidgets(
      'T4_TYPE_03: Parent constraint: Non-MD division can have at most one parent',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = E2ETestHarness();
        harness.seedAdminUser();

        // UNIT_C already has parent UNIT_A
        final orgA = OrgUnitModel(
          id: 'UNIT_A',
          name: 'Unit A',
          abbreviation: 'UA',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: null,
          childIds: ['UNIT_C'],
          status: 'Active',
        );
        final orgB = OrgUnitModel(
          id: 'UNIT_B',
          name: 'Unit B',
          abbreviation: 'UB',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: null,
          childIds: [],
          status: 'Active',
        );
        final orgC = OrgUnitModel(
          id: 'UNIT_C',
          name: 'Unit C',
          abbreviation: 'UC',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: 'UNIT_A', // Has parent
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(orgA);
        harness.seedOrgUnit(orgB);
        harness.seedOrgUnit(orgC);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'AdminPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        harness.container.read(selectedTabCollectionProvider.notifier).state =
            'Administration';
        harness.container.read(currentAdminRouteProvider.notifier).state =
            'orgs';
        await tester.pumpAndSettle();

        // Go to UNIT_B details
        harness.container.read(selectedOrgForDetailsProvider.notifier).state =
            orgB;
        harness.container.read(currentViewProvider.notifier).state =
            'org_detail';
        harness.container
                .read(showDetailedOrgChildInputProvider.notifier)
                .state =
            true;
        await tester.pumpAndSettle();

        // Attempt to add UNIT_C as child of UNIT_B via modal
        await tester.ensureVisible(
          find.byKey(const Key('org_add_child_button')),
        );
        await tester.tap(find.byKey(const Key('org_add_child_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('child_modal_search_input')),
          'UNIT_C',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('child_modal_row_UNIT_C')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('child_modal_save_button')));
        await tester.pumpAndSettle();

        // Verify constraint validation blocks assignment
        expect(
          find.text(
            'Constraint error: Non-MD division can have at most one parent.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T4_PROP_01: Status propagation: Deactivating a parent Org Unit propagates deactivation to child units',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = E2ETestHarness();
        harness.seedAdminUser();

        final parentOrg = OrgUnitModel(
          id: 'PARENT_UNIT',
          name: 'Parent Unit',
          abbreviation: 'PU',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: null,
          childIds: ['CHILD_UNIT'],
          status: 'Active',
        );
        final childOrg = OrgUnitModel(
          id: 'CHILD_UNIT',
          name: 'Child Unit',
          abbreviation: 'CU',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: 'PARENT_UNIT',
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(parentOrg);
        harness.seedOrgUnit(childOrg);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'AdminPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        harness.container.read(selectedTabCollectionProvider.notifier).state =
            'Administration';
        harness.container.read(currentAdminRouteProvider.notifier).state =
            'orgs';
        await tester.pumpAndSettle();

        // Deactivate parent
        await tester.tap(
          find.byKey(const Key('org_row_overflow_button_PARENT_UNIT')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('org_row_toggle_status_item_PARENT_UNIT')),
        );
        await tester.pumpAndSettle();

        // Verify parent is Inactive in DB
        final dbParent = OrgUnitModel.fromMap(
          harness.mockFirestore.getData('orgUnits', 'PARENT_UNIT')!,
        );
        expect(dbParent.status, equals('Inactive'));

        // Verify child propagated to Inactive
        final dbChild = OrgUnitModel.fromMap(
          harness.mockFirestore.getData('orgUnits', 'CHILD_UNIT')!,
        );
        expect(dbChild.status, equals('Inactive'));
      },
    );

    testWidgets(
      'T4_ASSOC_01: Remove child association clears parent reference field on child',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = E2ETestHarness();
        harness.seedAdminUser();

        final parentOrg = OrgUnitModel(
          id: 'PARENT_UNIT',
          name: 'Parent Unit',
          abbreviation: 'PU',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: null,
          childIds: ['CHILD_UNIT'],
          status: 'Active',
        );
        final childOrg = OrgUnitModel(
          id: 'CHILD_UNIT',
          name: 'Child Unit',
          abbreviation: 'CU',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: 'PARENT_UNIT',
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(parentOrg);
        harness.seedOrgUnit(childOrg);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const MaterialApp(home: MockAppRoot()),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'MalikJannico.Press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'AdminPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        harness.container.read(selectedTabCollectionProvider.notifier).state =
            'Administration';
        harness.container.read(currentAdminRouteProvider.notifier).state =
            'orgs';
        await tester.pumpAndSettle();

        // Go to parent details
        harness.container.read(selectedOrgForDetailsProvider.notifier).state =
            parentOrg;
        harness.container.read(currentViewProvider.notifier).state =
            'org_detail';
        await tester.pumpAndSettle();

        // Remove association
        final childOverflowFinder = find.byKey(
          const Key('org_child_overflow_button_CHILD_UNIT'),
        );
        await tester.ensureVisible(childOverflowFinder);
        await tester.pumpAndSettle();
        await tester.tap(childOverflowFinder);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('org_child_remove_parent_button_CHILD_UNIT')),
        );
        await tester.pumpAndSettle();

        // Verify parentId on child is null
        final dbChild = OrgUnitModel.fromMap(
          harness.mockFirestore.getData('orgUnits', 'CHILD_UNIT')!,
        );
        expect(dbChild.parentId, isNull);
      },
    );
  });
}
