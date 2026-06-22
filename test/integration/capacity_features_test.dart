import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cappla/main.dart';
import 'e2e_test_harness.dart';

void main() {
  group('Capacity Features Integration Tests', () {
    late E2ETestHarness harness;
    String clipboardText = '';

    setUp(() {
      harness = E2ETestHarness();
      harness.seedAdminUser();
      clipboardText = '';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': clipboardText};
            }
            if (methodCall.method == 'Clipboard.setData') {
              clipboardText = methodCall.arguments['text'] as String;
              return null;
            }
            return null;
          });
    });

    tearDown(() {
      harness.clearAll();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets(
      'My Capacity - Standard Capacity lifecycle, Adding Specific Capacities, and Overlap Validation',
      (WidgetTester tester) async {
        // 1. Pump CapplaApp wrapped in ProviderScope with our harness container overrides
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        // Log in as the admin user
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

        // Navigate to profile view
        await tester.tap(find.byKey(const Key('profile_dropdown_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('profile_menu_item_profile')));
        await tester.pumpAndSettle();

        // Verify "My Capacity" title is displayed
        expect(find.text('My Capacity'), findsOneWidget);

        // Verify the default "Standard" capacity row is created and displayed
        // monday-friday should be 8, saturday-sunday 0, sum 40
        expect(find.text('Standard'), findsOneWidget);
        expect(find.text('8'), findsAtLeast(5)); // Mon-Fri
        expect(find.text('0'), findsAtLeast(2)); // Sat-Sun
        expect(find.text('40'), findsOneWidget); // Sum

        // Verify Copy on Tap behavior in non-edit mode is REMOVED
        // Tap the Monday capacity text cell
        final monTextKey = const Key(
          'capacity_monday_text_standard_malikjannico.press@vetter-pharma.com',
        );
        expect(find.byKey(monTextKey), findsOneWidget);
        await tester.ensureVisible(find.byKey(monTextKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(monTextKey));
        await tester.pumpAndSettle();

        // Verify SnackBar is NOT shown
        expect(find.text("Copied '8' to clipboard"), findsNothing);

        // Verify clicking outside the table deselects selection range
        final monCellKey = const Key(
          'capacity_monday_cell_standard_malikjannico.press@vetter-pharma.com',
        );
        await tester.tap(find.byKey(monCellKey));
        await tester.pumpAndSettle();

        // Tap outside the table (top-left of viewport, below AppBar but outside table)
        await tester.tapAt(const Offset(10, 100));
        await tester.pumpAndSettle();

        // Verify selection is cleared by trying to copy (which should copy nothing/not change clipboard)
        clipboardText = 'unchanged';
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(clipboardText, 'unchanged');

        // 2. Click capacity edit button
        await tester.ensureVisible(
          find.byKey(const Key('capacity_edit_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('capacity_edit_button')));
        await tester.pumpAndSettle();

        // Verify Edit mode buttons: Cancel and Save are visible
        expect(find.byKey(const Key('capacity_cancel_button')), findsOneWidget);
        expect(find.byKey(const Key('capacity_save_button')), findsOneWidget);

        // Double tap standard Monday cell to enter typing mode
        await tester.tap(find.byKey(monCellKey));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.byKey(monCellKey));
        await tester.pumpAndSettle();

        // Verify weekday inputs are shown (standard row id starts with standard_)
        final standardMonInput = find.byKey(
          const Key(
            'capacity_input_standard_malikjannico.press@vetter-pharma.com_monday',
          ),
        );
        expect(standardMonInput, findsOneWidget);

        // Edit Monday hours to 4.0
        await tester.enterText(standardMonInput, '4.0');
        await tester.pumpAndSettle();

        // Verify real-time sum updates to 36 (Monday was 8, now 4)
        expect(find.text('36'), findsOneWidget);

        // Tap Cancel to discard changes
        await tester.ensureVisible(
          find.byKey(const Key('capacity_cancel_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('capacity_cancel_button')));
        await tester.pumpAndSettle();

        // Verify sum went back to 40 and text fields are gone
        expect(find.text('40'), findsOneWidget);
        expect(standardMonInput, findsNothing);

        // Tap Edit again, modify Monday to 6.0, and Save
        await tester.ensureVisible(
          find.byKey(const Key('capacity_edit_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('capacity_edit_button')));
        await tester.pumpAndSettle();

        // Double tap standard Monday cell to enter typing mode
        await tester.tap(find.byKey(monCellKey));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.byKey(monCellKey));
        await tester.pumpAndSettle();

        await tester.enterText(standardMonInput, '6.0');
        await tester.pumpAndSettle();
        expect(find.text('38'), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const Key('capacity_save_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('capacity_save_button')));
        await tester.pumpAndSettle();

        // Verify saved state in View mode
        expect(find.text('38'), findsOneWidget);
        expect(find.text('6'), findsOneWidget); // monday is 6 now

        // 3. Add Specific Capacity Period (July 2026 - September 2026)
        await tester.ensureVisible(
          find.byKey(const Key('capacity_add_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('capacity_add_button')));
        await tester.pumpAndSettle();

        // Verify modal is open
        expect(find.text('Select a Time Period'), findsOneWidget);
        expect(
          find.byKey(const Key('capacity_modal_start_date_input')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('capacity_modal_end_date_input')),
          findsOneWidget,
        );

        // Select Start Date: 2026-07-01 and End Date: 2026-09-30
        // In the mock modal, we can directly update controllers or date pickers.
        // Let's tap start date calendar button and pick July 2026, or simulate it.
        // Wait, since we are in mock views and tests, let's see: the text fields are readOnly, but they have suffixIcon IconButton to trigger showDatePicker.
        // To bypass date picker interactions in widget tests (which can be flaky), we can just enter text or trigger the datepicker, or since it uses showDatePicker we can verify showDatePicker opens.
        // Actually, since start/end date text fields are readOnly: true in the UI, we can simulate picking dates by tapping on the calendar suffix icon button.
        // Let's write the test helper to tap on start date suffix icon, select a date, and tap end date suffix icon, select a date.
        // Wait, in widget tests, when showDatePicker is called, it pumps the Material DatePicker dialog. We can find the year/month/day selectors or we can enter the date directly if we mock showDatePicker or tap the date picker buttons.
        // Alternatively, can we just input the text directly? Since the text field is readOnly: true, tester.enterText might not work unless we set readOnly: false or bypass it.
        // Wait! In `MockProfilePage`, the text field is `readOnly: true`. But wait, in the test harness, can we just set the dates or does the test tap the suffix icon?
        // Let's check how `activity_edit_view` date picker was tested in `settings_features_test.dart`!
        // In `settings_features_test.dart`:
        // `await tester.enterText(find.byKey(const Key('activity_create_validity_start_input')), yesterdayStr);`
        // Wait! In `mock_views.dart`, was `activity_create_validity_start_input` readOnly?
        // Let's check `test/integration/mock_views.dart` line 8982:
        // It is a TextField, and it is NOT readOnly in `mock_views.dart`!
        // So `tester.enterText` works perfectly because in `mock_views.dart` they didn't make them readOnly, or even if they did, `tester.enterText` overrides it in Flutter tests!
        // So yes! We can just call `tester.enterText` on `capacity_modal_start_date_input` and `capacity_modal_end_date_input`! This is incredibly simple and reliable.
        await tester.enterText(
          find.byKey(const Key('capacity_modal_start_date_input')),
          '2026-07-01',
        );
        await tester.enterText(
          find.byKey(const Key('capacity_modal_end_date_input')),
          '2026-09-30',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('capacity_modal_save_button')));
        await tester.pumpAndSettle();

        // Verify the new row is added
        expect(find.text('July 1 2026 to September 30 2026'), findsOneWidget);
        // It should have 40 hours as default sum
        expect(find.text('40'), findsOneWidget);

        // Verify double click on user added period cell in edit mode opens modal
        await tester.tap(find.byKey(const Key('capacity_edit_button')));
        await tester.pumpAndSettle();

        final specificPeriodTextFinder = find.text(
          'July 1 2026 to September 30 2026',
        );
        await tester.ensureVisible(specificPeriodTextFinder);
        await tester.pumpAndSettle();
        await tester.tap(specificPeriodTextFinder);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(specificPeriodTextFinder);
        await tester.pumpAndSettle();

        // Verify the edit modal is open
        expect(find.text('Select a Time Period'), findsOneWidget);

        // Close the modal
        await tester.tap(find.byKey(const Key('capacity_modal_cancel_button')));
        await tester.pumpAndSettle();

        // Cancel edit mode
        await tester.tap(find.byKey(const Key('capacity_cancel_button')));
        await tester.pumpAndSettle();

        // 4. Try to add an overlapping specific period (August 2026 - September 2026)
        await tester.ensureVisible(
          find.byKey(const Key('capacity_add_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('capacity_add_button')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('capacity_modal_start_date_input')),
          '2026-08-01',
        );
        await tester.enterText(
          find.byKey(const Key('capacity_modal_end_date_input')),
          '2026-09-30',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('capacity_modal_save_button')));
        await tester.pumpAndSettle();

        // Verify overlap error message is shown in modal and modal remains open
        expect(
          find.text('Overlap detected with an existing capacity period.'),
          findsOneWidget,
        );

        // Click Cancel on modal to close it
        await tester.tap(find.byKey(const Key('capacity_modal_cancel_button')));
        await tester.pumpAndSettle();

        // Verify modal is closed
        expect(find.text('Select a Time Period'), findsNothing);
      },
    );

    testWidgets('Excel Grid Capabilities - Selection, Copy/Paste, and Drag-to-Fill', (
      WidgetTester tester,
    ) async {
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

      // Navigate to profile
      await tester.tap(find.byKey(const Key('profile_dropdown_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile_menu_item_profile')));
      await tester.pumpAndSettle();

      final monCellKey = const Key(
        'capacity_monday_cell_standard_malikjannico.press@vetter-pharma.com',
      );
      final wedCellKey = const Key(
        'capacity_wednesday_cell_standard_malikjannico.press@vetter-pharma.com',
      );

      // Ensure the cell is visible on the screen
      await tester.ensureVisible(find.byKey(monCellKey));
      await tester.pumpAndSettle();

      // 1. Drag selection range (Mon to Wed)
      final monCenter = tester.getCenter(find.byKey(monCellKey));
      final wedCenter = tester.getCenter(find.byKey(wedCellKey));
      final gesture = await tester.startGesture(monCenter);
      await tester.pump();
      for (int i = 1; i <= 5; i++) {
        final point = Offset.lerp(monCenter, wedCenter, i / 5.0)!;
        await gesture.moveTo(point);
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // 2. Verify copying works via keyboard shortcut Ctrl+C / Cmd+C
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipData?.text, '8\t8\t8');

      // 3. Edit mode paste
      await tester.tap(find.byKey(const Key('capacity_edit_button')));
      await tester.pumpAndSettle();

      // Set clipboard to new values
      await Clipboard.setData(const ClipboardData(text: '10\t12\t14'));

      // Select Monday cell to focus and set starting point
      await tester.tap(find.byKey(monCellKey));
      await tester.pumpAndSettle();

      // Paste using Ctrl+V
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      // Verify cell values updated (rendered as Text widgets when not actively typing)
      final monText = find.byKey(
        const Key(
          'capacity_monday_text_standard_malikjannico.press@vetter-pharma.com',
        ),
      );
      final tueText = find.byKey(
        const Key(
          'capacity_tuesday_text_standard_malikjannico.press@vetter-pharma.com',
        ),
      );
      final wedText = find.byKey(
        const Key(
          'capacity_wednesday_text_standard_malikjannico.press@vetter-pharma.com',
        ),
      );

      expect(tester.widget<Text>(monText).data, '10');
      expect(tester.widget<Text>(tueText).data, '12');
      expect(tester.widget<Text>(wedText).data, '14');

      // Test pasting a single cell value to multiple selected cells
      await Clipboard.setData(const ClipboardData(text: '7'));
      final pasteMonCellCenter = tester.getCenter(find.byKey(monCellKey));
      final pasteTueCellCenter = tester.getCenter(
        find.byKey(
          const Key(
            'capacity_tuesday_cell_standard_malikjannico.press@vetter-pharma.com',
          ),
        ),
      );
      final editDrag = await tester.startGesture(pasteMonCellCenter);
      await tester.pump();
      await editDrag.moveTo(pasteTueCellCenter);
      await editDrag.up();
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(monText).data, '7');
      expect(tester.widget<Text>(tueText).data, '7');

      // Restore values to 10 and 12
      await Clipboard.setData(const ClipboardData(text: '10\t12'));
      await tester.tap(find.byKey(monCellKey));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      // Save pasted edits and exit edit mode
      await tester.tap(find.byKey(const Key('capacity_save_button')));
      await tester.pumpAndSettle();

      // Enter edit mode again
      await tester.tap(find.byKey(const Key('capacity_edit_button')));
      await tester.pumpAndSettle();

      // We drag-select Monday and Tuesday cells in edit mode so they are the active selection range.
      final monCenter2 = tester.getCenter(find.byKey(monCellKey));
      final tueCenter = tester.getCenter(
        find.byKey(
          const Key(
            'capacity_tuesday_cell_standard_malikjannico.press@vetter-pharma.com',
          ),
        ),
      );
      final dragSelect = await tester.startGesture(monCenter2);
      await tester.pump();
      for (int i = 1; i <= 5; i++) {
        final point = Offset.lerp(monCenter2, tueCenter, i / 5.0)!;
        await dragSelect.moveTo(point);
        await tester.pump();
      }
      await dragSelect.up();
      await tester.pumpAndSettle();

      // Find the drag handle (located in the bottom right of active selection, which is Tuesday cell)
      final handle = find.byKey(const Key('drag_fill_handle'));
      expect(handle, findsOneWidget);

      // Drag the fill handle horizontally to Wednesday and Thursday cells
      final thuCellKey = const Key(
        'capacity_thursday_cell_standard_malikjannico.press@vetter-pharma.com',
      );
      final handleCenter = tester.getCenter(handle);
      final thuCenter = tester.getCenter(find.byKey(thuCellKey));
      final fillGesture = await tester.startGesture(handleCenter);
      await tester.pump();
      for (int i = 1; i <= 5; i++) {
        final point = Offset.lerp(handleCenter, thuCenter, i / 5.0)!;
        await fillGesture.moveTo(point);
        await tester.pump();
      }
      await fillGesture.up();
      await tester.pumpAndSettle();

      // Verify drag fill logic filled Wednesday and Thursday with Tuesday's value (12.0)
      final monText2 = find.byKey(
        const Key(
          'capacity_monday_text_standard_malikjannico.press@vetter-pharma.com',
        ),
      );
      final tueText2 = find.byKey(
        const Key(
          'capacity_tuesday_text_standard_malikjannico.press@vetter-pharma.com',
        ),
      );
      final wedText2 = find.byKey(
        const Key(
          'capacity_wednesday_text_standard_malikjannico.press@vetter-pharma.com',
        ),
      );
      final thuText2 = find.byKey(
        const Key(
          'capacity_thursday_text_standard_malikjannico.press@vetter-pharma.com',
        ),
      );

      expect(tester.widget<Text>(monText2).data, '10');
      expect(tester.widget<Text>(tueText2).data, '12');
      expect(tester.widget<Text>(wedText2).data, '12');
      expect(tester.widget<Text>(thuText2).data, '12');

      // Save the changes and verify the new sums
      await tester.tap(find.byKey(const Key('capacity_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('54'), findsOneWidget); // 10 + 12 + 12 + 12 + 8 = 54

      // 4. Verify Right-Click Context Menu copy/paste
      // Select Monday and Tuesday cells in view mode so they are the active selection range
      final monCenter3 = tester.getCenter(find.byKey(monCellKey));
      final tueCenter3 = tester.getCenter(
        find.byKey(
          const Key(
            'capacity_tuesday_cell_standard_malikjannico.press@vetter-pharma.com',
          ),
        ),
      );
      final dragSelect2 = await tester.startGesture(monCenter3);
      await tester.pump();
      for (int i = 1; i <= 5; i++) {
        final point = Offset.lerp(monCenter3, tueCenter3, i / 5.0)!;
        await dragSelect2.moveTo(point);
        await tester.pump();
      }
      await dragSelect2.up();
      await tester.pumpAndSettle();

      // Select Monday cell by right-clicking it (secondary click)
      await tester.tap(find.byKey(monCellKey), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      // Verify context menu is open
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);

      // Tap Copy menu item
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      // Verify clipboard has Monday and Tuesday values (10\t12)
      final rightClickClipData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(rightClickClipData?.text, '10\t12');

      // 5. Verify Period Column range selection and copying
      final periodCellKey = const Key(
        'capacity_period_cell_standard_malikjannico.press@vetter-pharma.com',
      );
      final periodCenter = tester.getCenter(find.byKey(periodCellKey));
      final monCellCenter = tester.getCenter(find.byKey(monCellKey));

      final periodDrag = await tester.startGesture(periodCenter);
      await tester.pump();
      await periodDrag.moveTo(monCellCenter);
      await periodDrag.up();
      await tester.pumpAndSettle();

      // Copy selection via Ctrl+C shortcut
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final periodClipData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(periodClipData?.text, 'Standard\t10');

      // 6. Enter edit mode to verify double-click focus and drag-select from focused input
      await tester.tap(find.byKey(const Key('capacity_edit_button')));
      await tester.pumpAndSettle();

      // Verify that double-clicking a cell instantly focuses the TextField
      final monInputKey = const Key(
        'capacity_input_standard_malikjannico.press@vetter-pharma.com_monday',
      );
      await tester.tap(find.byKey(monCellKey));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(monCellKey));
      await tester.pumpAndSettle();

      final monFocus = Focus.of(tester.element(find.byKey(monInputKey)));
      expect(monFocus.hasFocus, isTrue);

      // Verify that dragging starting from a focused TextField updates range selection
      final monInputCenter = tester.getCenter(find.byKey(monInputKey));
      final tueCellCenter = tester.getCenter(
        find.byKey(
          const Key(
            'capacity_tuesday_cell_standard_malikjannico.press@vetter-pharma.com',
          ),
        ),
      );

      final textfieldDrag = await tester.startGesture(monInputCenter);
      await tester.pump();
      await textfieldDrag.moveTo(tueCellCenter);
      await textfieldDrag.up();
      await tester.pumpAndSettle();

      // Copy range selection and verify it contains Monday and Tuesday values (10 and 12)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final textfieldDragClipData = await Clipboard.getData(
        Clipboard.kTextPlain,
      );
      expect(textfieldDragClipData?.text, '10\t12');
    });

    testWidgets(
      'Cell Typing Mode Arrow Keys and Enter Key Navigation',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        // Log in as the admin user
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

        // Navigate to profile view
        await tester.tap(find.byKey(const Key('profile_dropdown_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('profile_menu_item_profile')));
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.ensureVisible(find.byKey(const Key('capacity_edit_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('capacity_edit_button')));
        await tester.pumpAndSettle();

        final monCellKey = const Key(
          'capacity_monday_cell_standard_malikjannico.press@vetter-pharma.com',
        );
        final monInputKey = const Key(
          'capacity_input_standard_malikjannico.press@vetter-pharma.com_monday',
        );

        // Scroll the Monday cell into view
        await tester.ensureVisible(find.byKey(monCellKey));
        await tester.pumpAndSettle();

        // Double tap standard Monday cell to enter typing mode
        await tester.tap(find.byKey(monCellKey));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.byKey(monCellKey));
        await tester.pumpAndSettle();

        // Verify input is focused
        final textFieldFinder = find.byKey(monInputKey);
        expect(textFieldFinder, findsOneWidget);
        final monFocus = Focus.of(tester.element(textFieldFinder));
        expect(monFocus.hasFocus, isTrue);

        // Verify we can type in it
        await tester.enterText(textFieldFinder, '12.5');
        await tester.pumpAndSettle();

        // Press left arrow
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();

        // Press right arrow
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();

        // Press Enter key to commit
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // Verify that TextField is closed
        expect(find.byKey(monInputKey), findsNothing);

        // Verify that the value is committed (sum is now 44.5)
        expect(find.text('44.5'), findsOneWidget);

        // Verify arrow key navigation works immediately after Enter key
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();

        // Verify that the Tuesday cell is selected
        // We can do this by checking if the Tuesday cell highlight is selected.
        // Copy selection via Ctrl+C shortcut and check it's Tuesday's value (8)
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        final afterEnterClipData = await Clipboard.getData(Clipboard.kTextPlain);
        expect(afterEnterClipData?.text, '8');
      },
    );

    testWidgets(
      'My Capacity - Year Filtering and Pagination logic',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: const CapplaApp(),
          ),
        );

        // Log in as the admin user
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

        // Navigate to profile view
        await tester.tap(find.byKey(const Key('profile_dropdown_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('profile_menu_item_profile')));
        await tester.pumpAndSettle();

        // Initially no specific capacities, so filter chip should be hidden
        expect(find.byKey(const Key('profile_capacity_year_filter_dropdown')), findsNothing);

        // Add 6 custom capacities with different years:
        // 1. 2026-01-01 to 2026-01-31
        // 2. 2027-01-01 to 2027-01-31
        // 3. 2028-01-01 to 2028-01-31
        // 4. 2029-01-01 to 2029-01-31
        // 5. 2030-01-01 to 2030-01-31
        // 6. 2031-01-01 to 2031-01-31
        final years = [2026, 2027, 2028, 2029, 2030, 2031];
        for (final year in years) {
          await tester.ensureVisible(find.byKey(const Key('capacity_add_button')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('capacity_add_button')));
          await tester.pumpAndSettle();

          await tester.enterText(
            find.byKey(const Key('capacity_modal_start_date_input')),
            '$year-01-01',
          );
          await tester.enterText(
            find.byKey(const Key('capacity_modal_end_date_input')),
            '$year-01-31',
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('capacity_modal_save_button')));
          await tester.pumpAndSettle();
        }

        // Verify the year filter chip is now visible
        expect(find.byKey(const Key('profile_capacity_year_filter_dropdown')), findsOneWidget);

        // Verify standard row is visible
        expect(find.text('Standard'), findsOneWidget);

        // Verify result indicator shows "1-5 of 6" specific capacities
        expect(find.byKey(const Key('profile_capacity_pagination_displayed_count')), findsOneWidget);
        expect(find.text('1-5 of 6'), findsOneWidget);

        // Go to next page
        await tester.tap(find.byKey(const Key('profile_capacity_page_forward')));
        await tester.pumpAndSettle();

        // Verify result indicator shows "6-6 of 6"
        expect(find.text('6-6 of 6'), findsOneWidget);

        // Go back to first page
        await tester.tap(find.byKey(const Key('profile_capacity_page_back')));
        await tester.pumpAndSettle();
        expect(find.text('1-5 of 6'), findsOneWidget);

        // Select Year filter chip -> 2027
        await tester.tap(find.byKey(const Key('profile_capacity_year_filter_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('profile_capacity_year_filter_item_2027')));
        await tester.pumpAndSettle();

        // Only capacities overlapping 2027 should be shown.
        // The result indicator should show "1-1 of 1"
        expect(find.text('1-1 of 1'), findsOneWidget);
        expect(find.text('January 1 2027 to January 31 2027'), findsOneWidget);
        expect(find.text('January 1 2026 to January 31 2026'), findsNothing);

        // Clear filter
        await tester.tap(find.byKey(const Key('profile_capacity_year_filter_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('profile_capacity_year_filter_all_item')));
        await tester.pumpAndSettle();
        expect(find.text('1-5 of 6'), findsOneWidget);

        // Clean up: delete custom capacities
        await tester.tap(find.byKey(const Key('capacity_edit_button')));
        await tester.pumpAndSettle();

        // Delete page 1 capacities
        for (int i = 0; i < 5; i++) {
          final deleteButtonFinder = find.byIcon(Icons.delete).first;
          await tester.ensureVisible(deleteButtonFinder);
          await tester.tap(deleteButtonFinder);
          await tester.pumpAndSettle();
        }

        // Save deletes to update database state
        await tester.tap(find.byKey(const Key('capacity_save_button')));
        await tester.pumpAndSettle();

        // Now page 2 is automatically loaded (1 capacity remains)
        expect(find.text('1-1 of 1'), findsOneWidget);

        // Delete the last one
        await tester.tap(find.byKey(const Key('capacity_edit_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.delete).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('capacity_save_button')));
        await tester.pumpAndSettle();

        // All custom capacities deleted. Verify filter chip is hidden again
        expect(find.byKey(const Key('profile_capacity_year_filter_dropdown')), findsNothing);
      },
    );
  });
}
