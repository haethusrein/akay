// Smoke tests for the create account flow (front end only, no Firebase).
// Run them with:  flutter test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/create_account_screens.dart';

void main() {
  // Use a tall phone-sized screen so every button is visible in the test.
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget home) => MaterialApp(home: home);

  testWidgets('Welcome screen shows the two account buttons', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(app(const WelcomeScreen()));

    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
    expect(find.text('Call emergency hotline'), findsOneWidget);
  });

  testWidgets('Empty form shows validation errors', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(app(const WelcomeScreen()));

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pump();

        // One is the field hint, the other is the validation error.
    expect(find.text('Enter your password'), findsNWidgets(2));
    expect(find.textContaining('Enter a valid mobile number'), findsOneWidget);
  });

  testWidgets('Short password is rejected', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(app(const WelcomeScreen()));

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '09123456789');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });

  testWidgets('Household profile screen shows its form', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(app(const HouseholdSetupScreen()));

    expect(find.text('Create your household profile'), findsOneWidget);
    expect(find.text('Save and verify household'), findsOneWidget);
  });

  testWidgets('Verify screen asks for the 16-character code', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(app(const VerifyCodeScreen()));
    // pump() with a duration instead of pumpAndSettle(), because the code
    // field keeps blinking its cursor and would never "settle".
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Enter the one-time code'), findsOneWidget);
    expect(find.text('XXXX-XXXX-XXXX-XXXX'), findsOneWidget);
  });
}