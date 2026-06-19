// ignore_for_file: unnecessary_brace_in_string_interps
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cappla/models/user_model.dart';
import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/core/providers/providers.dart';
import 'package:cappla/core/router/router.dart';
import 'package:cappla/core/router/router_paths.dart';
import 'package:cappla/main.dart';
import 'e2e_test_harness.dart';

void main() {
  group('E2E Tier 4: Real-World Scenarios', () {
    testWidgets('SCENARIO_01: New Department Onboarding', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final harness = E2ETestHarness();
      harness.seedAdminUser(); // Seed Malik the Admin

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const CapplaApp(),
        ),
      );

      // 1. Login as Admin Malik
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

      // 2. Navigate to Administration -> Org Units
      harness.container.read(selectedTabCollectionProvider.notifier).state =
          'Administration';
      harness.container.read(currentAdminRouteProvider.notifier).state = 'orgs';
      await tester.pumpAndSettle();

      // Create VP Division (seeded or created)
      final vpOrg = OrgUnitModel(
        id: 'VP_DIV',
        name: 'VP Division',
        abbreviation: 'VPD',
        headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
        type: 'vp division',
        childIds: [],
        status: 'Active',
      );
      harness.mockFirestore.setData('orgUnits', 'VP_DIV', vpOrg.toMap());
      await tester.pumpAndSettle();

      // Navigate to VP Division details
      harness.container.read(selectedOrgForDetailsProvider.notifier).state =
          vpOrg;
      harness.container
          .read(routerProvider)
          .go(RouterPaths.adminOrgDetailPath('VP_DIV'));
      harness.container.read(showDetailedOrgChildInputProvider.notifier).state =
          true;
      await tester.pumpAndSettle();

      // Seed Department DEPT_A and Team TEAM_A in firestore first
      final deptA = OrgUnitModel(
        id: 'DEPT_A',
        name: 'Child Department',
        abbreviation: 'CDEPT',
        headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
        type: 'department',
        childIds: [],
        status: 'Active',
      );
      harness.mockFirestore.setData('orgUnits', 'DEPT_A', deptA.toMap());

      final teamA = OrgUnitModel(
        id: 'TEAM_A',
        name: 'Child Team',
        abbreviation: 'CTEAM',
        headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
        type: 'team',
        childIds: [],
        status: 'Active',
      );
      harness.mockFirestore.setData('orgUnits', 'TEAM_A', teamA.toMap());
      await tester.pumpAndSettle();

      // Add Department "DEPT_A" via modal
      await tester.ensureVisible(find.byKey(const Key('org_add_child_button')));
      await tester.tap(find.byKey(const Key('org_add_child_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('child_modal_search_input')),
        'DEPT_A',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('child_modal_row_DEPT_A')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('child_modal_save_button')));
      await tester.pumpAndSettle();

      // Navigate to Department "DEPT_A" details
      final deptOrg = OrgUnitModel.fromMap(
        harness.mockFirestore.getData('orgUnits', 'DEPT_A')!,
      );
      harness.container.read(selectedOrgForDetailsProvider.notifier).state =
          deptOrg;
      harness.container
          .read(routerProvider)
          .go(RouterPaths.adminOrgDetailPath('DEPT_A'));
      await tester.pumpAndSettle();

      // Add Team "TEAM_A" via modal
      await tester.ensureVisible(find.byKey(const Key('org_add_child_button')));
      await tester.tap(find.byKey(const Key('org_add_child_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('child_modal_search_input')),
        'TEAM_A',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('child_modal_row_TEAM_A')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('child_modal_save_button')));
      await tester.pumpAndSettle();

      // Navigate to Administration -> Users to onboarding Sarah Connor
      harness.container.read(selectedTabCollectionProvider.notifier).state =
          'Administration';
      harness.container.read(currentAdminRouteProvider.notifier).state =
          'users';
      harness.container
              .read(showDetailedUserCreateFormProvider.notifier)
              .state =
          true;
      await tester.pumpAndSettle();

      // Create user Sarah Connor
      await tester.enterText(
        find.byKey(const Key('user_create_fullname_input')),
        'Sarah Connor Temp',
      );
      await tester.enterText(
        find.byKey(const Key('user_create_email_input')),
        'sarah.connor@vetter-pharma.com',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create_user_button')));
      await tester.pumpAndSettle();

      // Add Sarah to team TEAM_A
      final teamOrg = OrgUnitModel.fromMap(
        harness.mockFirestore.getData('orgUnits', 'TEAM_A')!,
      );
      harness.container.read(selectedOrgForDetailsProvider.notifier).state =
          teamOrg;
      harness.container
          .read(routerProvider)
          .go(RouterPaths.adminOrgDetailPath('TEAM_A'));
      await tester.pumpAndSettle();

      // Tapping "Add User" opens modal, select Sarah, and save
      await tester.ensureVisible(
        find.byKey(const Key('org_add_employee_button')),
      );
      await tester.tap(find.byKey(const Key('org_add_employee_button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sarah Connor Temp'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('user_add_modal_save_button')));
      await tester.pumpAndSettle();

      // Log out Malik the Admin
      await tester.tap(find.byKey(const Key('profile_dropdown_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile_menu_item_logout')));
      await tester.pumpAndSettle();

      // Seed password for Sarah Connor (so she can login)
      harness.mockAuth.registerUser(
        'sarah.connor@vetter-pharma.com',
        'SarahConnor123!',
      );

      // Login as Sarah
      await tester.enterText(
        find.byKey(const Key('login_email_input')),
        'sarah.connor@vetter-pharma.com',
      );
      await tester.tap(find.byKey(const Key('login_next_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login_password_input')),
        'SarahConnor123!',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      // Navigate to Sarah's Profile page
      await tester.tap(find.byKey(const Key('profile_dropdown_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile_menu_item_profile')));
      await tester.pumpAndSettle();

      // Edit profile to update Title and Full Name
      await tester.tap(find.byKey(const Key('profile_edit_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('profile_name_input')),
        'Sarah Connor',
      );
      await tester.enterText(
        find.byKey(const Key('profile_title_input')),
        'Team Lead',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile_save_button')));
      await tester.pumpAndSettle();

      // Verify Sarah's profile lists her unit and title
      expect(find.text('Sarah Connor'), findsOneWidget);
      expect(find.text('Team Lead'), findsOneWidget);
      expect(find.text('Child Team'), findsOneWidget);
    });

    testWidgets('SCENARIO_02: Department Reorganization', (
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

      // Seed DEPT_A, DEPT_B, and TEAM_B
      final deptA = OrgUnitModel(
        id: 'DEPT_A',
        name: 'Department A',
        abbreviation: 'DEPTA',
        headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
        type: 'department',
        childIds: ['TEAM_B'],
        status: 'Active',
      );
      final deptB = OrgUnitModel(
        id: 'DEPT_B',
        name: 'Department B',
        abbreviation: 'DEPTB',
        headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
        type: 'department',
        childIds: [],
        status: 'Active',
      );
      final teamB = OrgUnitModel(
        id: 'TEAM_B',
        name: 'Team B',
        abbreviation: 'TEAMB',
        headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
        type: 'team',
        parentId: 'DEPT_A',
        childIds: [],
        status: 'Active',
      );
      harness.seedOrgUnit(deptA);
      harness.seedOrgUnit(deptB);
      harness.seedOrgUnit(teamB);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const CapplaApp(),
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

      // Navigate to DEPT_A detail page
      harness.container.read(selectedTabCollectionProvider.notifier).state =
          'Administration';
      harness.container.read(currentAdminRouteProvider.notifier).state = 'orgs';
      harness.container.read(selectedOrgForDetailsProvider.notifier).state =
          deptA;
      harness.container
          .read(routerProvider)
          .go(RouterPaths.adminOrgDetailPath('DEPT_A'));
      await tester.pumpAndSettle();

      // Remove TEAM_B child association from DEPT_A
      final overflowBtn = find.byKey(
        const Key('org_child_overflow_button_TEAM_B'),
      );
      await tester.ensureVisible(overflowBtn);
      await tester.tap(overflowBtn);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('org_child_remove_parent_button_TEAM_B')),
      );
      await tester.pumpAndSettle();

      // Navigate back to Org Unit list, then to DEPT_B details
      harness.container.read(selectedTabCollectionProvider.notifier).state =
          'Administration';
      harness.container.read(currentAdminRouteProvider.notifier).state = 'orgs';
      await tester.pumpAndSettle();

      harness.container.read(selectedOrgForDetailsProvider.notifier).state =
          deptB;
      harness.container
          .read(routerProvider)
          .go(RouterPaths.adminOrgDetailPath('DEPT_B'));
      harness.container.read(showDetailedOrgChildInputProvider.notifier).state =
          true;
      await tester.pumpAndSettle();

      // Add TEAM_B as child to DEPT_B via modal
      await tester.ensureVisible(find.byKey(const Key('org_add_child_button')));
      await tester.tap(find.byKey(const Key('org_add_child_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('child_modal_search_input')),
        'TEAM_B',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('child_modal_row_TEAM_B')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('child_modal_save_button')));
      await tester.pumpAndSettle();

      // Verify db changes
      final db = harness.mockFirestore;
      final updatedDeptA = OrgUnitModel.fromMap(
        db.getData('orgUnits', 'DEPT_A')!,
      );
      final updatedDeptB = OrgUnitModel.fromMap(
        db.getData('orgUnits', 'DEPT_B')!,
      );
      final updatedTeamB = OrgUnitModel.fromMap(
        db.getData('orgUnits', 'TEAM_B')!,
      );

      expect(updatedDeptA.childIds, isNot(contains('TEAM_B')));
      expect(updatedDeptB.childIds, contains('TEAM_B'));
      expect(updatedTeamB.parentId, equals('DEPT_B'));
    });

    testWidgets('SCENARIO_03: Standard User Daily Log & Profile Update', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final harness = E2ETestHarness();
      final orgUnit = OrgUnitModel(
        id: 'DEPT_IT',
        name: 'IT Department',
        abbreviation: 'IT',
        headOfEmail: 'john.doe@vetter-pharma.com',
        type: 'department',
        childIds: [],
        status: 'Active',
      );
      harness.mockFirestore.setData('orgUnits', 'DEPT_IT', orgUnit.toMap());

      final standardUser = UserModel(
        id: 'john-doe-uuid-0000-0000-000000000000',
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

      // 1. Login as standard user
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

      // 2. Navigate tabs
      await tester.tap(find.byKey(const Key('nav_settings')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('activity_groups_title')), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav_planning')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('planning_page')), findsOneWidget);

      // 3. Open Profile
      await tester.tap(find.byKey(const Key('profile_dropdown_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile_menu_item_profile')));
      await tester.pumpAndSettle();

      // 4. Edit Title and Full Name
      await tester.tap(find.byKey(const Key('profile_edit_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('profile_name_input')),
        'John Doe Updated',
      );
      await tester.enterText(
        find.byKey(const Key('profile_title_input')),
        'Lead Analyst',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile_save_button')));
      await tester.pumpAndSettle();

      // Verify updates persist
      expect(find.text('John Doe Updated'), findsOneWidget);
      expect(find.text('Lead Analyst'), findsOneWidget);

      // 5. Verify direct navigation to admin route redirects back to home dashboard
      harness.container
          .read(routerProvider)
          .go(RouterPaths.adminUserDetailPath(standardUser.id));
      await tester.pumpAndSettle();

      // Verify we are back on shell
      expect(
        harness.container.read(selectedTabCollectionProvider),
        equals('Standard'),
      );
    });

    testWidgets('SCENARIO_04: Password Reset Recovery Flow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final harness = E2ETestHarness();
      final standardUser = UserModel(
        id: 'john-doe-uuid-0000-0000-000000000000',
        fullName: 'John Doe',
        email: 'john.doe@vetter-pharma.com',
        title: 'Specialist',
        status: 'Active',
        role: 'User',
      );
      harness.seedUser(standardUser, 'OldPassword123!');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const CapplaApp(),
        ),
      );

      // Enter email and navigate to password step
      await tester.enterText(
        find.byKey(const Key('login_email_input')),
        'john.doe@vetter-pharma.com',
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

      // Strength validation tests:
      // Weak password
      await tester.enterText(
        find.byKey(const Key('reset_new_password_input')),
        '123',
      );
      await tester.pumpAndSettle();
      expect(
        (tester.widget(find.byKey(const Key('password_strength_indicator')))
                as Text)
            .data,
        equals('Weak'),
      );

      // Medium password
      await tester.enterText(
        find.byKey(const Key('reset_new_password_input')),
        'abcdefg',
      );
      await tester.pumpAndSettle();
      expect(
        (tester.widget(find.byKey(const Key('password_strength_indicator')))
                as Text)
            .data,
        equals('Medium'),
      );

      // Strong password
      await tester.enterText(
        find.byKey(const Key('reset_new_password_input')),
        'NewPassword123!',
      );
      await tester.pumpAndSettle();
      expect(
        (tester.widget(find.byKey(const Key('password_strength_indicator')))
                as Text)
            .data,
        equals('Strong'),
      );

      // Save strong password
      await tester.tap(find.byKey(const Key('reset_password_button')));
      await tester.pumpAndSettle();
      expect(find.text('Reset email sent successfully.'), findsOneWidget);

      // Back to login
      await tester.tap(find.byKey(const Key('reset_back_button')));
      await tester.pumpAndSettle();

      // Try logging in using old password (should fail)
      await tester.enterText(
        find.byKey(const Key('login_email_input')),
        'john.doe@vetter-pharma.com',
      );
      await tester.tap(find.byKey(const Key('login_next_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login_password_input')),
        'OldPassword123!',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login_error_text')), findsOneWidget);

      // Log in using new password (should succeed)
      // Navigate back to Step 1 since we failed and are on Step 2
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login_email_input')),
        'john.doe@vetter-pharma.com',
      );
      await tester.tap(find.byKey(const Key('login_next_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login_password_input')),
        'NewPassword123!',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app_title')), findsOneWidget);
    });

    testWidgets('SCENARIO_05: Malicious Cycle Injection', (
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

      // Create hierarchy A -> B -> C (allowed to have parents to avoid type error)
      final orgA = OrgUnitModel(
        id: 'A',
        name: 'Unit A',
        abbreviation: 'UA',
        headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
        type: 'svp division',
        childIds: ['B'],
        status: 'Active',
      );
      final orgB = OrgUnitModel(
        id: 'B',
        name: 'Unit B',
        abbreviation: 'UB',
        headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
        type: 'vp division',
        parentId: 'A',
        childIds: ['C'],
        status: 'Active',
      );
      final orgC = OrgUnitModel(
        id: 'C',
        name: 'Unit C',
        abbreviation: 'UC',
        headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
        type: 'department',
        parentId: 'B',
        childIds: [],
        status: 'Active',
      );
      harness.seedOrgUnit(orgA);
      harness.seedOrgUnit(orgB);
      harness.seedOrgUnit(orgC);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const CapplaApp(),
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

      // Go to Unit C's detail page
      harness.container.read(selectedTabCollectionProvider.notifier).state =
          'Administration';
      harness.container.read(currentAdminRouteProvider.notifier).state = 'orgs';
      harness.container.read(selectedOrgForDetailsProvider.notifier).state =
          orgC;
      harness.container
          .read(routerProvider)
          .go(RouterPaths.adminOrgDetailPath('C'));
      harness.container.read(showDetailedOrgChildInputProvider.notifier).state =
          true;
      await tester.pumpAndSettle();

      // UI edit: add A as child of C (which forms cycle A -> B -> C -> A) via modal
      await tester.ensureVisible(find.byKey(const Key('org_add_child_button')));
      await tester.tap(find.byKey(const Key('org_add_child_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('child_modal_search_input')),
        'A',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('child_modal_row_A')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('child_modal_save_button')));
      await tester.pumpAndSettle();

      // Verify cycle warning is shown and A is not added
      expect(
        find.text('Cycle detected: Circular hierarchy not allowed.'),
        findsOneWidget,
      );
      expect(
        OrgUnitModel.fromMap(
          harness.mockFirestore.getData('orgUnits', 'C')!,
        ).childIds,
        isNot(contains('A')),
      );

      // Direct DB write of cycle should throw Exception
      final db = harness.mockFirestore;
      final cycleData = {
        'id': 'A',
        'name': 'Unit A',
        'abbreviation': 'UA',
        'headOfEmail': 'MalikJannico.Press@vetter-pharma.com',
        'type': 'svp division',
        'parentId': 'C', // Pointing A's parent to C
        'childIds': ['B'],
        'status': 'Active',
      };

      expect(
        () => db.setData('orgUnits', 'A', cycleData),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Cycle detected'),
          ),
        ),
      );
    });
  });
}
