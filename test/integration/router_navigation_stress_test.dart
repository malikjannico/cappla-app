import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cappla/main.dart';
import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/core/providers/providers.dart';
import 'package:cappla/core/router/router.dart';
import 'package:cappla/core/router/router_paths.dart';
import 'e2e_test_harness.dart';

void main() {
  group('Adversarial Stress Tests — Challenger M7', () {
    setUpWidget(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
    }

    tearDownWidget(WidgetTester tester) {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }

    void seedAdminWithOrg(E2ETestHarness harness) {
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
    }

    testWidgets(
      'M7_ST_01: Dynamic User Inactivation triggers silent redirect to login but leaves session active',
      (WidgetTester tester) async {
        setUpWidget(tester);
        addTearDown(() => tearDownWidget(tester));

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

        final standardUser = UserModel(
          id: 'john.doe@vetter-pharma.com',
          fullName: 'John Doe',
          email: 'john.doe@vetter-pharma.com',
          title: 'Specialist',
          status: 'Active',
          role: 'User',
          orgUnitId: 'DEPT_IT',
        );
        harness.seedUser(standardUser, 'UserPassword123!');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        // Log in
        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'john.doe@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'UserPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Verify authenticated and on Planning page
        expect(find.byKey(const Key('app_title')), findsOneWidget);
        expect(find.byKey(const Key('nav_planning')), findsOneWidget);

        // Change status to Inactive in the database
        final inactiveUser = UserModel(
          id: 'john.doe@vetter-pharma.com',
          fullName: 'John Doe',
          email: 'john.doe@vetter-pharma.com',
          title: 'Specialist',
          status: 'Inactive',
          role: 'User',
        );
        harness.mockFirestore.setData(
          'users',
          'john.doe@vetter-pharma.com',
          inactiveUser.toMap(),
        );

        // Pump to trigger stream updates and route guard check
        await tester.pumpAndSettle();

        // Verify user gets redirected back to Login screen
        expect(find.text('Log in to Cappla'), findsOneWidget);

        // Verify session itself was terminated
        expect(harness.mockAuth.currentUser, isNull);
      },
    );

    testWidgets(
      'M7_ST_02: User Deletion triggers dynamic redirect to login without terminating Auth session',
      (WidgetTester tester) async {
        setUpWidget(tester);
        addTearDown(() => tearDownWidget(tester));

        final harness = E2ETestHarness();
        final standardUser = UserModel(
          id: 'john.doe@vetter-pharma.com',
          fullName: 'John Doe',
          email: 'john.doe@vetter-pharma.com',
          title: 'Specialist',
          status: 'Active',
          role: 'User',
        );
        harness.seedUser(standardUser, 'UserPassword123!');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        // Log in
        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'john.doe@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'UserPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Verify Planning screen
        expect(find.byKey(const Key('app_title')), findsOneWidget);

        // Delete user document from firestore
        harness.removeUser('john.doe@vetter-pharma.com');

        // Pump to allow stream updates to propagate and trigger redirection
        await tester.pumpAndSettle();

        // Assert redirection to login screen
        expect(find.text('Log in to Cappla'), findsOneWidget);

        // Verify FirebaseAuth is terminated
        expect(harness.mockAuth.currentUser, isNull);
      },
    );

    testWidgets(
      'M7_ST_03: Admin self-demotion to standard user redirects them to /planning',
      (WidgetTester tester) async {
        setUpWidget(tester);
        addTearDown(() => tearDownWidget(tester));

        final harness = E2ETestHarness();
        seedAdminWithOrg(harness);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        // Log in as Malik Jannico Press
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

        // Go to Tab Collection dropdown and select Administration
        await tester.tap(find.byKey(const Key('tab_collection_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Administration').last);
        await tester.pumpAndSettle();

        // Navigate to self details in User Admin List
        await tester.tap(
          find.byKey(
            const Key(
              'user_row_edit_button_malikjannico.press@vetter-pharma.com',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Change own role to User
        await tester.tap(find.byKey(const Key('user_detail_role_input')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('User').last);
        await tester.pumpAndSettle();

        // Save changes
        await tester.tap(find.byKey(const Key('user_detail_save_button')));
        await tester.pumpAndSettle();

        // Verify immediate redirection to Planning view (due to route guard intercepting unauthorized admin route)
        expect(find.byKey(const Key('nav_planning')), findsOneWidget);

        // Verify role is indeed updated to User
        final updatedUser = harness.container.read(currentUserProvider);
        expect(updatedUser?.role, 'User');
      },
    );

    testWidgets(
      'M7_ST_04: Admin self-inactivation redirects them to login screen',
      (WidgetTester tester) async {
        setUpWidget(tester);
        addTearDown(() => tearDownWidget(tester));

        final harness = E2ETestHarness();
        seedAdminWithOrg(harness);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        // Log in
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

        // Select Administration
        await tester.tap(find.byKey(const Key('tab_collection_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Administration').last);
        await tester.pumpAndSettle();

        // Toggle own status to Inactive using the row's overflow popup menu
        await tester.tap(
          find.byKey(
            const Key(
              'user_row_overflow_button_malikjannico.press@vetter-pharma.com',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            const Key(
              'user_row_toggle_status_item_malikjannico.press@vetter-pharma.com',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert redirected to Login screen
        expect(find.text('Log in to Cappla'), findsOneWidget);
      },
    );

    testWidgets(
      'M7_ST_05: Accessing non-existent admin detail routes directly displays empty placeholder state',
      (WidgetTester tester) async {
        setUpWidget(tester);
        addTearDown(() => tearDownWidget(tester));

        final harness = E2ETestHarness();
        harness.seedAdminUser();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        // Log in
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

        // Use router directly to deep link to a non-existent user
        final router = harness.container.read(routerProvider);
        router.go(RouterPaths.adminUserDetailPath('missing@vetter-pharma.com'));
        await tester.pumpAndSettle();

        // Verify "No User Selected" placeholder is shown
        expect(find.text('No User Selected'), findsOneWidget);

        // Deep link to a non-existent org unit
        router.go(RouterPaths.adminOrgDetailPath('MISSING_ORG'));
        await tester.pumpAndSettle();

        // Verify "No Org Unit Selected" placeholder is shown
        expect(find.text('No Org Unit Selected'), findsOneWidget);
      },
    );

    testWidgets(
      'M7_ST_06: Password strength indicator is non-monotonic due to design flaws',
      (WidgetTester tester) async {
        setUpWidget(tester);
        addTearDown(() => tearDownWidget(tester));

        final harness = E2ETestHarness();
        harness.seedAdminUser();
        harness.seedAdminUser();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        // Go to Forgot Password page
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
        // 1. Enter 7-character password (abcdefg)
        await tester.enterText(
          find.byKey(const Key('reset_new_password_input')),
          'abcdefg',
        );

        await tester.pump();

        // Verify strength is "Medium"
        var strengthText = tester.widget<Text>(
          find.byKey(const Key('password_strength_indicator')),
        );
        expect(strengthText.data, equals('Medium'));

        // 2. Append another character to make it 8-characters (abcdefgh)
        await tester.enterText(
          find.byKey(const Key('reset_new_password_input')),
          'abcdefgh',
        );
        await tester.pump();

        // Verify strength is "Medium" (monotonic)
        strengthText = tester.widget<Text>(
          find.byKey(const Key('password_strength_indicator')),
        );
        expect(strengthText.data, equals('Medium'));
      },
    );
    testWidgets(
      'M7_ST_07: Email empty validation error is displayed on detailed user creation',
      (WidgetTester tester) async {
        setUpWidget(tester);
        addTearDown(() => tearDownWidget(tester));

        final harness = E2ETestHarness();
        seedAdminWithOrg(harness);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        // Log in
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

        // Go to Administration
        await tester.tap(find.byKey(const Key('tab_collection_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Administration').last);
        await tester.pumpAndSettle();

        // Set detailed user form visibility to true via provider directly to simulate detailed user creation form display
        harness.container
                .read(showDetailedUserCreateFormProvider.notifier)
                .state =
            true;
        await tester.pumpAndSettle();

        // Enter full name, but leave email empty
        await tester.enterText(
          find.byKey(const Key('user_create_fullname_input')),
          'Blank Email User',
        );
        await tester.enterText(
          find.byKey(const Key('user_create_email_input')),
          '',
        );

        // Tap create user button
        await tester.tap(find.byKey(const Key('create_user_button')));
        await tester.pumpAndSettle();

        // Verify validation error is displayed
        expect(find.text('Email is required.'), findsOneWidget);
        // Verify user is NOT created in database
        expect(
          harness.mockFirestore.getData('users', 'blank@vetter-pharma.com'),
          isNull,
        );
      },
    );

    testWidgets(
      'M7_ST_08: Profile view displays warning when current user org unit becomes Inactive',
      (WidgetTester tester) async {
        setUpWidget(tester);
        addTearDown(() => tearDownWidget(tester));

        final harness = E2ETestHarness();
        final standardUser = UserModel(
          id: 'john.doe@vetter-pharma.com',
          fullName: 'John Doe',
          email: 'john.doe@vetter-pharma.com',
          title: 'Specialist',
          status: 'Active',
          role: 'User',
          orgUnitId: 'MD_DIV',
        );
        final activeOrg = OrgUnitModel(
          id: 'MD_DIV',
          name: 'MD Division',
          abbreviation: 'MD',
          headOfEmail: 'john.doe@vetter-pharma.com',
          type: 'md division',
          parentId: null,
          childIds: [],
          status: 'Active',
        );

        harness.seedUser(standardUser, 'UserPassword123!');
        harness.seedOrgUnit(activeOrg);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        // Log in
        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'john.doe@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'UserPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Navigate to My Profile
        await tester.tap(find.byKey(const Key('profile_dropdown_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('profile_menu_item_profile')));
        await tester.pumpAndSettle();

        // Verify no warning is shown initially
        expect(
          find.byKey(const Key('profile_org_inactive_warning')),
          findsNothing,
        );

        // Inactivate the organization unit in firestore
        final inactiveOrg = OrgUnitModel(
          id: 'MD_DIV',
          name: 'MD Division',
          abbreviation: 'MD',
          headOfEmail: 'john.doe@vetter-pharma.com',
          type: 'md division',
          parentId: null,
          childIds: [],
          status: 'Inactive',
        );
        harness.mockFirestore.setData(
          'orgUnits',
          'MD_DIV',
          inactiveOrg.toMap(),
        );

        // Go back to planning page and return to Profile page to trigger _loadOrgUnit reload
        await tester.tap(find.byKey(const Key('nav_planning')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('profile_dropdown_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('profile_menu_item_profile')));
        await tester.pumpAndSettle();

        // Verify warning container is displayed now that profile is loaded under inactive org
        expect(
          find.byKey(const Key('profile_org_inactive_warning')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'M7_ST_09: Guest access to invalid paths redirects to login, while authenticated shows 404 page',
      (WidgetTester tester) async {
        setUpWidget(tester);
        addTearDown(() => tearDownWidget(tester));

        final harness = E2ETestHarness();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        // Get router to navigate directly
        final router = harness.container.read(routerProvider);

        // 1. Navigate as guest to /invalid-path
        router.go('/invalid-path');
        await tester.pumpAndSettle();

        // Verify guest is redirected to login (due to redirect guard returning /login for guest accessing non-auth paths)
        expect(find.text('Log in to Cappla'), findsOneWidget);

        // 2. Log in
        final standardUser = UserModel(
          id: 'john.doe@vetter-pharma.com',
          fullName: 'John Doe',
          email: 'john.doe@vetter-pharma.com',
          title: 'Specialist',
          status: 'Active',
          role: 'User',
        );
        harness.seedUser(standardUser, 'UserPassword123!');

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'john.doe@vetter-pharma.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'UserPassword123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // 3. Navigate as authenticated user to /invalid-path
        router.go('/invalid-path');
        await tester.pumpAndSettle();

        // Verify authenticated user sees 404 - Page Not Found
        expect(find.text('404 - Page Not Found'), findsOneWidget);
      },
    );
  });
}
