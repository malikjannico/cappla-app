import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cappla/main.dart';
import 'package:cappla/models/user_model.dart';
import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/core/providers/providers.dart';
import 'e2e_test_harness.dart';

void main() {
  group('Feature R1: Auth & Access', () {
    testWidgets(
      'R1_HP_01: Login as Malik Jannico Press (seeded Admin) succeeds',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        harness.seedAdminUser();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        expect(find.text('Log in to Cappla'), findsOneWidget);

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

        expect(find.byKey(const Key('app_title')), findsOneWidget);
        expect(harness.mockAuth.currentUser, isNotNull);
        expect(
          harness.mockAuth.currentUser!.email,
          'malikjannico.press@vetter-pharma.com',
        );
      },
    );

    testWidgets('R1_HP_02: Login as new standard User succeeds', (
      WidgetTester tester,
    ) async {
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

      expect(find.byKey(const Key('app_title')), findsOneWidget);
      expect(harness.mockAuth.currentUser, isNotNull);
      expect(harness.mockAuth.currentUser!.email, 'john.doe@vetter-pharma.com');
    });

    testWidgets(
      'R1_HP_03: Profile screen shows correct name, email, role, and org unit',
      (WidgetTester tester) async {
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
        harness.seedUser(standardUser, 'UserPassword123!');

        final mdDiv = OrgUnitModel(
          id: 'MD_DIV',
          name: 'MD Division',
          abbreviation: 'MDD',
          headOfEmail: 'john.doe@vetter-pharma.com',
          type: 'md division',
          childIds: [],
          status: 'Active',
        );
        harness.mockFirestore.setData('orgUnits', 'MD_DIV', mdDiv.toMap());

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

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

        // Navigate to profile
        await tester.tap(find.byKey(const Key('profile_dropdown_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('profile_menu_item_profile')));
        await tester.pumpAndSettle();

        // Verify profile info
        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('john.doe@vetter-pharma.com'), findsOneWidget);
        expect(find.text('MD Division'), findsOneWidget);
      },
    );

    testWidgets('R1_HP_04: Logout signs out user and navigates back to login', (
      WidgetTester tester,
    ) async {
      final harness = E2ETestHarness();
      harness.seedAdminUser();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const CapplaApp(),
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

      // Logout
      await tester.tap(find.byKey(const Key('profile_dropdown_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile_menu_item_logout')));
      await tester.pumpAndSettle();

      expect(find.text('Log in to Cappla'), findsOneWidget);
      expect(harness.mockAuth.currentUser, isNull);
    });

    testWidgets('R1_HP_05: Trigger password reset email via Forgot Password', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final harness = E2ETestHarness();
      harness.seedAdminUser();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const CapplaApp(),
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
      await tester.enterText(
        find.byKey(const Key('reset_new_password_input')),
        'NewPassword123!',
      );

      await tester.tap(find.byKey(const Key('reset_password_button')));

      await tester.pumpAndSettle();

      expect(find.text('Reset email sent successfully.'), findsOneWidget);
      expect(
        harness.mockAuth.sentPasswordResets.contains(
          'malikjannico.press@vetter-pharma.com',
        ),
        isTrue,
      );
    });

    testWidgets(
      'R1_HP_06: Malik Jannico Press is automatically seeded on init',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        harness.seedAdminUser();

        final userMap = harness.mockFirestore.getData(
          'users',
          'malikjannico.press@vetter-pharma.com',
        );
        expect(userMap, isNotNull);
        final user = UserModel.fromMap(userMap!);
        expect(user.fullName, 'Malik Jannico Press');
        expect(user.email, 'malikjannico.press@vetter-pharma.com');
        expect(user.role, 'Administrator');
        expect(user.status, 'Active');
      },
    );
  });

  group('Feature R2: Global Nav', () {
    testWidgets('R2_HP_01: Standard users see Planning, Settings tabs', (
      WidgetTester tester,
    ) async {
      final harness = E2ETestHarness();
      final orgUnit = OrgUnitModel(
        id: 'DEPT_IT',
        name: 'IT Department',
        abbreviation: 'IT',
        headOfEmail: 'john@vetter.com',
        type: 'department',
        childIds: [],
        status: 'Active',
      );
      harness.mockFirestore.setData('orgUnits', 'DEPT_IT', orgUnit.toMap());

      final standardUser = UserModel(
        id: 'john@vetter.com',
        fullName: 'John',
        email: 'john@vetter.com',
        title: 'Specialist',
        status: 'Active',
        role: 'User',
        orgUnitId: 'DEPT_IT',
      );
      harness.seedUser(standardUser, 'Pass123!');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const CapplaApp(),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('login_email_input')),
        'john@vetter.com',
      );
      await tester.tap(find.byKey(const Key('login_next_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login_password_input')),
        'Pass123!',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nav_planning')), findsOneWidget);
      expect(find.byKey(const Key('nav_settings')), findsOneWidget);
    });

    testWidgets(
      'R2_HP_02: Administrator can switch Tab Collection dropdown to "Administration" and see Users/Orgs tabs',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        final orgUnit = OrgUnitModel(
          id: 'DEPT_IT',
          name: 'IT Department',
          abbreviation: 'IT',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          childIds: [],
          status: 'Active',
        );
        harness.mockFirestore.setData('orgUnits', 'DEPT_IT', orgUnit.toMap());
        harness.seedAdminUser();
        final updatedAdmin = UserModel(
          id: '00000000-0000-0000-0000-000000000000',
          fullName: 'Malik Jannico Press',
          email: 'MalikJannico.Press@vetter-pharma.com',
          title: 'Administrator',
          status: 'Active',
          role: 'Administrator',
          orgUnitId: 'DEPT_IT',
        );
        harness.mockFirestore.setData(
          'users',
          'MalikJannico.Press@vetter-pharma.com',
          updatedAdmin.toMap(),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
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

        // Switch Tab Collection to Administration
        await tester.tap(find.byKey(const Key('tab_collection_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Administration').last);
        await tester.pumpAndSettle();

        // Verify User Administration is shown
        expect(find.byKey(const Key('user_admin_title')), findsOneWidget);
        expect(find.byKey(const Key('nav_rail_orgs')), findsOneWidget);

        // Tap orgs nav
        await tester.tap(find.byKey(const Key('nav_rail_orgs')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('org_admin_title')), findsOneWidget);
        expect(find.byKey(const Key('nav_rail_users')), findsOneWidget);
      },
    );

    testWidgets(
      'R2_HP_04: Standard users cannot see "tab_collection_dropdown" trigger',
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

        final standardUser = UserModel(
          id: 'john@vetter.com',
          fullName: 'John',
          email: 'john@vetter.com',
          title: 'Specialist',
          status: 'Active',
          role: 'User',
          orgUnitId: 'DEPT_IT',
        );
        harness.seedUser(standardUser, 'Pass123!');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'john@vetter.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'Pass123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tab_collection_dropdown')), findsNothing);
      },
    );

    testWidgets('R2_HP_05: Verify profile navigation via profile dropdown', (
      WidgetTester tester,
    ) async {
      final harness = E2ETestHarness();
      harness.seedAdminUser();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const CapplaApp(),
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

      await tester.tap(find.byKey(const Key('profile_dropdown_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile_menu_item_profile')));
      await tester.pumpAndSettle();

      expect(find.text('My Profile'), findsOneWidget);
    });
  });

  group('Feature R3: User Admin', () {
    testWidgets('R3_HP_01: Search filters user table correctly', (
      WidgetTester tester,
    ) async {
      final harness = E2ETestHarness();
      harness.seedAdminUser();

      final alice = UserModel(
        id: 'alice@vetter.com',
        fullName: 'Alice Smith',
        email: 'alice@vetter.com',
        title: 'Analyst',
        status: 'Active',
        role: 'User',
      );
      final bob = UserModel(
        id: 'bob@vetter.com',
        fullName: 'Bob Jones',
        email: 'bob@vetter.com',
        title: 'Analyst',
        status: 'Active',
        role: 'User',
      );
      harness.seedUser(alice, 'Pass123!');
      harness.seedUser(bob, 'Pass123!');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const CapplaApp(),
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

      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Bob Jones'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('user_search_input')),
        'Alice',
      );
      await tester.tap(find.byKey(const Key('user_search_button')));
      await tester.pumpAndSettle();

      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Bob Jones'), findsNothing);
    });

    testWidgets('R3_HP_02: Status filter (Active/Inactive) works', (
      WidgetTester tester,
    ) async {
      final harness = E2ETestHarness();
      harness.seedAdminUser();

      final alice = UserModel(
        id: 'alice@vetter.com',
        fullName: 'Alice Smith',
        email: 'alice@vetter.com',
        title: 'Analyst',
        status: 'Active',
        role: 'User',
      );
      final bob = UserModel(
        id: 'bob@vetter.com',
        fullName: 'Bob Jones',
        email: 'bob@vetter.com',
        title: 'Analyst',
        status: 'Inactive',
        role: 'User',
      );
      harness.seedUser(alice, 'Pass123!');
      harness.seedUser(bob, 'Pass123!');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const CapplaApp(),
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

      // Verify we are on screen (meaning login is complete)
      expect(find.byKey(const Key('app_title')), findsOneWidget);

      harness.container.read(selectedTabCollectionProvider.notifier).state =
          'Administration';
      await tester.pumpAndSettle();

      // Filter by Inactive
      await tester.ensureVisible(
        find.byKey(const Key('filter_status_dropdown')),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('filter_status_dropdown')),
          matching: find.byType(Text),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter_status_inactive_item')));
      await tester.pumpAndSettle();

      expect(find.text('Bob Jones'), findsOneWidget);
      expect(find.text('Alice Smith'), findsNothing);

      // Filter by Active
      await tester.ensureVisible(
        find.byKey(const Key('filter_status_dropdown')),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('filter_status_dropdown')),
          matching: find.byType(Text),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter_status_active_item')));
      await tester.pumpAndSettle();

      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Bob Jones'), findsNothing);
    });

    testWidgets('R3_HP_03: Paginate table forwards/backwards when users > 5', (
      WidgetTester tester,
    ) async {
      final harness = E2ETestHarness();
      harness.seedAdminUser();
      for (int i = 1; i <= 5; i++) {
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
          child: const CapplaApp(),
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

      await tester.ensureVisible(find.byKey(const Key('user_page_forward')));
      await tester.tap(find.byKey(const Key('user_page_forward')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('user_pagination_pages_input')),
            )
            .controller
            ?.text,
        '2',
      );
      expect(find.text('/ 2'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('user_page_back')));
      await tester.tap(find.byKey(const Key('user_page_back')));
      await tester.pumpAndSettle();

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
    });

    testWidgets(
      'R3_HP_04: View details button navigates to User Detail page with breadcrumbs',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        harness.seedAdminUser();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
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

        await tester.ensureVisible(
          find.byKey(
            const Key('user_row_malikjannico.press@vetter-pharma.com'),
          ),
        );
        await tester.tap(
          find.byKey(
            const Key('user_row_malikjannico.press@vetter-pharma.com'),
          ),
        );
        await tester.pumpAndSettle();

        final nameField = find.byKey(const Key('user_detail_name'));
        expect(nameField, findsOneWidget);
        expect(
          tester.widget<TextField>(nameField).controller?.text,
          'Malik Jannico Press',
        );

        await tester.tap(find.byKey(const Key('user_detail_back_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('user_admin_title')), findsOneWidget);
      },
    );

    testWidgets(
      'R3_HP_05: Create new user correctly adds user to database and table',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        harness.seedAdminUser();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
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

        await tester.enterText(
          find.byKey(const Key('user_create_fullname_input')),
          'New User',
        );
        await tester.enterText(
          find.byKey(const Key('user_create_email_input')),
          'new.user@vetter-pharma.com',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('create_user_button')));
        await tester.pumpAndSettle();

        Map<String, dynamic>? dbUser;
        final usersMap = harness.mockFirestore.collections['users'];
        if (usersMap != null) {
          for (final val in usersMap.values) {
            if (val['email'].toString().toLowerCase() ==
                'new.user@vetter-pharma.com') {
              dbUser = val;
              break;
            }
          }
        }
        expect(dbUser, isNotNull);
        expect(dbUser!['fullName'], 'New User');

        expect(find.text('New User'), findsOneWidget);
      },
    );
  });

  group('Feature R4: Org Unit Admin', () {
    testWidgets(
      'R4_HP_01: Table shows all organization units (root and child)',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        harness.seedAdminUser();

        final rootOrg = OrgUnitModel(
          id: 'MD_DIV',
          name: 'MD Division',
          abbreviation: 'MDD',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'md division',
          parentId: null,
          childIds: [],
          status: 'Active',
        );
        final childOrg = OrgUnitModel(
          id: 'SVP_DIV',
          name: 'SVP Division',
          abbreviation: 'SVPD',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'svp division',
          parentId: 'MD_DIV',
          childIds: [],
          status: 'Active',
        );

        harness.seedOrgUnit(rootOrg);
        harness.seedOrgUnit(childOrg);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
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

        expect(find.byKey(const Key('org_row_MD_DIV')), findsOneWidget);
        expect(find.byKey(const Key('org_row_SVP_DIV')), findsOneWidget);
      },
    );

    testWidgets('R4_HP_02: Detail page displays correct unit info', (
      WidgetTester tester,
    ) async {
      final harness = E2ETestHarness();
      harness.seedAdminUser();

      final rootOrg = OrgUnitModel(
        id: 'MD_DIV',
        name: 'MD Division',
        abbreviation: 'MDD',
        headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
        type: 'md division',
        parentId: null,
        childIds: [],
        status: 'Active',
      );
      harness.seedOrgUnit(rootOrg);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const CapplaApp(),
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
      harness.container.read(currentAdminRouteProvider.notifier).state = 'orgs';
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('org_row_MD_DIV')));
      await tester.pumpAndSettle();

      final nameField = find.byKey(const Key('org_detail_name'));
      expect(nameField, findsOneWidget);
      expect(
        tester.widget<TextField>(nameField).controller?.text,
        'MD Division',
      );

      final abbrevField = find.byKey(const Key('org_detail_abbrev'));
      expect(abbrevField, findsOneWidget);
      expect(tester.widget<TextField>(abbrevField).controller?.text, 'MDD');

      final headField = find.byKey(const Key('org_detail_head'));
      expect(headField, findsOneWidget);
      expect(
        tester.widget<TextField>(headField).controller?.text,
        'MalikJannico.Press@vetter-pharma.com',
      );

      final typeField = find.byKey(const Key('org_detail_type'));
      expect(typeField, findsOneWidget);
      expect(
        tester.widget<TextField>(typeField).controller?.text,
        'MD Division',
      );

      expect(find.byKey(const Key('org_detail_status_label')), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets(
      'R4_HP_03: Add employee to unit displays them in the Employees section',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = E2ETestHarness();
        harness.seedAdminUser();

        // Update admin user so that john@vetter.com is the first user with null orgUnitId
        final updatedAdmin = UserModel(
          id: 'MalikJannico.Press@vetter-pharma.com',
          fullName: 'Malik Jannico Press',
          email: 'MalikJannico.Press@vetter-pharma.com',
          title: 'Administrator',
          status: 'Active',
          role: 'Administrator',
          orgUnitId: 'SOME_DIV',
        );
        harness.mockFirestore.setData(
          'users',
          updatedAdmin.email,
          updatedAdmin.toMap(),
        );

        final john = UserModel(
          id: 'john@vetter.com',
          fullName: 'John Doe',
          email: 'john@vetter.com',
          title: 'Consultant',
          status: 'Active',
          role: 'User',
          orgUnitId: null,
        );
        harness.seedUser(john, 'Pass123!');

        final rootOrg = OrgUnitModel(
          id: 'MD_DIV',
          name: 'MD Division',
          abbreviation: 'MDD',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'md division',
          parentId: null,
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(rootOrg);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
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

        await tester.tap(find.byKey(const Key('org_row_MD_DIV')));
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('org_add_employee_button')),
        );
        await tester.tap(find.byKey(const Key('org_add_employee_button')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('user_add_modal_row_john@vetter.com')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('user_add_modal_save_button')));
        await tester.pumpAndSettle();

        expect(find.text('John Doe'), findsOneWidget);

        final dbJohn = harness.mockFirestore.getData(
          'users',
          'john@vetter.com',
        );
        expect(dbJohn, isNotNull);
        expect(dbJohn!['orgUnitId'], 'MD_DIV');
      },
    );

    testWidgets(
      'R4_HP_04: Set parent-child relationship (e.g. SVP division under MD division)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = E2ETestHarness();
        harness.seedAdminUser();

        final rootOrg = OrgUnitModel(
          id: 'MD_DIV',
          name: 'MD Division',
          abbreviation: 'MDD',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'md division',
          parentId: null,
          childIds: [],
          status: 'Active',
        );
        final childOrg = OrgUnitModel(
          id: 'CHILD_DEPT',
          name: 'Child Department',
          abbreviation: 'CDEPT',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: null,
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(rootOrg);
        harness.seedOrgUnit(childOrg);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
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

        await tester.tap(find.byKey(const Key('org_row_MD_DIV')));
        await tester.pumpAndSettle();

        final addChildButton = find.byKey(const Key('org_add_child_button'));
        await tester.ensureVisible(addChildButton);
        await tester.tap(addChildButton);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('child_modal_search_input')),
          'CHILD_DEPT',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('child_modal_row_CHILD_DEPT')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('child_modal_save_button')));
        await tester.pumpAndSettle();

        expect(find.text('Child Department'), findsOneWidget);

        final dbChild = harness.mockFirestore.getData('orgUnits', 'CHILD_DEPT');
        expect(dbChild, isNotNull);
        expect(dbChild!['parentId'], 'MD_DIV');

        final dbParent = harness.mockFirestore.getData('orgUnits', 'MD_DIV');
        expect(dbParent, isNotNull);
        expect(
          List<String>.from(dbParent!['childIds']).contains('CHILD_DEPT'),
          isTrue,
        );
      },
    );

    testWidgets(
      'R4_HP_05: Remove parent association clears parent field on child and places it in root list',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = E2ETestHarness();
        harness.seedAdminUser();

        final rootOrg = OrgUnitModel(
          id: 'MD_DIV',
          name: 'MD Division',
          abbreviation: 'MDD',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'md division',
          parentId: null,
          childIds: ['CHILD_DEPT'],
          status: 'Active',
        );
        final childOrg = OrgUnitModel(
          id: 'CHILD_DEPT',
          name: 'Child Department',
          abbreviation: 'CDEPT',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: 'MD_DIV',
          childIds: [],
          status: 'Active',
        );

        harness.seedOrgUnit(rootOrg);
        harness.seedOrgUnit(childOrg);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
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

        expect(find.byKey(const Key('org_row_MD_DIV')), findsOneWidget);
        expect(find.byKey(const Key('org_row_CHILD_DEPT')), findsOneWidget);

        await tester.tap(find.byKey(const Key('org_row_MD_DIV')));
        await tester.pumpAndSettle();

        expect(find.text('Child Department'), findsOneWidget);

        final childOverflowFinder = find.byKey(
          const Key('org_child_overflow_button_CHILD_DEPT'),
        );
        await tester.ensureVisible(childOverflowFinder);
        await tester.pumpAndSettle();
        await tester.tap(childOverflowFinder);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('org_child_remove_parent_button_CHILD_DEPT')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Child Department'), findsNothing);

        await tester.ensureVisible(
          find.byKey(const Key('org_detail_back_button')),
        );
        await tester.tap(find.byKey(const Key('org_detail_back_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('org_row_MD_DIV')), findsOneWidget);
        expect(find.byKey(const Key('org_row_CHILD_DEPT')), findsOneWidget);

        final dbChild = harness.mockFirestore.getData('orgUnits', 'CHILD_DEPT');
        expect(dbChild, isNotNull);
        expect(dbChild!['parentId'], isNull);
      },
    );

    testWidgets(
      'R3_HP_06: Manual page indicator input updates the current page correctly',
      (WidgetTester tester) async {
        final harness = E2ETestHarness();
        harness.seedAdminUser();
        for (int i = 1; i <= 7; i++) {
          harness.mockFirestore.setData('users', 'user$i@vetter.com', {
            'id': 'user$i',
            'fullName': 'User $i',
            'email': 'user$i@vetter.com',
            'title': 'Analyst',
            'status': 'Active',
            'role': 'User',
          });
        }

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
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

        // Page 1 users should be visible, Page 2 users should not
        expect(find.text('User 1'), findsOneWidget);
        expect(find.text('User 6'), findsNothing);

        // Update page input field manually to '2' and submit
        final pageInputFinder = find.byKey(
          const Key('user_pagination_pages_input'),
        );
        expect(pageInputFinder, findsOneWidget);
        await tester.enterText(pageInputFinder, '2');
        final TextField textField = tester.widget(pageInputFinder);
        textField.onSubmitted!('2');
        await tester.pumpAndSettle();

        // Page 2 users should be visible now, Page 1 users should not
        expect(find.text('User 6'), findsOneWidget);
        expect(find.text('User 1'), findsNothing);
      },
    );

    testWidgets('R4_HP_06: Edit Parent Org Unit using Search Modal', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final harness = E2ETestHarness();
      harness.seedAdminUser();

      final rootOrg = OrgUnitModel(
        id: 'MD_DIV',
        name: 'MD Division',
        abbreviation: 'MDD',
        headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
        type: 'md division',
        parentId: null,
        childIds: [],
        status: 'Active',
      );
      final childOrg = OrgUnitModel(
        id: 'CHILD_DEPT',
        name: 'Child Department',
        abbreviation: 'CDEPT',
        headOfEmail: 'child.head@vetter-pharma.com',
        type: 'department',
        parentId: null,
        childIds: [],
        status: 'Active',
      );
      harness.seedOrgUnit(rootOrg);
      harness.seedOrgUnit(childOrg);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const CapplaApp(),
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
      harness.container.read(currentAdminRouteProvider.notifier).state = 'orgs';
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('org_row_CHILD_DEPT')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('org_detail_edit_button')));
      await tester.pumpAndSettle();

      final parentField = find.byKey(const Key('org_detail_parent_input'));
      await tester.ensureVisible(parentField);
      await tester.tap(parentField);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('parent_modal_search_input')),
        'MD Division',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, 'MD Division'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('parent_modal_select_button')));
      await tester.pumpAndSettle();

      final saveButton = find.byKey(const Key('org_detail_save_button'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final dbChild = harness.mockFirestore.getData('orgUnits', 'CHILD_DEPT');
      expect(dbChild, isNotNull);
      expect(dbChild!['parentId'], 'MD_DIV');
    });
  });
}
