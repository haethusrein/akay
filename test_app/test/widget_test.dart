// Flutter widget tests for the current Firebase-free account setup flow.
// Run from test_app with: flutter test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/create_account_screens.dart';

void main() {
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget home) => MaterialApp(home: home);

  group('Welcome and account creation', () {
    testWidgets('welcome screen presents resident account actions', (
      tester,
    ) async {
      useTallScreen(tester);
      await tester.pumpWidget(app(const WelcomeScreen()));

      expect(find.text('Create an account'), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);
      expect(find.text('Call emergency hotline'), findsOneWidget);
    });

    testWidgets('empty create-account form reports required input errors', (
      tester,
    ) async {
      useTallScreen(tester);
      await tester.pumpWidget(app(const WelcomeScreen()));

      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pump();

      // One occurrence is the field hint and the other is the validation text.
      expect(find.text('Enter your password'), findsNWidgets(2));
      expect(find.textContaining('Enter a valid mobile number'), findsOneWidget);
    });

    testWidgets('short password is rejected before continuing', (tester) async {
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

    testWidgets('resident remains the default selected account role', (
      tester,
    ) async {
      useTallScreen(tester);
      await tester.pumpWidget(app(const CreateAccountScreen()));

      final residentCard = tester.widget<RoleOption>(find.byType(RoleOption).first);
      final respondentCard =
          tester.widget<RoleOption>(find.byType(RoleOption).last);
      expect(residentCard.selected, isTrue);
      expect(respondentCard.selected, isFalse);
    });
  });

  group('Household setup form', () {
    testWidgets('shows the current household fields and save action', (
      tester,
    ) async {
      useTallScreen(tester);
      await tester.pumpWidget(app(const HouseholdSetupScreen()));

      expect(find.text('Create your household profile'), findsOneWidget);
      expect(find.text('Household name'), findsOneWidget);
      expect(find.text('Barangay'), findsOneWidget);
      expect(find.text('Complete address'), findsOneWidget);
      expect(find.text('Household members'), findsOneWidget);
      expect(find.text('Mobility or equipment needs'), findsOneWidget);
      expect(find.text('Save and verify household'), findsOneWidget);
    });

    testWidgets('empty household form reports all required setup steps', (
      tester,
    ) async {
      useTallScreen(tester);
      await tester.pumpWidget(app(const HouseholdSetupScreen()));

      await tester.tap(find.text('Save and verify household'));
      await tester.pump();

      expect(find.text('Enter a household name'), findsOneWidget);
      // The label appears once as the picker placeholder and once as the
      // validation message after submitting the empty form.
      expect(find.text('Select your barangay'), findsNWidgets(2));
      expect(find.text('Enter your address'), findsOneWidget);
      expect(find.text('Pin your exact home location'), findsOneWidget);
      expect(find.byType(VerifyCodeScreen), findsNothing);
    });
  });

  group('One-time code screen', () {
    testWidgets('renders six code boxes and accepts only digit input', (
      tester,
    ) async {
      useTallScreen(tester);
      await tester.pumpWidget(app(const VerifyCodeScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Enter the one-time code'), findsOneWidget);
      expect(find.byType(CodeBox), findsNWidgets(6));

      final input = find.byType(TextField);
      await tester.enterText(input, '12a34');
      await tester.pump();

      final boxes = tester.widgetList<CodeBox>(find.byType(CodeBox)).toList();
      expect(boxes.map((box) => box.digit).join(), '1234');
    });
  });
}
