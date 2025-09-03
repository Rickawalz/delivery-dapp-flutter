import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import '../../constants/contract_addresses.dart';
import '../../constants/contract_abis.dart';

class BlockchainService {
  late Web3Client _client;
  late Credentials _credentials;
  late String _address;

  BlockchainService({Web3Client? client}) {
    _client = client ?? Web3Client('http://localhost:8545', Client());
  }

  Future<void> connect(String privateKey) async {
    _credentials = EthPrivateKey.fromHex(privateKey);
    _address = (await _credentials.extractAddress()).hex;
  }

  String get address => _address;
  Credentials get credentials => _credentials;
  Web3Client get client => _client;

  Future<void> disconnect() async {
    _client.dispose();
  }

  // Staking Manager Methods
  Future<void> stake(BigInt amount) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(ContractABIs.stakingManager, 'StakingManager'),
      EthereumAddress.fromHex(ContractAddresses.stakingManager),
    );

    final stakeFunction = contract.function('stake');
    await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: contract,
        function: stakeFunction,
        parameters: [amount],
      ),
    );
  }

  Future<void> unstake() async {
    final contract = DeployedContract(
      ContractAbi.fromJson(ContractABIs.stakingManager, 'StakingManager'),
      EthereumAddress.fromHex(ContractAddresses.stakingManager),
    );

    final unstakeFunction = contract.function('unstake');
    await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: contract,
        function: unstakeFunction,
        parameters: [],
      ),
    );
  }

  Future<BigInt> getStakedAmount(String account) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(ContractABIs.stakingManager, 'StakingManager'),
      EthereumAddress.fromHex(ContractAddresses.stakingManager),
    );

    final getStakedAmountFunction = contract.function('getStakedAmount');
    final result = await _client.call(
      contract: contract,
      function: getStakedAmountFunction,
      params: [EthereumAddress.fromHex(account)],
    );

    return result[0] as BigInt;
  }

  // Rating System Methods
  Future<void> submitRating(String user, int rating) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(ContractABIs.ratingSystem, 'RatingSystem'),
      EthereumAddress.fromHex(ContractAddresses.ratingSystem),
    );

    final submitRatingFunction = contract.function('submitRating');
    await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: contract,
        function: submitRatingFunction,
        parameters: [
          EthereumAddress.fromHex(user),
          BigInt.from(rating),
        ],
      ),
    );
  }

  Future<int> getRating(String user) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(ContractABIs.ratingSystem, 'RatingSystem'),
      EthereumAddress.fromHex(ContractAddresses.ratingSystem),
    );

    final getRatingFunction = contract.function('getRating');
    final result = await _client.call(
      contract: contract,
      function: getRatingFunction,
      params: [EthereumAddress.fromHex(user)],
    );

    return (result[0] as BigInt).toInt();
  }

  // Delivery Token Methods
  Future<void> transfer(String to, BigInt amount) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(ContractABIs.deliveryToken, 'DeliveryToken'),
      EthereumAddress.fromHex(ContractAddresses.deliveryToken),
    );

    final transferFunction = contract.function('transfer');
    await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: contract,
        function: transferFunction,
        parameters: [EthereumAddress.fromHex(to), amount],
      ),
    );
  }

  Future<BigInt> getBalance(String account) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(ContractABIs.deliveryToken, 'DeliveryToken'),
      EthereumAddress.fromHex(ContractAddresses.deliveryToken),
    );

    final balanceOfFunction = contract.function('balanceOf');
    final result = await _client.call(
      contract: contract,
      function: balanceOfFunction,
      params: [EthereumAddress.fromHex(account)],
    );

    return result[0] as BigInt;
  }
} 