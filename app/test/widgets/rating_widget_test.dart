import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:web3dart/web3dart.dart';
import 'package:delivery_dapp/services/blockchain/rating_service.dart';
import 'package:delivery_dapp/widgets/rating_widget.dart';

@GenerateMocks([RatingService])
void main() {
  late MockRatingService mockRatingService;
  late EthereumAddress testAddress;

  setUp(() {
    mockRatingService = MockRatingService();
    testAddress = EthereumAddress.fromHex('0x1234567890123456789012345678901234567890');
  });

  testWidgets('RatingWidget displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RatingWidget(
            userAddress: testAddress,
            ratingService: mockRatingService,
          ),
        ),
      ),
    );

    expect(find.text('Rate User'), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsNWidgets(5));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('Can select rating', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RatingWidget(
            userAddress: testAddress,
            ratingService: mockRatingService,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.star_border).first);
    await tester.pump();

    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsNWidgets(4));
  });

  testWidgets('Can submit rating', (WidgetTester tester) async {
    bool callbackCalled = false;

    when(mockRatingService.submitRating(
      any,
      any,
      any,
    )).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RatingWidget(
            userAddress: testAddress,
            ratingService: mockRatingService,
            onRatingSubmitted: () => callbackCalled = true,
          ),
        ),
      ),
    );

    // Select rating
    await tester.tap(find.byIcon(Icons.star_border).first);
    await tester.pump();

    // Enter comment
    await tester.enterText(find.byType(TextField), 'Great service!');
    await tester.pump();

    // Submit rating
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    verify(mockRatingService.submitRating(
      testAddress,
      BigInt.from(1),
      'Great service!',
    )).called(1);

    expect(callbackCalled, true);
  });

  testWidgets('Shows error when submitting without rating', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RatingWidget(
            userAddress: testAddress,
            ratingService: mockRatingService,
          ),
        ),
      ),
    );

    // Try to submit without selecting rating
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('Please select a rating'), findsOneWidget);
  });

  testWidgets('Shows loading indicator during submission', (WidgetTester tester) async {
    when(mockRatingService.submitRating(
      any,
      any,
      any,
    )).thenAnswer((_) async {
      await Future.delayed(const Duration(milliseconds: 100));
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RatingWidget(
            userAddress: testAddress,
            ratingService: mockRatingService,
          ),
        ),
      ),
    );

    // Select rating and submit
    await tester.tap(find.byIcon(Icons.star_border).first);
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
} 