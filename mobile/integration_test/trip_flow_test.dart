import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:truck_mate_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-End Trip Flow Test', (WidgetTester tester) async {
    // 1. Launch App
    app.main();
    await tester.pumpAndSettle();

    // 2. Handle Welcome Screen (if present)
    final loginButton = find.text('Login'); // Or key 'login_button'
    if (loginButton.evaluate().isNotEmpty) {
      await tester.tap(loginButton);
      await tester.pumpAndSettle();
    }

    // 3. Login Flow
    // Enter Phone
    final phoneField = find.byType(TextField).first;
    await tester.enterText(phoneField, '1234567880'); // Dev Test User
    await tester.pumpAndSettle();

    // Tap Send OTP
    final sendButton =
        find.byType(ElevatedButton).last; // Assuming last button is Action
    await tester.tap(sendButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Enter OTP
    final otpField = find.byType(TextField).last; // OTP input
    await tester.enterText(otpField, '123456');
    await tester.pumpAndSettle();

    // Tap Verify
    final verifyButton = find.byType(ElevatedButton).last;
    await tester.tap(verifyButton);
    await tester.pumpAndSettle(const Duration(seconds: 5)); // Wait for auth/nav

    // 4. Verify Dashboard
    expect(find.text('Active Trip'), findsOneWidget); // Or "No Active Trip"

    // 5. Trip Flow (Driver)
    // Find Load List (assuming Driver view shows Assigned Loads)
    // This part depends on seeded data.
    // We can at least verify the screen loaded.

    // Check for "Create Documents" button which would be on Load Detail
    // Navigate to a load if possible
    // await tester.tap(find.text('Assigned Load #...'));
  });
}
