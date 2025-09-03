import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:delivery_dapp/main.dart' as app;
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Staking Flow Test', () {
    testWidgets('Complete staking flow', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to staking screen
      await tester.tap(find.text('Staking'));
      await tester.pumpAndSettle();

      // Verify staking dashboard is shown
      expect(find.text('Staking Dashboard'), findsOneWidget);

      // Enter staking amount and period
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount to Stake'),
        '100',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Lock Period (in seconds)'),
        '2592000', // 30 days
      );
      await tester.pumpAndSettle();

      // Submit stake
      await tester.tap(find.text('Stake'));
      await tester.pumpAndSettle();

      // Verify success message
      expect(find.text('Stake submitted successfully'), findsOneWidget);

      // Verify stake info is displayed
      expect(find.text('Current Stake: 100 tokens'), findsOneWidget);
      expect(find.text('Lock Period: 2592000 seconds'), findsOneWidget);

      // Wait for rewards to accumulate
      await Future.delayed(const Duration(seconds: 1));
      await tester.pump();

      // Verify rewards are showing
      expect(find.textContaining('Pending Rewards:'), findsOneWidget);

      // Try to unstake
      await tester.tap(find.text('Unstake'));
      await tester.pumpAndSettle();

      // Verify unstake success
      expect(find.text('Unstake successful'), findsOneWidget);

      // Verify back to initial state
      expect(find.widgetWithText(TextField, 'Amount to Stake'), findsOneWidget);
    });

    testWidgets('Staking validation and error handling', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to staking screen
      await tester.tap(find.text('Staking'));
      await tester.pumpAndSettle();

      // Try to stake without amount
      await tester.tap(find.text('Stake'));
      await tester.pumpAndSettle();

      expect(find.text('Please fill in all fields'), findsOneWidget);

      // Enter invalid amount
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount to Stake'),
        'invalid',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Lock Period (in seconds)'),
        '2592000',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stake'));
      await tester.pumpAndSettle();

      // Should show error for invalid number format
      expect(find.textContaining('Error staking:'), findsOneWidget);

      // Enter amount below minimum
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount to Stake'),
        '1',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stake'));
      await tester.pumpAndSettle();

      // Should show error for minimum stake requirement
      expect(find.textContaining('Error staking:'), findsOneWidget);
    });

    testWidgets('Staking rewards calculation', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to staking screen
      await tester.tap(find.text('Staking'));
      await tester.pumpAndSettle();

      // Stake tokens
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount to Stake'),
        '1000',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Lock Period (in seconds)'),
        '2592000',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stake'));
      await tester.pumpAndSettle();

      // Wait for rewards calculation
      await Future.delayed(const Duration(seconds: 1));
      await tester.pump();

      // Verify rewards are calculated correctly
      final rewardText = find.textContaining('Pending Rewards:').evaluate().single.widget as Text;
      final reward = int.parse(rewardText.data!.split(' ')[2]);
      expect(reward, greaterThan(0));
    });
  });
} 