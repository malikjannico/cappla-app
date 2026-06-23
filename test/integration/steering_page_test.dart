// ignore_for_file: avoid_print
// File: test/integration/steering_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cappla/main.dart';
import 'package:cappla/models/user_model.dart';
import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/core/providers/providers.dart';
import 'package:cappla/core/router/router_paths.dart';
import 'package:cappla/core/router/router.dart';
import 'package:cappla/views/standard/reports_view.dart';
import 'package:cappla/models/activity_model.dart';
import 'package:cappla/models/activity_group_model.dart';
import 'package:cappla/models/category_model.dart';
import 'e2e_test_harness.dart';

void main() {
  group('Capacity Steering Reports and Dashboards Integration Tests', () {
    late E2ETestHarness harness;

    setUp(() {
      harness = E2ETestHarness();
      harness.seedAdminUser();
    });

    tearDown(() {
      harness.clearAll();
    });

    testWidgets(
      'Steering Views Layout, Filter Chips, Row Colors, Categories and Grand Totals',
      (WidgetTester tester) async {
        // Set desktop screen size
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Seed organization units before app launch to satisfy routing guards
        final orgDQS = OrgUnitModel(
          id: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          name: 'IT Document & Quality Solutions',
          abbreviation: 'IT DQS',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(orgDQS);

        final orgUnit1 = OrgUnitModel(
          id: 'org_unit_1',
          name: 'IT DQS Team A',
          abbreviation: 'IT DQS A',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'section',
          parentId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(orgUnit1);

        final orgUnit2 = OrgUnitModel(
          id: 'org_unit_2',
          name: 'IT DQS Team B',
          abbreviation: 'IT DQS B',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'team',
          parentId: 'org_unit_1',
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(orgUnit2);

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

        // Should redirect to plan page
        expect(find.byKey(const Key('planning_page')), findsOneWidget);

        // Seed Jane Doe in Team B
        final otherUser = UserModel(
          id: 'other_user_id',
          fullName: 'Jane Doe',
          email: 'jane.doe@vetter-pharma.com',
          title: 'Team Member',
          status: 'Active',
          role: 'Standard',
          orgUnitId: 'org_unit_2',
        );
        harness.seedUser(otherUser, 'Password123!');

        // Seed Activity Group
        final actGroup = ActivityGroupModel(
          id: 'group_1',
          name: 'Packaging Group',
          ownerOrgUnitId: 'org_unit_1',
          sharedOrgUnitIds: [],
          appliedOrgUnitIds: [],
          statusMap: {
            'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
            'org_unit_1': 'Active',
            'org_unit_2': 'Active',
          },
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

        // Seed Category
        final category = CategoryModel(
          id: 'category_1',
          name: 'Operation Category',
          ownerOrgUnitId: 'org_unit_1',
          sharedOrgUnitIds: [],
          appliedOrgUnitIds: [],
          statusMap: {
            'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
            'org_unit_1': 'Active',
            'org_unit_2': 'Active',
          },
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

        // Seed Activities in both OUs
        final activity1 = ActivityModel(
          id: 'act_1',
          name: 'Vial Labeling A',
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
        harness.mockFirestore.setData('activities', 'act_1', activity1.toMap());

        final activity2 = ActivityModel(
          id: 'act_2',
          name: 'Vial Labeling B',
          activityGroupId: 'group_1',
          type: 'Limited',
          ownerOrgUnitId: 'org_unit_2',
          sharedOrgUnitIds: [],
          appliedOrgUnitIds: [],
          statusMap: {'org_unit_2': 'Active'},
          assignedUserEmails: ['jane.doe@vetter-pharma.com'],
          categoryId: 'category_1',
          createdBy: 'system',
          createdAt: DateTime.now(),
          lastModifiedBy: 'system',
          lastModifiedAt: DateTime.now(),
          order: 1,
        );
        harness.mockFirestore.setData('activities', 'act_2', activity2.toMap());

        // 1. Navigate to Reports View
        harness.container.read(routerProvider).go(RouterPaths.reports);
        await tester.pumpAndSettle();

        // Print state info using public Ref
        final Element element = tester.element(
          find.byKey(const Key('reports_title_header')),
        );
        final reportsState = element
            .findAncestorStateOfType<ConsumerState<ReportsView>>();
        if (reportsState != null) {
          final allUsers =
              reportsState.ref.read(allUsersStreamProvider).value ?? [];
          print('allUsers count: ${allUsers.length}');
          for (final u in allUsers) {
            print(
              '  User: ${u.email} - status=${u.status} - org=${u.orgUnitId}',
            );
          }
          final allOrgs =
              reportsState.ref.read(orgUnitsStreamProvider).value ?? [];
          print('allOrgs count: ${allOrgs.length}');
          for (final o in allOrgs) {
            print(
              '  Org: ${o.id} - name=${o.name} - parent=${o.parentId} - childIds=${o.childIds}',
            );
          }
          final allActivities =
              reportsState.ref.read(activitiesStreamProvider).value ?? [];
          print('allActivities count: ${allActivities.length}');
          for (final act in allActivities) {
            print(
              '  Activity: ${act.id} - name=${act.name} - owner=${act.ownerOrgUnitId} - statusMap=${act.statusMap}',
            );
          }
          final allGroups =
              reportsState.ref.read(activityGroupsStreamProvider).value ?? [];
          print('allGroups count: ${allGroups.length}');
          for (final g in allGroups) {
            print(
              '  Group: ${g.id} - name=${g.name} - statusMap=${g.statusMap}',
            );
          }
        }

        // Verify page title is present
        expect(find.byKey(const Key('reports_title_header')), findsOneWidget);
        expect(find.text('Reports'), findsOneWidget);

        // Verify that three sections exist: Activity Groups, Categories, Employees
        // (NWidgets(2) since they appear both in section headers and column headers)
        expect(find.text('Activity Groups'), findsNWidgets(2));
        expect(find.text('Categories'), findsNWidgets(2));
        expect(find.text('Employees'), findsNWidgets(2));

        // Verify that the Year chip is followed by the Organization Unit chip in all three sections
        expect(
          find.byKey(const Key('filter_ag_year_dropdown')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('filter_ag_org_unit_dropdown')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('filter_cat_year_dropdown')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('filter_cat_org_unit_dropdown')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('filter_emp_year_dropdown')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('filter_emp_org_unit_dropdown')),
          findsOneWidget,
        );

        // Verify corner clipping (using ClipRRect in layout)
        final clipRRectFinder = find.byType(ClipRRect);
        expect(
          clipRRectFinder,
          findsAtLeast(3),
        ); // One for each steering section table container

        // Verify colors of the table rows (Available Capacity, Planned Capacity, Delta)
        final theme = Theme.of(
          tester.element(find.byKey(const Key('reports_title_header'))),
        );

        // Available Capacity should use tertiary
        final availableCapacityContainer = tester.widget<Container>(
          find
              .ancestor(
                of: find.textContaining('Available Capacity').first,
                matching: find.byType(Container),
              )
              .at(1),
        );
        final availableBoxDecoration =
            availableCapacityContainer.decoration as BoxDecoration?;
        expect(
          availableBoxDecoration?.color,
          equals(theme.colorScheme.tertiary),
        );

        // Planned Capacity should use primary
        final plannedCapacityContainer = tester.widget<Container>(
          find
              .ancestor(
                of: find.textContaining('Planned Capacity').first,
                matching: find.byType(Container),
              )
              .at(1),
        );
        final plannedBoxDecoration =
            plannedCapacityContainer.decoration as BoxDecoration?;
        expect(
          plannedBoxDecoration?.color,
          equals(theme.colorScheme.primary),
        );

        // Delta should use transparent
        final deltaContainer = tester.widget<Container>(
          find
              .ancestor(
                of: find.textContaining('Delta').first,
                matching: find.byType(Container),
              )
              .at(1),
        );
        final deltaBoxDecoration = deltaContainer.decoration as BoxDecoration?;
        expect(deltaBoxDecoration?.color, equals(Colors.transparent));

        // Verify multi-org selection results in grand total rows
        expect(find.text('Total'), findsAtLeast(3));
        expect(find.textContaining('Total Available Capacity'), findsAtLeast(3));
        expect(find.textContaining('Total Planned Capacity'), findsAtLeast(3));
        expect(find.textContaining('Total Delta'), findsAtLeast(3));

        // Verify that three-dots CSV export buttons exist on Reports page
        final exportAgButton = find.byKey(
          const Key('export_csv_button_activity_groups'),
        );
        final exportCatButton = find.byKey(
          const Key('export_csv_button_categories'),
        );
        final exportEmpButton = find.byKey(
          const Key('export_csv_button_employees'),
        );
        expect(exportAgButton, findsOneWidget);
        expect(exportCatButton, findsOneWidget);
        expect(exportEmpButton, findsOneWidget);

        // Tap on the Activity Groups export button and select Export as CSV
        await tester.tap(exportAgButton);
        await tester.pumpAndSettle();
        expect(find.text('Export as CSV'), findsOneWidget);
        await tester.tap(find.text('Export as CSV'));
        await tester.pumpAndSettle();

        // 2. Navigate to Dashboard View
        harness.container.read(routerProvider).go(RouterPaths.dashboards);
        await tester.pumpAndSettle();

        // Verify Dashboard header is present
        expect(find.byKey(const Key('dashboard_title_header')), findsOneWidget);
        expect(find.text('Dashboard'), findsOneWidget);

        // Verify that the Year chip is followed by the Organization Unit chip on dashboards page
        expect(
          find.byKey(const Key('filter_dash_year_dropdown')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('filter_dash_org_unit_dropdown')),
          findsOneWidget,
        );

        // Verify KPI Cards details: available, planned, utilization, delta
        expect(find.text('Available Capacity'), findsAtLeast(1));
        expect(find.text('Planned Capacity'), findsAtLeast(1));
        expect(find.text('Utilization Rate'), findsAtLeast(1));
        expect(find.text('Capacity Delta'), findsAtLeast(1));

        // Verify that NO icons are rendered inside KPI Cards
        expect(find.byIcon(Icons.calendar_today), findsNothing);
        expect(find.byIcon(Icons.assignment), findsNothing);
        expect(find.byIcon(Icons.trending_up), findsNothing);
        expect(find.byIcon(Icons.difference), findsNothing);
      },
    );

    testWidgets(
      'Reports View Sorting (Activity Groups by order, Categories and Employees alphabetically A-Z) and Footer copyright Vetter Pharma',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Seed organization units before app launch to satisfy routing guards
        final orgDQS = OrgUnitModel(
          id: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          name: 'IT Document & Quality Solutions',
          abbreviation: 'IT DQS',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'department',
          parentId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(orgDQS);

        final orgUnit1 = OrgUnitModel(
          id: 'org_unit_1',
          name: 'IT DQS Team A',
          abbreviation: 'IT DQS A',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'section',
          parentId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(orgUnit1);

        final orgUnit2 = OrgUnitModel(
          id: 'org_unit_2',
          name: 'IT DQS Team B',
          abbreviation: 'IT DQS B',
          headOfEmail: 'MalikJannico.Press@vetter-pharma.com',
          type: 'team',
          parentId: 'org_unit_1',
          childIds: [],
          status: 'Active',
        );
        harness.seedOrgUnit(orgUnit2);

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

        // Seed second employee: Abby (comes first alphabetically compared to Malik)
        final otherUser = UserModel(
          id: 'abby-uuid',
          fullName: 'Abby Admin',
          email: 'abby.admin@vetter-pharma.com',
          title: 'Developer',
          status: 'Active',
          role: 'Standard',
          orgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        );
        harness.seedUser(otherUser, 'AbbyPassword123!');

        // Seed two activity groups:
        // Group B: order 2, name 'B Group'
        // Group A: order 1, name 'A Group' (comes first by order, even though we seed B first)
        final groupB = ActivityGroupModel(
          id: 'group_b',
          name: 'B Group',
          ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          sharedOrgUnitIds: [],
          appliedOrgUnitIds: [],
          statusMap: {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
          createdBy: 'system',
          createdAt: DateTime.now(),
          lastModifiedBy: 'system',
          lastModifiedAt: DateTime.now(),
          order: 2,
        );
        harness.mockFirestore.setData('activityGroups', 'group_b', groupB.toMap());

        final groupA = ActivityGroupModel(
          id: 'group_a',
          name: 'A Group',
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
        harness.mockFirestore.setData('activityGroups', 'group_a', groupA.toMap());

        // Seed categories:
        // Cat B: name 'Beta Cat'
        // Cat A: name 'Alpha Cat' (comes first alphabetically, even though we seed B first)
        final catB = CategoryModel(
          id: 'cat_b',
          name: 'Beta Cat',
          ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          sharedOrgUnitIds: [],
          appliedOrgUnitIds: [],
          statusMap: {
            'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
          },
          createdBy: 'system',
          createdAt: DateTime.now(),
          lastModifiedBy: 'system',
          lastModifiedAt: DateTime.now(),
          order: 2,
        );
        harness.mockFirestore.setData('categories', 'cat_b', catB.toMap());

        final catA = CategoryModel(
          id: 'cat_a',
          name: 'Alpha Cat',
          ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          sharedOrgUnitIds: [],
          appliedOrgUnitIds: [],
          statusMap: {
            'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
          },
          createdBy: 'system',
          createdAt: DateTime.now(),
          lastModifiedBy: 'system',
          lastModifiedAt: DateTime.now(),
          order: 1,
        );
        harness.mockFirestore.setData('categories', 'cat_a', catA.toMap());

        // Seed activities to bind everything
        final act1 = ActivityModel(
          id: 'act_1',
          name: 'Activity A',
          activityGroupId: 'group_a',
          type: 'Standard',
          ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          sharedOrgUnitIds: [],
          appliedOrgUnitIds: [],
          statusMap: {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
          assignedUserEmails: ['MalikJannico.Press@vetter-pharma.com'],
          categoryId: 'cat_a',
          createdBy: 'system',
          createdAt: DateTime.now(),
          lastModifiedBy: 'system',
          lastModifiedAt: DateTime.now(),
          order: 1,
        );
        harness.mockFirestore.setData('activities', 'act_1', act1.toMap());

        final act2 = ActivityModel(
          id: 'act_2',
          name: 'Activity B',
          activityGroupId: 'group_b',
          type: 'Standard',
          ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
          sharedOrgUnitIds: [],
          appliedOrgUnitIds: [],
          statusMap: {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
          assignedUserEmails: ['abby.admin@vetter-pharma.com'],
          categoryId: 'cat_b',
          createdBy: 'system',
          createdAt: DateTime.now(),
          lastModifiedBy: 'system',
          lastModifiedAt: DateTime.now(),
          order: 2,
        );
        harness.mockFirestore.setData('activities', 'act_2', act2.toMap());

        // Pump app
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Log in
        await tester.enterText(find.byKey(const Key('login_email_input')), 'MalikJannico.Press@vetter-pharma.com');
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('login_password_input')), 'AdminPassword123!');
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Navigate to Reports View
        harness.container.read(routerProvider).go(RouterPaths.reports);
        await tester.pumpAndSettle();

        // Verify footer copyright text
        expect(
          find.textContaining('Vetter Pharma-Fertigung GmbH & Co. KG'),
          findsAtLeast(1),
        );

        // We want to verify the display order of the rows in the three tables.
        // The first table is Activity Groups. Rows: 'A Group', then 'B Group'.
        expect(find.text('A Group'), findsAtLeast(1));
        expect(find.text('B Group'), findsAtLeast(1));

        // The second table is Categories. Rows: 'Alpha Cat', then 'Beta Cat'.
        expect(find.text('Alpha Cat'), findsAtLeast(1));
        expect(find.text('Beta Cat'), findsAtLeast(1));

        // The third table is Employees. Rows: 'Abby Admin', then 'Malik Jannico Press'.
        expect(find.text('Abby Admin'), findsAtLeast(1));
        expect(find.text('Malik Jannico Press'), findsAtLeast(1));

        // Check relative positions of the text to confirm sorting order in the widget tree.
        final aGroupPos = tester.getCenter(find.text('A Group').first);
        final bGroupPos = tester.getCenter(find.text('B Group').first);
        expect(aGroupPos.dy, lessThan(bGroupPos.dy));

        final alphaCatPos = tester.getCenter(find.text('Alpha Cat').first);
        final betaCatPos = tester.getCenter(find.text('Beta Cat').first);
        expect(alphaCatPos.dy, lessThan(betaCatPos.dy));

        final abbyPos = tester.getCenter(find.text('Abby Admin').first);
        final malikPos = tester.getCenter(find.text('Malik Jannico Press').first);
        expect(abbyPos.dy, lessThan(malikPos.dy));
      },
    );
  });
}
