import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'dart:convert';
import '../../../constants/contract_addresses.dart';
import '../../../constants/abis.dart';

class RatingService {
  final Web3Client _client;
  final EthereumAddress _contractAddress;
  final DeployedContract _contract;
  final Credentials _credentials;

  RatingService({
    required Web3Client client,
    required Credentials credentials,
  }) : _client = client,
       _credentials = credentials,
       _contractAddress = EthereumAddress.fromHex(ContractAddresses.ratingSystem),
       _contract = DeployedContract(
         ContractAbi.fromJson(jsonEncode(Abis.ratingSystem), 'RatingSystem'),
         EthereumAddress.fromHex(ContractAddresses.ratingSystem),
       );

  Future<void> submitRating(
    EthereumAddress reviewed,
    BigInt score,
    String comment,
  ) async {
    final function = _contract.function('submitRating');
    await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: _contract,
        function: function,
        parameters: [reviewed, score, comment],
      ),
    );
  }

  Future<Map<String, dynamic>> getUserRating(EthereumAddress user) async {
    final function = _contract.function('getUserRating');
    final result = await _client.call(
      contract: _contract,
      function: function,
      params: [user],
    );
    
    return {
      'score': result[0] as BigInt,
      'totalRatings': result[1] as BigInt,
      'lastRatingTime': result[2] as BigInt,
    };
  }

  Future<List<Map<String, dynamic>>> getUserReviews(
    EthereumAddress user,
  ) async {
    final function = _contract.function('getUserReviews');
    final result = await _client.call(
      contract: _contract,
      function: function,
      params: [user],
    );
    
    final reviews = result[0] as List;
    return reviews.map((review) => {
      'reviewer': review[0] as EthereumAddress,
      'score': review[1] as BigInt,
      'comment': review[2] as String,
      'timestamp': review[3] as BigInt,
    }).toList();
  }
} 