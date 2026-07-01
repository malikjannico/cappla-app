// ignore_for_file: unnecessary_brace_in_string_interps
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/core/providers/providers.dart';
import 'package:cappla/core/router/router.dart';
import 'e2e_test_harness.dart';
import 'package:cappla/main.dart';

void main() {
  group('E2E Tier 3: Combination & Cross-Feature Tests', () {
    testWidgets('T3.1: Org Unit deactivation and cascade propagation', (
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

      // Create parent and child units
      final parentOrg = OrgUnitModel(
        id: 'PARENT_DIV',
        name: 'Parent Division',
        abbreviation: 'PDIV',
        headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
        type: 'md division',
        childIds: ['CHILD_DIV'],
        status: 'Active',
      );
      final childOrg = OrgUnitModel(
        id: 'CHILD_DIV',
        name: 'Child Division',
        abbreviation: 'CDIV',
        headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
        type: 'svp division',
        parentId: 'PARENT_DIV',
        childIds: [],
        status: 'Active',
      );
      harness.seedOrgUnit(parentOrg);
      harness.seedOrgUnit(childOrg);

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

      harness.container.read(currentAdminRouteProvider.notifier).state = 'orgs';
      harness.container.read(routerProvider).go('/admin/orgs');
      await tester.pumpAndSettle();

      // Verify parent status is Active
      final db = harness.mockFirestore;
      expect(
        OrgUnitModel.fromMap(db.getData('orgUnits', 'PARENT_DIV')!).status,
        equals('Active'),
      );
      expect(
        OrgUnitModel.fromMap(db.getData('orgUnits', 'CHILD_DIV')!).status,
        equals('Active'),
      );

      // Toggle parent status to Inactive
      await tester.tap(
        find.byKey(const Key('org_row_overflow_button_PARENT_DIV')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('org_row_toggle_status_item_PARENT_DIV')),
      );
      await tester.pumpAndSettle();

      // Verify parent and child status are now Inactive in firestore
      expect(
        OrgUnitModel.fromMap(db.getData('orgUnits', 'PARENT_DIV')!).status,
        equals('Inactive'),
      );
      expect(
        OrgUnitModel.fromMap(db.getData('orgUnits', 'CHILD_DIV')!).status,
        equals('Inactive'),
      );
    });

    testWidgets('T3.2: User association and Org Unit deactivation warning', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final harness = E2ETestHarness();

      // Create user associated with org unit
      final standardUser = UserModel(
        id: 'sarah.connor@vetter-pharma.com',
        fullName: 'Sarah Connor',
        email: 'sarah.connor@vetter-pharma.com',
        title: 'Specialist',
        status: 'Active',
        role: 'User',
        orgUnitId: 'DEPT_A',
      );
      final orgUnit = OrgUnitModel(
        id: 'DEPT_A',
        name: 'Department A',
        abbreviation: 'DEPTA',
        headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
        type: 'department',
        childIds: [],
        status: 'Inactive', // Seeded as inactive
      );
      harness.seedUser(standardUser, 'SarahCon123!');
      harness.seedOrgUnit(orgUnit);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const CapplaApp(),
        ),
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
        'SarahCon123!',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      // Navigate to My Profile
      await tester.tap(find.byKey(const Key('profile_dropdown_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile_menu_item_profile')));
      await tester.pumpAndSettle();

      // Verify the warning label is displayed
      expect(
        find.byKey(const Key('profile_org_inactive_warning')),
        findsOneWidget,
      );
      expect(
        find.text('Warning: Associated organization unit is inactive.'),
        findsOneWidget,
      );
    });

    testWidgets('T3.3: Role upgrade and active UI navigation refresh', (
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
        headOfEmail: 'manager@vetter.com',
        type: 'department',
        childIds: [],
        status: 'Active',
      );
      harness.mockFirestore.setData('orgUnits', 'DEPT_IT', orgUnit.toMap());
      final standardUser = UserModel(
        id: 'sarah.connor@vetter-pharma.com',
        fullName: 'Sarah Connor',
        email: 'sarah.connor@vetter-pharma.com',
        title: 'Specialist',
        status: 'Active',
        role: 'User',
        orgUnitId: 'DEPT_IT',
      );
      harness.seedUser(standardUser, 'SarahCon123!');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const CapplaApp(),
        ),
      );

      // Login as standard user
      await tester.enterText(
        find.byKey(const Key('login_email_input')),
        'sarah.connor@vetter-pharma.com',
      );
      await tester.tap(find.byKey(const Key('login_next_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login_password_input')),
        'SarahCon123!',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      // Check dropdown is not visible for standard user
      expect(find.byKey(const Key('tab_collection_dropdown')), findsNothing);

      // Upgrade user's role to Administrator dynamically mid-session
      final upgradedUser = UserModel(
        id: 'sarah.connor@vetter-pharma.com',
        fullName: 'Sarah Connor',
        email: 'sarah.connor@vetter-pharma.com',
        title: 'Specialist',
        status: 'Active',
        role: 'Administrator',
        orgUnitId: 'DEPT_IT',
      );
      harness.mockFirestore.setData(
        'users',
        upgradedUser.email,
        upgradedUser.toMap(),
      );
      await tester.pumpAndSettle();

      // Check tab collection dropdown now has the "Administration" option
      await tester.tap(find.byKey(const Key('tab_collection_dropdown')));
      await tester.pumpAndSettle();
      expect(find.text('Administration'), findsOneWidget);
    });

    testWidgets('T3.4: Parent association removal and promotion to root', (
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

      final parentOrg = OrgUnitModel(
        id: 'PARENT_DIV',
        name: 'Parent Division',
        abbreviation: 'PDIV',
        headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
        type: 'md division',
        childIds: ['CHILD_DIV'],
        status: 'Active',
      );
      final childOrg = OrgUnitModel(
        id: 'CHILD_DIV',
        name: 'Child Division',
        abbreviation: 'CDIV',
        headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
        type: 'svp division',
        parentId: 'PARENT_DIV',
        childIds: [],
        status: 'Active',
      );
      harness.seedOrgUnit(parentOrg);
      harness.seedOrgUnit(childOrg);

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

      harness.container.read(currentAdminRouteProvider.notifier).state = 'orgs';
      harness.container.read(routerProvider).go('/admin/orgs');
      await tester.pumpAndSettle();

      // Root list should contain PARENT_DIV and CHILD_DIV
      expect(find.text('Parent Division'), findsOneWidget);
      expect(find.text('Child Division'), findsOneWidget);

      // Go to parent details
      await tester.tap(find.byKey(const Key('org_row_PARENT_DIV')));
      await tester.pumpAndSettle();

      // Under Child Units, tap link_off on child
      expect(find.text('Child Division'), findsOneWidget);
      final childOverflowFinder = find.byKey(
        const Key('org_child_overflow_button_CHILD_DIV'),
      );
      await tester.ensureVisible(childOverflowFinder);
      await tester.pumpAndSettle();
      await tester.tap(childOverflowFinder);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('org_child_remove_parent_button_CHILD_DIV')),
      );
      await tester.pumpAndSettle();

      // Verify child removed from parent children list
      expect(find.text('Child Division'), findsNothing);

      // Go back to Org Admin root list
      await tester.ensureVisible(
        find.byKey(const Key('org_detail_back_button')),
      );
      await tester.tap(find.byKey(const Key('org_detail_back_button')));
      await tester.pumpAndSettle();

      // Verify child is promoted to root (listed on the main Org Unit Admin page)
      expect(find.text('Parent Division'), findsOneWidget);
      expect(find.text('Child Division'), findsOneWidget);
    });

    testWidgets('T3.5: Dynamic "Head of" labels matching the Org Unit Type', (
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

      final types = [
        'md division',
        'svp division',
        'vp division',
        'department',
        'group',
        'team',
      ];
      final expectedLabels = [
        'Managing Director',
        'SVP',
        'VP',
        'Director',
        'Head of',
        'Team Lead',
      ];

      for (int i = 0; i < types.length; i++) {
        final org = OrgUnitModel(
          id: 'ORG_${i}',
          name: 'Org Unit ${i}',
          abbreviation: 'O${i}',
          headOfEmail: 'head_${i}@vetter.com',
          type: types[i],
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(org);
      }

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

      for (int i = 0; i < types.length; i++) {
        harness.container.read(currentAdminRouteProvider.notifier).state = 'orgs';
        harness.container.read(routerProvider).go('/admin/orgs');
        await tester.pumpAndSettle();

        // Go to Org details
        if (i >= 5) {
          await tester.tap(find.byKey(const Key('org_page_forward')));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(Key('org_row_ORG_${i}')));
        await tester.pumpAndSettle();

        // Verify headOf dynamic label
        final headField = tester.widget<TextField>(
          find.byKey(const Key('org_detail_head')),
        );
        expect(headField.controller?.text, 'head_${i}@vetter.com');
        expect(headField.decoration?.labelText, expectedLabels[i]);

        // Back
        await tester.ensureVisible(
          find.byKey(const Key('org_detail_back_button')),
        );
        await tester.tap(find.byKey(const Key('org_detail_back_button')));
        await tester.pumpAndSettle();
      }
    });
  });
}
