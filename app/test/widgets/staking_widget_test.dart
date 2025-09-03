import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:web3dart/web3dart.dart';
import 'package:delivery_dapp/services/blockchain/staking_service.dart';
import 'package:delivery_dapp/widgets/staking_widget.dart';

@GenerateMocks([StakingService])
void main() {
  late MockStakingService mockStakingService;
  late EthereumAddress testAddress;

  setUp(() {
    mockStakingService = MockStakingService();
    testAddress = EthereumAddress.fromHex('0x1234567890123456789012345678901234567890');
  });

  group('StakingWidget - No Active Stake', () {
    setUp(() {
      when(mockStakingService.getStakeInfo(any)).thenAnswer((_) async => {
        'amount': BigInt.zero,
        'startTime': BigInt.zero,
        'lockPeriod': BigInt.zero,
        'lastRewardTime': BigInt.zero,
      });
      when(mockStakingService.calculateReward(any)).thenAnswer((_) async => BigInt.zero);
    });

    testWidgets('displays staking form when no active stake', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StakingWidget(
              stakingService: mockStakingService,
              userAddress: testAddress,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Staking Dashboard'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Stake'), findsOneWidget);
    });

    testWidgets('validates empty fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StakingWidget(
              stakingService: mockStakingService,
              userAddress: testAddress,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stake'));
      await tester.pumpAndSettle();

      expect(find.text('Please fill in all fields'), findsOneWidget);
    });

    testWidgets('can submit stake', (WidgetTester tester) async {
      when(mockStakingService.stake(any, any)).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StakingWidget(
              stakingService: mockStakingService,
              userAddress: testAddress,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Amount to Stake'), '100');
      await tester.enterText(find.widgetWithText(TextField, 'Lock Period (in seconds)'), '2592000');
      await tester.pump();

      await tester.tap(find.text('Stake'));
      await tester.pumpAndSettle();

      verify(mockStakingService.stake(BigInt.from(100), BigInt.from(2592000))).called(1);
      expect(find.text('Stake submitted successfully'), findsOneWidget);
    });
  });

  group('StakingWidget - Active Stake', () {
    setUp(() {
      when(mockStakingService.getStakeInfo(any)).thenAnswer((_) async => {
        'amount': BigInt.from(100),
        'startTime': BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        'lockPeriod': BigInt.from(30 * 24 * 60 * 60),
        'lastRewardTime': BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      });
      when(mockStakingService.calculateReward(any)).thenAnswer((_) async => BigInt.from(5));
    });

    testWidgets('displays stake info when active stake exists', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StakingWidget(
              stakingService: mockStakingService,
              userAddress: testAddress,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Current Stake: 100 tokens'), findsOneWidget);
      expect(find.text('Pending Rewards: 5 tokens'), findsOneWidget);
      expect(find.text('Unstake'), findsOneWidget);
    });

    testWidgets('can unstake', (WidgetTester tester) async {
      when(mockStakingService.unstake()).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StakingWidget(
              stakingService: mockStakingService,
              userAddress: testAddress,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unstake'));
      await tester.pumpAndSettle();

      verify(mockStakingService.unstake()).called(1);
      expect(find.text('Unstake successful'), findsOneWidget);
    });

    testWidgets('shows loading indicator during unstake', (WidgetTester tester) async {
      when(mockStakingService.unstake()).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StakingWidget(
              stakingService: mockStakingService,
              userAddress: testAddress,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unstake'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('handles unstake error', (WidgetTester tester) async {
      when(mockStakingService.unstake()).thenThrow(Exception('Failed to unstake'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StakingWidget(
              stakingService: mockStakingService,
              userAddress: testAddress,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unstake'));
      await tester.pumpAndSettle();

      expect(find.text('Error unstaking: Exception: Failed to unstake'), findsOneWidget);
    });
  });
} 