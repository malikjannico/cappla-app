// File: test/integration/planning_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cappla/main.dart';
import 'package:cappla/models/user_model.dart';
import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/core/providers/providers.dart';
import 'e2e_test_harness.dart';

void main() {
  group('Capacity Plan Dashboard Integration Tests', () {
    late E2ETestHarness harness;

    setUp(() {
      harness = E2ETestHarness();
      harness.seedAdminUser();
    });

    tearDown(() {
      harness.clearAll();
    });

    testWidgets(
      'Activity and Employee Views lifecycle, cell editing and capacity calculations',
      (WidgetTester tester) async {
        // Set desktop screen size to prevent offscreen elements in horizontal scroll tables
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Seed organization unit and user matching default seed
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

        // Update admin user to be in the org unit
        final adminUser = UserModel(
          id: '00000000-0000-0000-0000-000000000000',
          fullName: 'Malik Jannico Press',
          email: 'MalikJannico.Press@vetter-pharma.com',
          title: 'Administrator',
          status: 'Active',
          role: 'Administrator',
          orgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        );
        harness.seedUser(adminUser, 'AdminPassword123!');

        // Seed activity group and activity with IT DQS
        final actGroup = ActivityGroupModel(
          id: '11111111-2222-3333-4444-555555555555',
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
          '11111111-2222-3333-4444-555555555555',
          actGroup.toMap(),
        );

        // Seed category
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
          id: '66666666-7777-8888-9999-000000000000',
          name: 'Vial Labeling',
          activityGroupId: '11111111-2222-3333-4444-555555555555',
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
          '66666666-7777-8888-9999-000000000000',
          activity.toMap(),
        );

        // Pump app
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

        // Should redirect to plan page since user is assigned to org unit
        expect(find.byKey(const Key('planning_page')), findsOneWidget);
        expect(find.text('Capacity Plan'), findsOneWidget);
        expect(find.text('Vial Labeling'), findsOneWidget);

        // Verify root background color is white
        final scaffold = tester.widget<Scaffold>(
          find.byKey(const Key('planning_page')),
        );
        expect(scaffold.backgroundColor, equals(const Color(0xFFFFFFFF)));

        // Verify Card container is removed in activity section
        expect(find.byType(Card), findsNothing);

        // Verify category is shown next to title inside the header Row
        final titleRow = find
            .ancestor(
              of: find.text('Vial Labeling'),
              matching: find.byType(Row),
            )
            .first;
        expect(
          find.descendant(of: titleRow, matching: find.text('Operation')),
          findsOneWidget,
        );

        // Verify activity name text styling is titleLarge
        final theme = Theme.of(
          tester.element(find.byKey(const Key('planning_page'))),
        );
        final activityText = tester.widget<Text>(find.text('Vial Labeling'));
        expect(
          activityText.style?.fontSize,
          equals(theme.textTheme.titleLarge?.fontSize),
        );

        // We should see Activity view toggle
        expect(find.text('Activity'), findsAtLeast(1));
        expect(find.text('Employee'), findsAtLeast(1));

        // Check default Demand row values
        expect(find.text('Demand'), findsAtLeast(1));

        // Toggle to Employee view
        await tester.tap(find.text('Employee').last);
        await tester.pumpAndSettle();

        // Verify Malik's tab is displayed even when he is the only selected employee
        expect(find.byKey(const Key('employee_tab_malikjannico.press@vetter-pharma.com')), findsOneWidget);

        // Verify Employee view layout and segmented scrolling (4 SingleChildScrollView widgets)
        expect(find.textContaining('Available Capacity'), findsOneWidget);
        expect(find.text('Planned Capacity'), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsAtLeast(4));

        // Click Edit in Employee view
        await tester.tap(find.byKey(const Key('employee_view_edit_button')));
        await tester.pumpAndSettle();

        // Double tap cell to enter typing mode
        await tester.tap(find.byKey(const Key('employee_cell_4_1')));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.byKey(const Key('employee_cell_4_1')));
        await tester.pumpAndSettle();

        // Enter value 10 in first month cell for Malik Jannico
        final cellKey = const Key(
          'edit_malikjannico.press@vetter-pharma.com_66666666-7777-8888-9999-000000000000_1',
        );
        await tester.enterText(find.byKey(cellKey), '10.0');
        await tester.pumpAndSettle();

        // Save edits
        await tester.tap(find.text('Save').last);
        await tester.pumpAndSettle();

        // Verify that value is persisted
        final allocDoc = harness.mockFirestore.getData(
          'planningAllocations',
          'malikjannico.press@vetter-pharma.com_66666666-7777-8888-9999-000000000000_${DateTime.now().year}',
        );
        expect(allocDoc, isNotNull);
        expect(allocDoc!['january'], equals(10.0));

        // Seed another user in the same org unit to test multi-employee view
        final otherUser = UserModel(
          id: 'other-user-uuid',
          fullName: 'Jane Doe',
          email: 'jane.doe@vetter-pharma.com',
          title: 'Team Member',
          status: 'Active',
          role: 'Standard',
          orgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        );
        harness.seedUser(otherUser, 'Password123!');

        // Pump again to rebuild with new seeded user
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Click Employee Filter Popup to add Jane Doe to selection
        final employeeFilter = find.byTooltip('Select Employee');
        expect(employeeFilter, findsOneWidget);
        await tester.tap(employeeFilter);
        await tester.pumpAndSettle();

        // Tap on Jane Doe item in popup menu to add her
        final janeItem = find.text('Jane Doe');
        await tester.tap(janeItem, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Now both Malik Jannico Press and Jane Doe are selected!
        // Verify tabs are displayed
        final malikTab = find.byKey(const Key('employee_tab_malikjannico.press@vetter-pharma.com'));
        final janeTab = find.byKey(const Key('employee_tab_jane.doe@vetter-pharma.com'));
        expect(malikTab, findsOneWidget);
        expect(janeTab, findsOneWidget);

        // Click on Jane Doe tab to select her
        await tester.tap(janeTab);
        await tester.pumpAndSettle();

        // Verify Jane Doe's name is displayed (her tab is highlighted / visible)
        expect(find.text('Jane Doe'), findsOneWidget);

        // Click on the close button to deselect Jane Doe
        final closeJaneBtn = find.byKey(const Key('deselect_employee_jane.doe@vetter-pharma.com'));
        expect(closeJaneBtn, findsOneWidget);
        await tester.tap(closeJaneBtn);
        await tester.pumpAndSettle();

        // Verify Jane Doe is no longer shown in the tabs
        expect(find.byKey(const Key('employee_tab_jane.doe@vetter-pharma.com')), findsNothing);

        // Verify that Employee export button is present
        final exportEmployeeBtn = find.byKey(
          const Key('export_csv_button_employee'),
        );
        expect(exportEmployeeBtn, findsOneWidget);
        await tester.tap(exportEmployeeBtn);
        await tester.pumpAndSettle();
        expect(find.text('Export as CSV'), findsOneWidget);
        await tester.tap(find.text('Export as CSV'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'UI Improvements: cell selection, tooltip alignment, rounded corners, and Settings nav active highlight',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Seed organization unit and user matching default seed
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

        final adminUser = UserModel(
          id: '00000000-0000-0000-0000-000000000000',
          fullName: 'Malik Jannico Press',
          email: 'MalikJannico.Press@vetter-pharma.com',
          title: 'Administrator',
          status: 'Active',
          role: 'Administrator',
          orgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        );
        harness.seedUser(adminUser, 'AdminPassword123!');

        final actGroup = ActivityGroupModel(
          id: '11111111-2222-3333-4444-555555555555',
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
          '11111111-2222-3333-4444-555555555555',
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
          id: '66666666-7777-8888-9999-000000000000',
          name: 'Vial Labeling',
          activityGroupId: '11111111-2222-3333-4444-555555555555',
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
          '66666666-7777-8888-9999-000000000000',
          activity.toMap(),
        );

        // Pump app
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

        // We are on Plan Activities page. Tapping a cell selects it.
        final cellKey = const Key(
          'cell_66666666-7777-8888-9999-000000000000_1_1',
        );
        expect(find.byKey(cellKey), findsOneWidget);
        await tester.tap(find.byKey(cellKey));
        await tester.pumpAndSettle();

        // Tooltip positioning presence check
        expect(find.byTooltip('Select Category'), findsOneWidget);

        // Verify that Activity export button is present
        final exportActivityBtn = find.byKey(
          const Key('export_csv_button_66666666-7777-8888-9999-000000000000'),
        );
        expect(exportActivityBtn, findsOneWidget);
        await tester.tap(exportActivityBtn);
        await tester.pumpAndSettle();
        expect(find.text('Export as CSV'), findsOneWidget);
        await tester.tap(find.text('Export as CSV'));
        await tester.pumpAndSettle();

        // Toggle to Employee view
        await tester.tap(find.text('Employee').last);
        await tester.pumpAndSettle();

        // Activities header cell has rounded corner via ClipRRect decoration
        final activitiesHeader = find.byKey(const Key('fixed_1'));
        expect(activitiesHeader, findsOneWidget);
        expect(
          find.descendant(
            of: activitiesHeader,
            matching: find.byType(ClipRRect),
          ),
          findsOneWidget,
        );

        // Settings navigation active highlight checks
        final settingsNavButton = find.byKey(const Key('nav_settings'));
        expect(settingsNavButton, findsOneWidget);
        await tester.tap(settingsNavButton);
        await tester.pumpAndSettle();

        final TextButton settingsBtn = tester.widget<TextButton>(
          find.byKey(const Key('nav_settings')),
        );
        final style = settingsBtn.style;
        expect(
          style?.foregroundColor?.resolve({}),
          equals(
            Theme.of(
              tester.element(find.byKey(const Key('nav_settings'))),
            ).colorScheme.primary,
          ),
        );
      },
    );
  });
}
