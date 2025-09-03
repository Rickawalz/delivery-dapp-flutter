import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'dart:convert';
import '../../../constants/contract_addresses.dart';
import '../../../constants/abis.dart';

class StakingService {
  final Web3Client _client;
  final EthereumAddress _contractAddress;
  final DeployedContract _contract;
  final Credentials _credentials;

  StakingService({
    required Web3Client client,
    required Credentials credentials,
  }) : _client = client,
       _credentials = credentials,
       _contractAddress = EthereumAddress.fromHex(ContractAddresses.stakingManager),
       _contract = DeployedContract(
         ContractAbi.fromJson(jsonEncode(Abis.stakingManager), 'StakingManager'),
         EthereumAddress.fromHex(ContractAddresses.stakingManager),
       );

  Future<void> stake(BigInt amount, BigInt lockPeriod) async {
    final function = _contract.function('stake');
    await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: _contract,
        function: function,
        parameters: [amount, lockPeriod],
      ),
    );
  }

  Future<void> unstake() async {
    final function = _contract.function('unstake');
    await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: _contract,
        function: function,
        parameters: [],
      ),
    );
  }

  Future<BigInt> calculateReward(EthereumAddress user) async {
    final function = _contract.function('calculateReward');
    final result = await _client.call(
      contract: _contract,
      function: function,
      params: [user],
    );
    return result[0] as BigInt;
  }

  Future<Map<String, dynamic>> getStakeInfo(EthereumAddress user) async {
    final function = _contract.function('getStakeInfo');
    final result = await _client.call(
      contract: _contract,
      function: function,
      params: [user],
    );
    
    return {
      'amount': result[0] as BigInt,
      'startTime': result[1] as BigInt,
      'lockPeriod': result[2] as BigInt,
      'lastRewardTime': result[3] as BigInt,
    };
  }
} 