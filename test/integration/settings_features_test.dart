import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cappla/main.dart';
import 'package:cappla/models/org_unit_model.dart';
import 'package:cappla/core/providers/providers.dart';
import 'e2e_test_harness.dart';

void main() {
  group('Settings Features & Sharing Integration Tests', () {
    late E2ETestHarness harness;

    setUp(() {
      harness = E2ETestHarness();

      // Seed organization units
      final orgA = OrgUnitModel(
        id: 'ORG_A',
        name: 'Organization A',
        abbreviation: 'OA',
        headOfEmail: 'head.a@vetter.com',
        type: 'department',
        childIds: [],
        status: 'Active',
      );
      final orgB = OrgUnitModel(
        id: 'ORG_B',
        name: 'Organization B',
        abbreviation: 'OB',
        headOfEmail: 'head.b@vetter.com',
        type: 'department',
        childIds: [],
        status: 'Active',
      );
      harness.seedOrgUnit(orgA);
      harness.seedOrgUnit(orgB);

      // Seed users
      final userA = UserModel(
        id: 'user_a_uuid',
        fullName: 'Head A',
        email: 'head.a@vetter.com',
        title: 'Director A',
        status: 'Active',
        role: 'User',
        orgUnitId: 'ORG_A',
      );
      final userB = UserModel(
        id: 'user_b_uuid',
        fullName: 'Head B',
        email: 'head.b@vetter.com',
        title: 'Director B',
        status: 'Active',
        role: 'User',
        orgUnitId: 'ORG_B',
      );
      harness.seedUser(userA, 'Password123!');
      harness.seedUser(userB, 'Password123!');
    });

    testWidgets(
      'T_SET_01: Category lifecycle, edit, and deletion constraints',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        // Login as Head A
        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'head.a@vetter.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'Password123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Navigate to Settings
        await tester.tap(find.byKey(const Key('nav_settings')));
        await tester.pumpAndSettle();

        // Go to Categories tab
        await tester.tap(find.byKey(const Key('nav_rail_categories')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('categories_title')), findsOneWidget);

        // Create Category
        await tester.tap(find.byKey(const Key('create_category_button')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('category_create_name_input')),
          'Cat A',
        );
        await tester.tap(find.byKey(const Key('category_create_button')));
        await tester.pumpAndSettle();

        // Category should be created and listed
        expect(find.text('Cat A'), findsOneWidget);

        // Tap on Category Row to view details
        final catList = harness.mockFirestore.collections['categories']!.values
            .toList();
        final catId =
            catList.firstWhere((c) => c['name'] == 'Cat A')['id'] as String;

        await tester.tap(find.byKey(Key('category_row_$catId')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('category_detail_title')), findsOneWidget);
        expect(
          find.byKey(const Key('category_detail_created_by')),
          findsOneWidget,
        );

        // Edit Category
        await tester.tap(find.byKey(const Key('category_detail_edit_button')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('category_edit_name_input')),
          'Cat A Edit',
        );
        await tester.tap(find.byKey(const Key('category_edit_save_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('category_detail_title')), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('category_detail_title')))
              .data,
          equals('Cat A Edit'),
        );

        // Back to list
        await tester.tap(find.byKey(const Key('category_detail_back_button')));
        await tester.pumpAndSettle();

        // Try deleting category (should succeed because it has no activities)
        await tester.tap(
          find.byKey(Key('category_row_overflow_button_$catId')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('category_row_delete_item_$catId')));
        await tester.pumpAndSettle();

        expect(find.text('Cat A Edit'), findsNothing);
      },
    );

    testWidgets(
      'T_SET_02: Activity Group lifecycle, cascade deactivation, and deactivation constraints',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        // Login as Head A
        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'head.a@vetter.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'Password123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Navigate to Settings
        await tester.tap(find.byKey(const Key('nav_settings')));
        await tester.pumpAndSettle();

        // Create Category first
        await tester.tap(find.byKey(const Key('nav_rail_categories')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('create_category_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('category_create_name_input')),
          'Category X',
        );
        await tester.tap(find.byKey(const Key('category_create_button')));
        await tester.pumpAndSettle();

        final catList = harness.mockFirestore.collections['categories']!.values
            .toList();
        final catId =
            catList.firstWhere((c) => c['name'] == 'Category X')['id']
                as String;

        // Go to Activities tab
        await tester.tap(find.byKey(const Key('nav_rail_activities')));
        await tester.pumpAndSettle();

        // Create Activity Group
        await tester.tap(find.byKey(const Key('create_activity_group_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('activity_group_create_name_input')),
          'Group A',
        );
        await tester.tap(find.byKey(const Key('activity_group_create_button')));
        await tester.pumpAndSettle();

        expect(find.text('Group A'), findsOneWidget);

        final groupList = harness
            .mockFirestore
            .collections['activityGroups']!
            .values
            .toList();
        final groupId =
            groupList.firstWhere((g) => g['name'] == 'Group A')['id'] as String;

        // Tap on Group A row to open detail view
        await tester.tap(find.byKey(Key('activity_group_row_$groupId')));
        await tester.pumpAndSettle();

        // Create Activity under Group A
        await tester.tap(find.byKey(const Key('create_activity_button')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('activity_create_name_input')),
          'Activity X',
        );
        // Category selection modal
        await tester.tap(
          find.byKey(const Key('activity_create_category_input')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('category_select_modal_row_$catId')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('category_modal_select_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('activity_create_button')));
        await tester.pumpAndSettle();

        expect(find.text('Activity X'), findsOneWidget);

        final actList = harness.mockFirestore.collections['activities']!.values
            .toList();
        final actId =
            actList.firstWhere((a) => a['name'] == 'Activity X')['id']
                as String;

        // Try deleting category (should fail because it is used by Activity X)
        await tester.tap(
          find.byKey(const Key('activity_group_detail_back_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('nav_rail_categories')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(Key('category_row_overflow_button_$catId')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('category_row_delete_item_$catId')));
        await tester.pumpAndSettle();

        // Error banner or toast should show, category still exists
        expect(find.text('Category X'), findsOneWidget);

        // Back to Activities
        await tester.tap(find.byKey(const Key('nav_rail_activities')));
        await tester.pumpAndSettle();

        // Try deleting Activity Group (should fail because it has activities)
        await tester.tap(
          find.byKey(Key('activity_group_row_overflow_button_$groupId')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(Key('activity_group_row_delete_item_$groupId')),
        );
        await tester.pumpAndSettle();

        // Group A still exists
        expect(find.text('Group A'), findsOneWidget);

        // Verify cascade deactivation
        // Go to detail view
        await tester.tap(find.byKey(Key('activity_group_row_$groupId')));
        await tester.pumpAndSettle();

        // Deactivate group A
        await tester.tap(
          find.byKey(const Key('activity_group_detail_overflow_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('activity_group_detail_toggle_status_item')),
        );
        await tester.pumpAndSettle();

        // Group status should be Inactive
        expect(
          find.byKey(const Key('activity_group_detail_status_label')),
          findsOneWidget,
        );
        final groupStatusLabel = tester.widget<Text>(
          find.byKey(const Key('activity_group_detail_status_label')),
        );
        expect(groupStatusLabel.data, contains('Inactive'));

        // Nested activity status should cascade to Inactive
        final actStatusLabel = tester.widget<Text>(
          find.byKey(Key('activity_row_status_$actId')),
        );
        expect(actStatusLabel.data, equals('Inactive'));

        // Reactivate Activity X
        await tester.ensureVisible(find.byKey(Key('activity_row_$actId')));
        await tester.tap(find.byKey(Key('activity_row_$actId')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('activity_detail_overflow_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('activity_detail_toggle_status_item')),
        );
        await tester.pumpAndSettle();

        // Activity should be Active
        final actDetailStatus = tester.widget<Text>(
          find.byKey(const Key('activity_detail_status_label')),
        );
        expect(actDetailStatus.data, contains('Active'));

        // Parent Activity Group should automatically reactivate
        await tester.tap(
          find.byKey(const Key('activity_detail_group_breadcrumb')),
        );
        await tester.pumpAndSettle();

        final groupDetailStatus = tester.widget<Text>(
          find.byKey(const Key('activity_group_detail_status_label')),
        );
        expect(groupDetailStatus.data, contains('Active'));
      },
    );

    testWidgets(
      'T_SET_03: Sharing, Applying, and Ownership Promotion on Deletion',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        // Login as Head A
        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'head.a@vetter.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'Password123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Navigate to Settings
        await tester.tap(find.byKey(const Key('nav_settings')));
        await tester.pumpAndSettle();

        // Create Group A
        await tester.tap(find.byKey(const Key('create_activity_group_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('activity_group_create_name_input')),
          'Group A',
        );
        await tester.tap(find.byKey(const Key('activity_group_create_button')));
        await tester.pumpAndSettle();

        final groupList = harness
            .mockFirestore
            .collections['activityGroups']!
            .values
            .toList();
        final groupId =
            groupList.firstWhere((g) => g['name'] == 'Group A')['id'] as String;

        // Share Group A with ORG_B
        await tester.tap(
          find.byKey(Key('activity_group_row_overflow_button_$groupId')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(Key('activity_group_row_share_item_$groupId')),
        );
        await tester.pumpAndSettle();

        // Step 1: Select items (already has Group A selected) -> Next
        await tester.tap(find.byKey(const Key('share_modal_next_button')));
        await tester.pumpAndSettle();

        // Step 2: Select Organization Units -> ORG_B
        await tester.tap(find.byKey(const Key('share_modal_row_ORG_B')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('share_modal_share_button')));
        await tester.pumpAndSettle();

        // Logout
        await tester.tap(find.byKey(const Key('profile_dropdown_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('profile_menu_item_logout')));
        await tester.pumpAndSettle();

        // Login as Head B
        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'head.b@vetter.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'Password123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Navigate to Settings
        await tester.tap(find.byKey(const Key('nav_settings')));
        await tester.pumpAndSettle();

        // Verify Group A is NOT yet listed for ORG_B
        expect(find.text('Group A'), findsNothing);

        // Apply shared items
        await tester.tap(
          find.byKey(const Key('activity_group_list_actions_dropdown')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('activity_group_list_apply_item')),
        );
        await tester.pumpAndSettle();

        // Select Group A from dialog and apply
        await tester.tap(find.byKey(Key('apply_modal_row_$groupId')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('apply_modal_save_button')));
        await tester.pumpAndSettle();

        // Group A is now listed for ORG_B
        expect(find.text('Group A'), findsOneWidget);

        // Logout
        await tester.tap(find.byKey(const Key('profile_dropdown_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('profile_menu_item_logout')));
        await tester.pumpAndSettle();

        // Login as Head A (owner) to delete Group A
        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'head.a@vetter.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'Password123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Navigate to Settings
        await tester.tap(find.byKey(const Key('nav_settings')));
        await tester.pumpAndSettle();

        // Delete Group A (since it is applied by ORG_B, ownership should promote to ORG_B)
        await tester.tap(
          find.byKey(Key('activity_group_row_overflow_button_$groupId')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(Key('activity_group_row_delete_item_$groupId')),
        );
        await tester.pumpAndSettle();

        // Group A is removed from Head A's list
        expect(find.text('Group A'), findsNothing);

        // Verify ownership was promoted in DB
        final dbGroup = ActivityGroupModel.fromMap(
          harness.mockFirestore.getData('activityGroups', groupId)!,
        );
        expect(dbGroup.ownerOrgUnitId, equals('ORG_B'));
      },
    );

    testWidgets('T_SET_04: Limited Activity validity range and automatic deactivation', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const CapplaApp(),
        ),
      );

      // Login as Head A
      await tester.enterText(
        find.byKey(const Key('login_email_input')),
        'head.a@vetter.com',
      );
      await tester.tap(find.byKey(const Key('login_next_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login_password_input')),
        'Password123!',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      // Navigate to Settings
      await tester.tap(find.byKey(const Key('nav_settings')));
      await tester.pumpAndSettle();

      // Create Category
      await tester.tap(find.byKey(const Key('nav_rail_categories')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create_category_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('category_create_name_input')),
        'Category Y',
      );
      await tester.tap(find.byKey(const Key('category_create_button')));
      await tester.pumpAndSettle();

      final catList = harness.mockFirestore.collections['categories']!.values
          .toList();
      final catId =
          catList.firstWhere((c) => c['name'] == 'Category Y')['id'] as String;

      // Go to Activities tab
      await tester.tap(find.byKey(const Key('nav_rail_activities')));
      await tester.pumpAndSettle();

      // Create Activity Group
      await tester.tap(find.byKey(const Key('create_activity_group_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('activity_group_create_name_input')),
        'Group B',
      );
      await tester.tap(find.byKey(const Key('activity_group_create_button')));
      await tester.pumpAndSettle();

      final groupList = harness
          .mockFirestore
          .collections['activityGroups']!
          .values
          .toList();
      final groupId =
          groupList.firstWhere((g) => g['name'] == 'Group B')['id'] as String;

      // Open detail view
      await tester.tap(find.byKey(Key('activity_group_row_$groupId')));
      await tester.pumpAndSettle();

      // Create a Limited Activity that is already expired (ends in the past)
      await tester.tap(find.byKey(const Key('create_activity_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('activity_create_name_input')),
        'Expired Act',
      );
      await tester.tap(find.byKey(const Key('activity_create_category_input')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('category_select_modal_row_$catId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('category_modal_select_button')));
      await tester.pumpAndSettle();

      // Select Limited type
      await tester.tap(find.byKey(const Key('activity_create_type_input')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limited').last);
      await tester.pumpAndSettle();

      // Enter expired dates (yesterday to today - 1 minute)
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final pastEnd = DateTime.now().subtract(const Duration(minutes: 1));

      // Enter start and end dates directly
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final pastEndStr =
          '${pastEnd.year}-${pastEnd.month.toString().padLeft(2, '0')}-${pastEnd.day.toString().padLeft(2, '0')}';

      await tester.enterText(
        find.byKey(const Key('activity_create_validity_start_input')),
        yesterdayStr,
      );
      await tester.enterText(
        find.byKey(const Key('activity_create_validity_end_input')),
        pastEndStr,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('activity_create_button')));
      await tester.pumpAndSettle();

      final actList = harness.mockFirestore.collections['activities']!.values
          .toList();
      final actId =
          actList.firstWhere((a) => a['name'] == 'Expired Act')['id'] as String;

      // Verify the activity is deactivated automatically
      final actStatusLabel = tester.widget<Text>(
        find.byKey(Key('activity_row_status_$actId')),
      );
      expect(actStatusLabel.data, equals('Inactive'));

      // Scroll the row into view first to prevent it being off-screen or obscured
      await tester.ensureVisible(find.byKey(Key('activity_row_$actId')));
      await tester.pumpAndSettle();

      // Tap on row -> try to activate directly (it should alert or block because it is expired)
      await tester.tap(find.byKey(Key('activity_row_$actId')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('activity_detail_overflow_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('activity_detail_toggle_status_item')),
      );
      await tester.pumpAndSettle();

      // Verify reactivation modal is opened because it is expired
      expect(find.byKey(const Key('reactivate_modal_title')), findsOneWidget);

      // Select new validity range in modal
      final newStart = DateTime.now().add(const Duration(days: 1));
      final newEnd = DateTime.now().add(const Duration(days: 10));

      final newStartStr =
          '${newStart.year}-${newStart.month.toString().padLeft(2, '0')}-${newStart.day.toString().padLeft(2, '0')}';
      final newEndStr =
          '${newEnd.year}-${newEnd.month.toString().padLeft(2, '0')}-${newEnd.day.toString().padLeft(2, '0')}';

      await tester.enterText(
        find.byKey(const Key('reactivate_modal_validity_start_input')),
        newStartStr,
      );
      await tester.enterText(
        find.byKey(const Key('reactivate_modal_validity_end_input')),
        newEndStr,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('reactivate_modal_confirm_button')),
      );
      await tester.pumpAndSettle();

      // Verify it is now Active and dates are updated
      final statusLabel = tester.widget<Text>(
        find.byKey(const Key('activity_detail_status_label')),
      );
      expect(statusLabel.data, contains('Active'));
    });

    testWidgets('T_SET_04: Change Ownership of resources', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const CapplaApp(),
        ),
      );

      // Login as Head A (head.a@vetter.com)
      await tester.enterText(
        find.byKey(const Key('login_email_input')),
        'head.a@vetter.com',
      );
      await tester.tap(find.byKey(const Key('login_next_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login_password_input')),
        'Password123!',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      // Navigate to Settings
      await tester.tap(find.byKey(const Key('nav_settings')));
      await tester.pumpAndSettle();

      // Go to Categories tab
      await tester.tap(find.byKey(const Key('nav_rail_categories')));
      await tester.pumpAndSettle();

      // Create Category
      await tester.tap(find.byKey(const Key('create_category_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('category_create_name_input')),
        'Cat A',
      );
      await tester.tap(find.byKey(const Key('category_create_button')));
      await tester.pumpAndSettle();

      final catList = harness.mockFirestore.collections['categories']!.values
          .toList();
      final catId =
          catList.firstWhere((c) => c['name'] == 'Cat A')['id'] as String;

      // Verify Category is owned by ORG_A
      var cat = CategoryModel.fromMap(
        harness.mockFirestore.collections['categories']![catId]!,
      );
      expect(cat.ownerOrgUnitId, equals('ORG_A'));

      // Tap overflow button
      await tester.tap(find.byKey(Key('category_row_overflow_button_$catId')));
      await tester.pumpAndSettle();

      // Tap change ownership menu item
      await tester.tap(
        find.byKey(Key('category_row_change_ownership_item_$catId')),
      );
      await tester.pumpAndSettle();

      // Select ORG_B
      await tester.tap(
        find.byKey(const Key('ownership_modal_org_radio_ORG_B')),
      );
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(find.byKey(const Key('ownership_modal_confirm_button')));
      await tester.pumpAndSettle();

      // Verify new owner is ORG_B and shared/applied with ORG_A is preserved
      cat = CategoryModel.fromMap(
        harness.mockFirestore.collections['categories']![catId]!,
      );
      expect(cat.ownerOrgUnitId, equals('ORG_B'));
      expect(cat.sharedOrgUnitIds, contains('ORG_A'));
      expect(cat.appliedOrgUnitIds, contains('ORG_A'));
      expect(cat.appliedOrgUnitIds, contains('ORG_B'));
      expect(cat.statusMap['ORG_B'], equals('Active'));

      // Go to Activities tab
      await tester.tap(find.byKey(const Key('nav_rail_activities')));
      await tester.pumpAndSettle();

      // Create Activity Group
      await tester.tap(find.byKey(const Key('create_activity_group_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('activity_group_create_name_input')),
        'Group A',
      );
      await tester.tap(find.byKey(const Key('activity_group_create_button')));
      await tester.pumpAndSettle();

      final groupList = harness
          .mockFirestore
          .collections['activityGroups']!
          .values
          .toList();
      final groupId =
          groupList.firstWhere((g) => g['name'] == 'Group A')['id'] as String;

      // Tap on Group A row to open detail view
      await tester.tap(find.byKey(Key('activity_group_row_$groupId')));
      await tester.pumpAndSettle();

      // Create Activity
      await tester.tap(find.byKey(const Key('create_activity_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('activity_create_name_input')),
        'Act A',
      );
      await tester.tap(find.byKey(const Key('activity_create_category_input')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('category_select_modal_row_$catId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('category_modal_select_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('activity_create_button')));
      await tester.pumpAndSettle();

      final actList = harness.mockFirestore.collections['activities']!.values
          .toList();
      final actId =
          actList.firstWhere((a) => a['name'] == 'Act A')['id'] as String;

      // Change ownership of child Activity "Act A" to ORG_B
      final overflowFinder = find.byKey(
        Key('activity_row_overflow_button_$actId'),
      );
      await tester.ensureVisible(overflowFinder);
      await tester.pumpAndSettle();
      await tester.tap(overflowFinder);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(Key('activity_row_change_ownership_item_$actId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('ownership_modal_org_radio_ORG_B')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ownership_modal_confirm_button')));
      await tester.pumpAndSettle();

      // Verify Activity ownership update
      var act = ActivityModel.fromMap(
        harness.mockFirestore.collections['activities']![actId]!,
      );
      expect(act.ownerOrgUnitId, equals('ORG_B'));
      expect(act.sharedOrgUnitIds, contains('ORG_A'));
      expect(act.appliedOrgUnitIds, contains('ORG_A'));
      expect(act.appliedOrgUnitIds, contains('ORG_B'));
      expect(act.statusMap['ORG_B'], equals('Active'));

      // Change ownership of Activity Group "Group A" to ORG_B
      await tester.tap(
        find.byKey(const Key('activity_group_detail_overflow_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('activity_group_detail_change_ownership_item')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('ownership_modal_org_radio_ORG_B')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ownership_modal_confirm_button')));
      await tester.pumpAndSettle();

      // Verify Activity Group ownership update
      var g = ActivityGroupModel.fromMap(
        harness.mockFirestore.collections['activityGroups']![groupId]!,
      );
      expect(g.ownerOrgUnitId, equals('ORG_B'));
      expect(g.sharedOrgUnitIds, contains('ORG_A'));
      expect(g.appliedOrgUnitIds, contains('ORG_A'));
      expect(g.appliedOrgUnitIds, contains('ORG_B'));
      expect(g.statusMap['ORG_B'], equals('Active'));
    });

    testWidgets('T_SET_05: Category Activities section assign and remove', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const CapplaApp(),
        ),
      );

      // Login as Head A
      await tester.enterText(
        find.byKey(const Key('login_email_input')),
        'head.a@vetter.com',
      );
      await tester.tap(find.byKey(const Key('login_next_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login_password_input')),
        'Password123!',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      // Navigate to Settings
      await tester.tap(find.byKey(const Key('nav_settings')));
      await tester.pumpAndSettle();

      // Go to Categories tab and create a Category
      await tester.tap(find.byKey(const Key('nav_rail_categories')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create_category_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('category_create_name_input')),
        'Category Z',
      );
      await tester.tap(find.byKey(const Key('category_create_button')));
      await tester.pumpAndSettle();

      final catList = harness.mockFirestore.collections['categories']!.values
          .toList();
      final catId =
          catList.firstWhere((c) => c['name'] == 'Category Z')['id'] as String;

      // Go to Activities tab and create Group Z
      await tester.tap(find.byKey(const Key('nav_rail_activities')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create_activity_group_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('activity_group_create_name_input')),
        'Group Z',
      );
      await tester.tap(find.byKey(const Key('activity_group_create_button')));
      await tester.pumpAndSettle();

      final groupList = harness
          .mockFirestore
          .collections['activityGroups']!
          .values
          .toList();
      final groupId =
          groupList.firstWhere((g) => g['name'] == 'Group Z')['id'] as String;

      // Open Group Z details page
      await tester.tap(find.byKey(Key('activity_group_row_$groupId')));
      await tester.pumpAndSettle();

      // Create Activity Z (without selecting category)
      await tester.tap(find.byKey(const Key('create_activity_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('activity_create_name_input')),
        'Activity Z',
      );
      await tester.tap(find.byKey(const Key('activity_create_button')));
      await tester.pumpAndSettle();

      final actList = harness.mockFirestore.collections['activities']!.values
          .toList();
      final actId =
          actList.firstWhere((a) => a['name'] == 'Activity Z')['id'] as String;

      // Go back to Categories and open Category Z details page
      await tester.tap(
        find.byKey(const Key('activity_group_detail_back_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav_rail_categories')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('category_row_$catId')));
      await tester.pumpAndSettle();

      // Verify Activities section
      expect(
        find.byKey(const Key('category_activities_title')),
        findsOneWidget,
      );

      // Open Assign Activity dialog
      await tester.tap(find.byKey(const Key('category_add_activity_button')));
      await tester.pumpAndSettle();

      // Check Activity Z row in dialog and Assign
      await tester.tap(find.byKey(Key('activity_assign_modal_row_$actId')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('activity_assign_modal_save_button')),
      );
      await tester.pumpAndSettle();

      // Verify Z is in the category's activities list
      expect(find.byKey(Key('category_activity_row_$actId')), findsOneWidget);

      // Search for Activity Z
      await tester.enterText(
        find.byKey(const Key('category_activity_search_input')),
        'Z',
      );
      await tester.tap(
        find.byKey(const Key('category_activity_search_button')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(Key('category_activity_row_$actId')), findsOneWidget);

      // Search for something else and make sure it finds nothing
      await tester.enterText(
        find.byKey(const Key('category_activity_search_input')),
        'Nonexistent',
      );
      await tester.tap(
        find.byKey(const Key('category_activity_search_button')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(Key('category_activity_row_$actId')), findsNothing);

      // Reset search
      await tester.enterText(
        find.byKey(const Key('category_activity_search_input')),
        '',
      );
      await tester.tap(
        find.byKey(const Key('category_activity_search_button')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(Key('category_activity_row_$actId')), findsOneWidget);

      // Remove Activity Z from Category Z
      await tester.tap(
        find.byKey(Key('category_activity_overflow_button_$actId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('category_activity_remove_item_$actId')));
      await tester.pumpAndSettle();

      // Verify Z is no longer in Category Z's activities list
      expect(find.byKey(Key('category_activity_row_$actId')), findsNothing);
    });

    testWidgets(
      'T_SET_06: Ownership checks and employee assignment constraints',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        // Login as Head A (owns ORG_A)
        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'head.a@vetter.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'Password123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Navigate to Settings
        await tester.tap(find.byKey(const Key('nav_settings')));
        await tester.pumpAndSettle();

        // Create Category A (owned by ORG_A)
        await tester.tap(find.byKey(const Key('nav_rail_categories')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('create_category_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('category_create_name_input')),
          'Category A',
        );
        await tester.tap(find.byKey(const Key('category_create_button')));
        await tester.pumpAndSettle();

        final catList = harness.mockFirestore.collections['categories']!.values.toList();
        final catId = catList.firstWhere((c) => c['name'] == 'Category A')['id'] as String;

        // Create Group A (owned by ORG_A)
        await tester.tap(find.byKey(const Key('nav_rail_activities')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('create_activity_group_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('activity_group_create_name_input')),
          'Group A',
        );
        await tester.tap(find.byKey(const Key('activity_group_create_button')));
        await tester.pumpAndSettle();

        final groupList = harness.mockFirestore.collections['activityGroups']!.values.toList();
        final groupId = groupList.firstWhere((g) => g['name'] == 'Group A')['id'] as String;

        // Open Group A and create Activity A (owned by ORG_A)
        await tester.tap(find.byKey(Key('activity_group_row_$groupId')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('create_activity_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('activity_create_name_input')),
          'Activity A',
        );
        await tester.tap(find.byKey(const Key('activity_create_button')));
        await tester.pumpAndSettle();

        final actList = harness.mockFirestore.collections['activities']!.values.toList();
        final actId = actList.firstWhere((a) => a['name'] == 'Activity A')['id'] as String;

        // Share Category A and Activity Group A with ORG_B so Head B can see them
        final db = harness.container.read(databaseServiceProvider);
        final cat = await db.getCategory(catId);
        await db.saveCategory(cat!.copyWith(
          sharedOrgUnitIds: ['ORG_B'],
          appliedOrgUnitIds: ['ORG_B'],
        ));
        final grp = await db.getActivityGroup(groupId);
        await db.saveActivityGroup(grp!.copyWith(
          sharedOrgUnitIds: ['ORG_B'],
          appliedOrgUnitIds: ['ORG_B'],
        ));
        final act = await db.getActivity(actId);
        await db.saveActivity(act!.copyWith(
          sharedOrgUnitIds: ['ORG_B'],
          appliedOrgUnitIds: ['ORG_B'],
        ));

        // Logout
        await tester.tap(find.byKey(const Key('profile_dropdown_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('profile_menu_item_logout')));
        await tester.pumpAndSettle();

        // Seed some employees for ORG_A and ORG_B
        final empA = UserModel(
          id: 'emp_a_uuid',
          fullName: 'Employee A',
          email: 'emp.a@vetter.com',
          title: 'Specialist',
          status: 'Active',
          role: 'User',
          orgUnitId: 'ORG_A',
        );
        final empB = UserModel(
          id: 'emp_b_uuid',
          fullName: 'Employee B',
          email: 'emp.b@vetter.com',
          title: 'Specialist',
          status: 'Active',
          role: 'User',
          orgUnitId: 'ORG_B',
        );
        harness.seedUser(empA, 'Password123!');
        harness.seedUser(empB, 'Password123!');

        // Also assign both to Activity A initially
        final actUpdated = (await db.getActivity(actId))!.copyWith(
          assignedUserEmails: ['emp.a@vetter.com', 'emp.b@vetter.com'],
        );
        await db.saveActivity(actUpdated);

        // Login as Head B (owns ORG_B)
        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'head.b@vetter.com',
        );
        await tester.tap(find.byKey(const Key('login_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'Password123!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Navigate to Settings -> Categories
        await tester.tap(find.byKey(const Key('nav_settings')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('nav_rail_categories')));
        await tester.pumpAndSettle();

        // 1. Verify row-level edit button and share action are hidden for Category A
        expect(find.byKey(Key('category_row_edit_button_$catId')), findsNothing);
        await tester.tap(find.byKey(Key('category_row_overflow_button_$catId')));
        await tester.pumpAndSettle();
        expect(find.byKey(Key('category_row_share_item_$catId')), findsNothing);

        // Close overflow menu
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // 2. Open Category A Detail, verify page-level edit/share are hidden
        await tester.tap(find.byKey(Key('category_row_$catId')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('category_detail_edit_button')), findsNothing);
        await tester.tap(find.byKey(const Key('category_detail_overflow_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('category_detail_share_item')), findsNothing);

        // Go to Activities Settings
        await tester.tap(find.byKey(const Key('nav_settings')));
        await tester.pumpAndSettle();

        // 3. Verify row-level edit and share action are hidden for Activity Group A
        expect(find.byKey(Key('activity_group_row_edit_button_$groupId')), findsNothing);
        await tester.tap(find.byKey(Key('activity_group_row_overflow_button_$groupId')));
        await tester.pumpAndSettle();
        expect(find.byKey(Key('activity_group_row_share_item_$groupId')), findsNothing);

        // Close overflow menu
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // 4. Open Group A details
        await tester.tap(find.byKey(Key('activity_group_row_$groupId')));
        await tester.pumpAndSettle();

        // Verify page-level edit/share are hidden for group
        expect(find.byKey(const Key('activity_group_detail_edit_button')), findsNothing);
        await tester.tap(find.byKey(const Key('activity_group_detail_overflow_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('activity_group_detail_share_item')), findsNothing);

        // Close overflow menu
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // 5. Verify row-level edit/share are hidden for Activity A inside Group A
        expect(find.byKey(Key('activity_row_edit_button_$actId')), findsNothing);
        await tester.tap(find.byKey(Key('activity_row_overflow_button_$actId')));
        await tester.pumpAndSettle();
        expect(find.byKey(Key('activity_row_share_item_$actId')), findsNothing);

        // Close overflow menu
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // 6. Open Activity A details
        await tester.tap(find.byKey(Key('activity_row_$actId')));
        await tester.pumpAndSettle();

        // Verify page-level edit/share are hidden
        expect(find.byKey(const Key('activity_detail_edit_button')), findsNothing);
        await tester.tap(find.byKey(const Key('activity_detail_overflow_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('activity_detail_share_item')), findsNothing);

        // Close overflow menu
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // 7. Verify assigned employees list only shows employees from ORG_B
        expect(find.text('Employee B'), findsOneWidget);
        expect(find.text('Employee A'), findsNothing); // Filtered out as not from ORG_B

        // 8. Open Assign Employee dialog and verify it only shows assignable employees from ORG_B
        final actUpdated2 = (await db.getActivity(actId))!.copyWith(
          assignedUserEmails: ['emp.a@vetter.com'],
        );
        await db.saveActivity(actUpdated2);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('activity_add_employee_button')));
        await tester.pumpAndSettle();

        expect(find.text('Employee B'), findsOneWidget);
        expect(find.text('Employee A'), findsNothing); // ORG_A employees not assignable by ORG_B head
      },
    );
  });
}
