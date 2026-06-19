import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cappla/main.dart';
import 'e2e_test_harness.dart';

void main() {
  testWidgets('E2E Smoke Test - Login Flow', (WidgetTester tester) async {
    // 1. Initialize harness
    final harness = E2ETestHarness();

    // Seed default admin user
    harness.seedAdminUser();

    // 2. Pump CapplaApp wrapped in a ProviderScope with our harness container overrides
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const CapplaApp(),
      ),
    );

    // Verify login page is shown
    expect(find.text('Log in to Cappla'), findsOneWidget);
    expect(find.byKey(const Key('login_email_input')), findsOneWidget);
    expect(find.byKey(const Key('login_password_input')), findsNothing);

    // 3. Enter email
    await tester.enterText(
      find.byKey(const Key('login_email_input')),
      'MalikJannico.Press@vetter-pharma.com',
    );

    // Tap Next button
    await tester.tap(find.byKey(const Key('login_next_button')));
    await tester.pumpAndSettle();

    // Now password field should be visible
    expect(find.byKey(const Key('login_password_input')), findsOneWidget);

    // Enter password
    await tester.enterText(
      find.byKey(const Key('login_password_input')),
      'AdminPassword123!',
    );

    // 4. Tap the login button
    await tester.tap(find.byKey(const Key('login_submit_button')));

    // Wait for any async actions (signInWithEmailAndPassword / setState)
    await tester.pumpAndSettle();

    // 5. Verify MockShellLayout is rendered
    expect(find.byKey(const Key('app_title')), findsOneWidget);
    final textWidget = tester.widget<Text>(find.byKey(const Key('app_title')));
    expect(textWidget.textSpan?.toPlainText(), contains('Cappla'));
  });
}
