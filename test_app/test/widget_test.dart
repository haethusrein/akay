// Basic smoke tests for the create account flow (front end only).
// Run them with:  flutter test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/main.dart';

void main() {
  // Use a tall phone-sized screen so every button is visible in the test.
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Welcome screen shows the two account buttons', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(const AkayApp());

    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
    expect(find.text('Call emergency hotline'), findsOneWidget);
  });

  testWidgets('Empty form shows validation errors', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(const AkayApp());

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Enter your password'), findsOneWidget);
    expect(find.textContaining('Enter a valid mobile number'), findsOneWidget);
  });

  testWidgets('Resident goes to the household profile', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(const AkayApp());

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '09123456789');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Create your household profile'), findsOneWidget);
  });

  testWidgets('Respondent skips the household profile', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(const AkayApp());

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Respondent'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(0), '+63 912 345 6789');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    // pump() with a duration instead of pumpAndSettle(), because the code
    // field keeps blinking its cursor and would never "settle".
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Enter the one-time code'), findsOneWidget);
  });
}
