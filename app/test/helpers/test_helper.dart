import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'package:mockito/mockito.dart';
import 'package:delivery_dapp/services/blockchain/rating_service.dart';
import 'package:delivery_dapp/services/blockchain/staking_service.dart';

class MockWeb3Client extends Mock implements Web3Client {}
class MockDeployedContract extends Mock implements DeployedContract {}
class MockContractFunction extends Mock implements ContractFunction {}

/// Helper class for setting up blockchain service mocks
class BlockchainTestHelper {
  static const String testPrivateKey = '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
  static const String testAddress = '0x1234567890123456789012345678901234567890';

  static Credentials get testCredentials => EthPrivateKey.fromHex(testPrivateKey);
  static EthereumAddress get testEthAddress => EthereumAddress.fromHex(testAddress);

  /// Creates a mock Web3Client with basic setup
  static MockWeb3Client createMockWeb3Client() {
    final client = MockWeb3Client();
    when(client.call(
      contract: anyNamed('contract'),
      function: anyNamed('function'),
      params: anyNamed('params'),
    )).thenAnswer((_) async => [BigInt.zero]);
    return client;
  }

  /// Creates a mock rating service with basic setup
  static RatingService createMockRatingService() {
    return RatingService(
      client: createMockWeb3Client(),
      credentials: testCredentials,
    );
  }

  /// Creates a mock staking service with basic setup
  static StakingService createMockStakingService() {
    return StakingService(
      client: createMockWeb3Client(),
      credentials: testCredentials,
    );
  }
}

/// Helper class for widget testing
class WidgetTestHelper {
  /// Wraps a widget with MaterialApp for testing
  static Widget wrapWithMaterial(Widget widget) {
    return MaterialApp(
      home: Scaffold(
        body: widget,
      ),
    );
  }

  /// Simulates a delay for async operations
  static Future<void> simulateDelay([int milliseconds = 100]) {
    return Future.delayed(Duration(milliseconds: milliseconds));
  }

  /// Finds text that contains a specific string
  static Finder findTextContaining(String text) {
    return find.byWidgetPredicate(
      (widget) => widget is Text && widget.data!.contains(text),
    );
  }

  /// Extracts a number from a text widget
  static int extractNumber(String text) {
    final RegExp regex = RegExp(r'\d+');
    final match = regex.firstMatch(text);
    return int.parse(match?.group(0) ?? '0');
  }
}

/// Extension methods for testing
extension WidgetTesterExtension on WidgetTester {
  /// Pumps widget and settles all animations
  Future<void> pumpWidgetAndSettle(Widget widget) async {
    await pumpWidget(WidgetTestHelper.wrapWithMaterial(widget));
    await pumpAndSettle();
  }

  /// Taps a widget and waits for animations
  Future<void> tapAndSettle(Finder finder) async {
    await tap(finder);
    await pumpAndSettle();
  }

  /// Enters text and waits for animations
  Future<void> enterTextAndSettle(Finder finder, String text) async {
    await enterText(finder, text);
    await pumpAndSettle();
  }
} 