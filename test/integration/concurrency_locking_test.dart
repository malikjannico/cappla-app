// File: test/integration/concurrency_locking_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cappla/main.dart';
import 'package:cappla/models/user_model.dart';
import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/core/providers/providers.dart';
import 'e2e_test_harness.dart';

void main() {
  group('Concurrency Locking System Integration Tests', () {
    late E2ETestHarness harness;

    setUp(() {
      harness = E2ETestHarness();
      harness.seedAdminUser();
    });

    tearDown(() {
      harness.clearAll();
    });

    testWidgets(
      'Activity lock prevents other users from editing and blocks employee view cells',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 1. Seed org, users, groups, category, activity
        final orgUnit = OrgUnitModel(
          id: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          name: 'IT Document & Quality Solutions',
          abbreviation: 'IT DQS',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'team',
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(orgUnit);

        final userA = UserModel(
          id: '00000000-0000-0000-0000-000000000000',
          fullName: 'Malik Jannico Press',
          email: 'MalikJannico.Press@vetter-pharma.com',
          title: 'Administrator',
          status: 'Active',
          role: 'Administrator',
          orgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        );
        harness.seedUser(userA, 'AdminPassword123!');

        final userB = UserModel(
          id: 'user-b-uuid',
          fullName: 'Jane Doe',
          email: 'jane.doe@vetter-pharma.com',
          title: 'Team Member',
          status: 'Active',
          role: 'Standard',
          orgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        );
        harness.seedUser(userB, 'Password123!');

        final actGroup = ActivityGroupModel(
          id: 'group_1',
          name: 'Packaging',
          ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          sharedOrgUnitIds: [],
          appliedOrgUnitIds: [],
          statusMap: {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
          createdBy: 'system',
          createdAt: DateTime.now(),
          lastModifiedBy: 'system',
          lastModifiedAt: DateTime.now(),
          order: 1,
        );
        harness.mockFirestore.setData(
          'activityGroups',
          'group_1',
          actGroup.toMap(),
        );

        final category = CategoryModel(
          id: 'category_1',
          name: 'Operation',
          ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          sharedOrgUnitIds: [],
          appliedOrgUnitIds: [],
          statusMap: {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
          createdBy: 'system',
          createdAt: DateTime.now(),
          lastModifiedBy: 'system',
          lastModifiedAt: DateTime.now(),
          order: 1,
        );
        harness.mockFirestore.setData(
          'categories',
          'category_1',
          category.toMap(),
        );

        final activity = ActivityModel(
          id: 'activity_1',
          name: 'Vial Labeling',
          activityGroupId: 'group_1',
          type: 'Limited',
          ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          sharedOrgUnitIds: [],
          appliedOrgUnitIds: [],
          statusMap: {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
          assignedUserEmails: [
            'MalikJannico.Press@vetter-pharma.com',
            'jane.doe@vetter-pharma.com',
          ],
          categoryId: 'category_1',
          createdBy: 'system',
          createdAt: DateTime.now(),
          lastModifiedBy: 'system',
          lastModifiedAt: DateTime.now(),
          order: 1,
        );
        harness.mockFirestore.setData(
          'activities',
          'activity_1',
          activity.toMap(),
        );

        // 2. Simulate User B (Jane Doe) holding a lock on activity_1
        final now = DateTime.now();
        final activityLock = LockModel(
          id: 'activity_activity_1_${now.year}_e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          userId: 'user-b-uuid',
          userEmail: 'jane.doe@vetter-pharma.com',
          userFullName: 'Jane Doe',
          lockType: 'activity',
          activityId: 'activity_1',
          activityIds: [],
          employeeEmails: [],
          year: now.year,
          orgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          lockedAt: now,
          expiresAt: now.add(const Duration(minutes: 5)),
        );
        harness.mockFirestore.setData(
          'locks',
          activityLock.id,
          activityLock.toMap(),
        );

        // 3. Pump App as User A (Malik Jannico Press)
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        // Log in as User A
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

        // Should be on Planning page, Activity view
        expect(find.byKey(const Key('planning_page')), findsOneWidget);
        expect(find.text('Vial Labeling'), findsOneWidget);

        // Check that Edit button for Vial Labeling shows "Locked by Jane Doe" and is disabled
        final editBtnFinder = find.byKey(
          const Key('activity_edit_button_activity_1'),
        );
        expect(editBtnFinder, findsOneWidget);
        final editBtn = tester.widget<FilledButton>(editBtnFinder);
        expect(editBtn.onPressed, isNull); // Disabled!
        expect(find.text('Locked by Jane Doe'), findsOneWidget);

        // Check that Assign button is also disabled
        final assignBtnFinder = find.byKey(
          const Key('activity_assign_button_activity_1'),
        );
        expect(assignBtnFinder, findsOneWidget);
        final assignBtn = tester.widget<FilledButton>(assignBtnFinder);
        expect(assignBtn.onPressed, isNull); // Disabled!

        // 4. Toggle to Employee View and verify cells are locked/greyed out
        await tester.tap(find.text('Employee').last);
        await tester.pumpAndSettle();

        // Click Edit in Employee View
        await tester.tap(find.byKey(const Key('employee_view_edit_button')));
        await tester.pumpAndSettle();

        // Verify that double-clicking on a cell of activity_1 for Malik Jannico does NOT enter edit mode
        // Let's find cell for row 4 (Malik) and col 1 (Jan)
        await tester.tap(find.byKey(const Key('employee_cell_4_1')));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.byKey(const Key('employee_cell_4_1')));
        await tester.pumpAndSettle();

        // It should NOT show the TextField because the cell is locked/read-only
        final cellEditField = find.byKey(
          const Key('edit_malikjannico.press@vetter-pharma.com_activity_1_1'),
        );
        expect(cellEditField, findsNothing);

        // 5. Release Lock and verify edit mode is now allowed
        harness.mockFirestore.deleteData('locks', activityLock.id);
        await tester.pumpAndSettle();

        // Double-click again
        await tester.tap(find.byKey(const Key('employee_cell_4_1')));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.byKey(const Key('employee_cell_4_1')));
        await tester.pumpAndSettle();

        // Now it SHOULD show the TextField!
        expect(
          find.byKey(
            const Key('edit_malikjannico.press@vetter-pharma.com_activity_1_1'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Employee lock prevents other users with overlapping selections from entering edit mode',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Seed setup
        final orgUnit = OrgUnitModel(
          id: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          name: 'IT Document & Quality Solutions',
          abbreviation: 'IT DQS',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'team',
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(orgUnit);

        final userA = UserModel(
          id: '00000000-0000-0000-0000-000000000000',
          fullName: 'Malik Jannico Press',
          email: 'MalikJannico.Press@vetter-pharma.com',
          title: 'Administrator',
          status: 'Active',
          role: 'Administrator',
          orgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        );
        harness.seedUser(userA, 'AdminPassword123!');

        final userB = UserModel(
          id: 'user-b-uuid',
          fullName: 'Jane Doe',
          email: 'jane.doe@vetter-pharma.com',
          title: 'Team Member',
          status: 'Active',
          role: 'Standard',
          orgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        );
        harness.seedUser(userB, 'Password123!');

        final actGroup = ActivityGroupModel(
          id: 'group_1',
          name: 'Packaging',
          ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          sharedOrgUnitIds: [],
          appliedOrgUnitIds: [],
          statusMap: {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
          createdBy: 'system',
          createdAt: DateTime.now(),
          lastModifiedBy: 'system',
          lastModifiedAt: DateTime.now(),
          order: 1,
        );
        harness.mockFirestore.setData(
          'activityGroups',
          'group_1',
          actGroup.toMap(),
        );

        final category = CategoryModel(
          id: 'category_1',
          name: 'Operation',
          ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          sharedOrgUnitIds: [],
          appliedOrgUnitIds: [],
          statusMap: {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
          createdBy: 'system',
          createdAt: DateTime.now(),
          lastModifiedBy: 'system',
          lastModifiedAt: DateTime.now(),
          order: 1,
        );
        harness.mockFirestore.setData(
          'categories',
          'category_1',
          category.toMap(),
        );

        final activity = ActivityModel(
          id: 'activity_1',
          name: 'Vial Labeling',
          activityGroupId: 'group_1',
          type: 'Limited',
          ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          sharedOrgUnitIds: [],
          appliedOrgUnitIds: [],
          statusMap: {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
          assignedUserEmails: ['MalikJannico.Press@vetter-pharma.com'],
          categoryId: 'category_1',
          createdBy: 'system',
          createdAt: DateTime.now(),
          lastModifiedBy: 'system',
          lastModifiedAt: DateTime.now(),
          order: 1,
        );
        harness.mockFirestore.setData(
          'activities',
          'activity_1',
          activity.toMap(),
        );

        // Simulate User B holding an employee lock covering Malik Jannico Press and activity_1
        final now = DateTime.now();
        final employeeLock = LockModel(
          id: 'employee_jane.doe@vetter-pharma.com_${now.year}_e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          userId: 'user-b-uuid',
          userEmail: 'jane.doe@vetter-pharma.com',
          userFullName: 'Jane Doe',
          lockType: 'employee',
          activityId: null,
          activityIds: ['activity_1'],
          employeeEmails: ['malikjannico.press@vetter-pharma.com'],
          year: now.year,
          orgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          lockedAt: now,
          expiresAt: now.add(const Duration(minutes: 5)),
        );
        harness.mockFirestore.setData(
          'locks',
          employeeLock.id,
          employeeLock.toMap(),
        );

        // Pump App as User A
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

        // Go to Employee View
        await tester.tap(find.text('Employee').last);
        await tester.pumpAndSettle();

        // Check that the Employee Edit button shows "Locked by Jane Doe" and is disabled
        final empEditBtnFinder = find.byKey(
          const Key('employee_view_edit_button'),
        );
        expect(empEditBtnFinder, findsOneWidget);
        final empEditBtn = tester.widget<FilledButton>(empEditBtnFinder);
        expect(empEditBtn.onPressed, isNull);
        expect(find.text('Locked by Jane Doe'), findsOneWidget);
      },
    );
  });
}
