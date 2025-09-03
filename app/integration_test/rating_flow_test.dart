import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:delivery_dapp/main.dart' as app;
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Rating Flow Test', () {
    testWidgets('Complete rating flow', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to delivery details (assuming we have a test delivery)
      // This part would need to be adapted based on your actual navigation flow
      await tester.tap(find.text('Deliveries'));
      await tester.pumpAndSettle();
      
      await tester.tap(find.first);
      await tester.pumpAndSettle();

      // Find and tap the rating button
      await tester.tap(find.text('Rate Delivery'));
      await tester.pumpAndSettle();

      // Verify rating widget is shown
      expect(find.text('Rate User'), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsNWidgets(5));

      // Submit a rating
      await tester.tap(find.byIcon(Icons.star_border).at(4)); // 5-star rating
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'Excellent service, very professional!',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit Rating'));
      await tester.pumpAndSettle();

      // Verify success message
      expect(find.text('Rating submitted successfully'), findsOneWidget);

      // Verify rating appears in history
      await tester.tap(find.text('Rating History'));
      await tester.pumpAndSettle();

      expect(find.text('Excellent service, very professional!'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNWidgets(5));
    });

    testWidgets('Rating error handling', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to delivery details
      await tester.tap(find.text('Deliveries'));
      await tester.pumpAndSettle();
      
      await tester.tap(find.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rate Delivery'));
      await tester.pumpAndSettle();

      // Try to submit without rating
      await tester.tap(find.text('Submit Rating'));
      await tester.pumpAndSettle();

      expect(find.text('Please select a rating'), findsOneWidget);

      // Try to submit without comment
      await tester.tap(find.byIcon(Icons.star_border).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit Rating'));
      await tester.pumpAndSettle();

      // Should still work as comment is optional
      expect(find.text('Rating submitted successfully'), findsOneWidget);
    });
  });
} 