import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'package:delivery_dapp/services/blockchain/staking_service.dart';
import 'package:delivery_dapp/constants/contract_abis.dart';
import 'package:delivery_dapp/constants/contract_addresses.dart';
import 'package:delivery_dapp/utils/abi_utils.dart';

// Generate mocks
@GenerateMocks([Web3Client, DeployedContract, ContractFunction])
import 'staking_service_test.mocks.dart';

void main() {
  late MockWeb3Client mockWeb3Client;
  late MockDeployedContract mockContract;
  late MockContractFunction mockStakeFunction;
  late MockContractFunction mockUnstakeFunction;
  late MockContractFunction mockCalculateRewardFunction;
  late MockContractFunction mockGetStakeInfoFunction;
  late StakingService stakingService;
  late Credentials mockCredentials;

  setUp(() {
    mockWeb3Client = MockWeb3Client();
    mockContract = MockDeployedContract();
    mockStakeFunction = MockContractFunction();
    mockUnstakeFunction = MockContractFunction();
    mockCalculateRewardFunction = MockContractFunction();
    mockGetStakeInfoFunction = MockContractFunction();
    mockCredentials = EthPrivateKey.fromHex('0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');

    when(mockContract.function('stake')).thenReturn(mockStakeFunction);
    when(mockContract.function('unstake')).thenReturn(mockUnstakeFunction);
    when(mockContract.function('calculateReward')).thenReturn(mockCalculateRewardFunction);
    when(mockContract.function('getStakeInfo')).thenReturn(mockGetStakeInfoFunction);

    stakingService = StakingService(
      client: mockWeb3Client,
      credentials: mockCredentials,
    );
  });

  group('StakingService', () {
    test('stake should call the stake function with correct parameters', () async {
      final amount = BigInt.from(100);
      final lockPeriod = BigInt.from(30 * 24 * 60 * 60); // 30 days in seconds

      when(mockWeb3Client.sendTransaction(
        any,
        any,
      )).thenAnswer((_) async => 'transaction_hash');

      await stakingService.stake(amount, lockPeriod);

      verify(mockWeb3Client.sendTransaction(
        any,
        argThat(isA<Transaction>()),
      )).called(1);
    });

    test('unstake should call the unstake function', () async {
      when(mockWeb3Client.sendTransaction(
        any,
        any,
      )).thenAnswer((_) async => 'transaction_hash');

      await stakingService.unstake();

      verify(mockWeb3Client.sendTransaction(
        any,
        argThat(isA<Transaction>()),
      )).called(1);
    });

    test('calculateReward should return the correct reward amount', () async {
      final user = EthereumAddress.fromHex('0x1234567890123456789012345678901234567890');
      final expectedReward = BigInt.from(50);

      when(mockWeb3Client.call(
        contract: anyNamed('contract'),
        function: anyNamed('function'),
        params: anyNamed('params'),
      )).thenAnswer((_) async => [expectedReward]);

      final reward = await stakingService.calculateReward(user);

      expect(reward, equals(expectedReward));
      verify(mockWeb3Client.call(
        contract: anyNamed('contract'),
        function: anyNamed('function'),
        params: anyNamed('params'),
      )).called(1);
    });

    test('getStakeInfo should return stake information', () async {
      final user = EthereumAddress.fromHex('0x1234567890123456789012345678901234567890');
      final expectedAmount = BigInt.from(100);
      final expectedStartTime = BigInt.from(1234567890);
      final expectedLockPeriod = BigInt.from(30 * 24 * 60 * 60);
      final expectedLastRewardTime = BigInt.from(1234567890);

      when(mockWeb3Client.call(
        contract: anyNamed('contract'),
        function: anyNamed('function'),
        params: anyNamed('params'),
      )).thenAnswer((_) async => [
        expectedAmount,
        expectedStartTime,
        expectedLockPeriod,
        expectedLastRewardTime,
      ]);

      final stakeInfo = await stakingService.getStakeInfo(user);

      expect(stakeInfo['amount'], equals(expectedAmount));
      expect(stakeInfo['startTime'], equals(expectedStartTime));
      expect(stakeInfo['lockPeriod'], equals(expectedLockPeriod));
      expect(stakeInfo['lastRewardTime'], equals(expectedLastRewardTime));

      verify(mockWeb3Client.call(
        contract: anyNamed('contract'),
        function: anyNamed('function'),
        params: anyNamed('params'),
      )).called(1);
    });
  });
} 