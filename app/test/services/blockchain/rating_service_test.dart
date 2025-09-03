import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'package:delivery_dapp/services/blockchain/rating_service.dart';
import 'package:delivery_dapp/constants/contract_abis.dart';
import 'package:delivery_dapp/constants/contract_addresses.dart';
import 'package:delivery_dapp/utils/abi_utils.dart';

// Generate mocks
@GenerateMocks([Web3Client, DeployedContract, ContractFunction])
import 'rating_service_test.mocks.dart';

void main() {
  late MockWeb3Client mockWeb3Client;
  late MockDeployedContract mockContract;
  late MockContractFunction mockSubmitRatingFunction;
  late MockContractFunction mockGetUserRatingFunction;
  late MockContractFunction mockGetUserReviewsFunction;
  late RatingService ratingService;
  late Credentials mockCredentials;

  setUp(() {
    mockWeb3Client = MockWeb3Client();
    mockContract = MockDeployedContract();
    mockSubmitRatingFunction = MockContractFunction();
    mockGetUserRatingFunction = MockContractFunction();
    mockGetUserReviewsFunction = MockContractFunction();
    mockCredentials = EthPrivateKey.fromHex('0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');

    when(mockContract.function('submitRating')).thenReturn(mockSubmitRatingFunction);
    when(mockContract.function('getUserRating')).thenReturn(mockGetUserRatingFunction);
    when(mockContract.function('getUserReviews')).thenReturn(mockGetUserReviewsFunction);

    ratingService = RatingService(
      client: mockWeb3Client,
      credentials: mockCredentials,
    );
  });

  group('RatingService', () {
    test('submitRating should call the submitRating function with correct parameters', () async {
      final user = EthereumAddress.fromHex('0x1234567890123456789012345678901234567890');
      final score = BigInt.from(5);
      final comment = 'Great service!';

      when(mockWeb3Client.sendTransaction(
        any,
        any,
      )).thenAnswer((_) async => 'transaction_hash');

      await ratingService.submitRating(user, score, comment);

      verify(mockWeb3Client.sendTransaction(
        any,
        argThat(isA<Transaction>()),
      )).called(1);
    });

    test('getUserRating should return rating information', () async {
      final user = EthereumAddress.fromHex('0x1234567890123456789012345678901234567890');
      final expectedScore = BigInt.from(5);
      final expectedTotalRatings = BigInt.from(10);
      final expectedLastRatingTime = BigInt.from(1234567890);

      when(mockWeb3Client.call(
        contract: anyNamed('contract'),
        function: anyNamed('function'),
        params: anyNamed('params'),
      )).thenAnswer((_) async => [
        expectedScore,
        expectedTotalRatings,
        expectedLastRatingTime,
      ]);

      final ratingInfo = await ratingService.getUserRating(user);

      expect(ratingInfo['score'], equals(expectedScore));
      expect(ratingInfo['totalRatings'], equals(expectedTotalRatings));
      expect(ratingInfo['lastRatingTime'], equals(expectedLastRatingTime));

      verify(mockWeb3Client.call(
        contract: anyNamed('contract'),
        function: anyNamed('function'),
        params: anyNamed('params'),
      )).called(1);
    });

    test('getUserReviews should return list of reviews', () async {
      final user = EthereumAddress.fromHex('0x1234567890123456789012345678901234567890');
      final reviewer = EthereumAddress.fromHex('0x0987654321098765432109876543210987654321');
      final expectedReviews = [
        [
          reviewer,
          BigInt.from(5),
          'Great service!',
          BigInt.from(1234567890),
        ]
      ];

      when(mockWeb3Client.call(
        contract: anyNamed('contract'),
        function: anyNamed('function'),
        params: anyNamed('params'),
      )).thenAnswer((_) async => [expectedReviews]);

      final reviews = await ratingService.getUserReviews(user);

      expect(reviews.length, equals(1));
      expect(reviews[0]['reviewer'], equals(reviewer));
      expect(reviews[0]['score'], equals(BigInt.from(5)));
      expect(reviews[0]['comment'], equals('Great service!'));
      expect(reviews[0]['timestamp'], equals(BigInt.from(1234567890)));

      verify(mockWeb3Client.call(
        contract: anyNamed('contract'),
        function: anyNamed('function'),
        params: anyNamed('params'),
      )).called(1);
    });
  });
} 